package com.nikorada.niko_rada

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.SystemClock
import android.util.Log
import com.google.firebase.Firebase
import com.google.firebase.FirebaseApp
import com.google.firebase.ai.DownloadStatus
import com.google.firebase.ai.GenerativeModel
import com.google.firebase.ai.InferenceMode
import com.google.firebase.ai.InferenceSource
import com.google.firebase.ai.OnDeviceConfig
import com.google.firebase.ai.OnDeviceModelStatus
import com.google.firebase.ai.ai
import com.google.firebase.ai.type.FirebaseAIException
import com.google.firebase.ai.type.GenerativeBackend
import com.google.firebase.ai.type.PublicPreviewAPI
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.debug.DebugAppCheckProviderFactory
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Thin Kotlin wrapper around Firebase AI Logic hybrid inference (firebase-ai + firebase-ai-ondevice), exposed to
 * Dart over a MethodChannel. This is the ONLY native code that calls a model.
 *
 * Routing is done by the Firebase SDK itself via [OnDeviceConfig] / [InferenceMode]. This class does not implement
 * its own "try on-device, then cloud" logic. It only adds diagnostics (on-device model status before the call,
 * connectivity) so the UI can explain WHY a request went to the cloud, which the SDK does not report.
 *
 * Methods (channel "niko_rada/hybrid_inference"):
 *  - deviceInfo                                   -> {manufacturer, model, androidVersion, sdkInt, totalRamGb,
 *                                                     firebaseConfigured, appCheckBuildToken} (nothing personal)
 *  - status   {cloudModel?}                       -> {firebaseConfigured, onDeviceStatus, online}
 *  - download {cloudModel?}                       -> {onDeviceStatus, downloadResult, bytesDownloaded, error?}
 *  - generate {prompt, mode, cloudModel?, maxOutputTokens?}
 *             -> {text, route, mode, cloudModel, onDeviceStatusBefore, online, latencyMs, fallbackReason?}
 *    Errors come back as FlutterError(code = exception class simple name, message, details = diagnostics map).
 */
@OptIn(PublicPreviewAPI::class)
class HybridInferencePlugin(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "niko_rada/hybrid_inference"
        // Stable, "billing not required" per https://firebase.google.com/docs/ai-logic/models (checked 23 Nov 2026).
        const val DEFAULT_CLOUD_MODEL = "gemini-3.5-flash-lite"
        private const val TAG = "NikoRadaHybrid"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var appCheckInstalled = false

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "deviceInfo" -> result.success(deviceInfo())
            "status" -> scope.launch { handleStatus(call, result) }
            "download" -> scope.launch { handleDownload(call, result) }
            "generate" -> scope.launch { handleGenerate(call, result) }
            else -> result.notImplemented()
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Handlers
    // ---------------------------------------------------------------------------------------------

    private suspend fun handleStatus(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureFirebase(result)) return
        val model = buildModel(call.argument<String>("cloudModel"), InferenceMode.PREFER_ON_DEVICE, null)
        result.success(
            mapOf(
                "firebaseConfigured" to true,
                "onDeviceStatus" to onDeviceStatus(model),
                "online" to isOnline(),
            )
        )
    }

    private suspend fun handleDownload(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureFirebase(result)) return
        val model = buildModel(call.argument<String>("cloudModel"), InferenceMode.PREFER_ON_DEVICE, null)
        val ext = model.onDeviceExtension
        if (ext == null) {
            result.success(mapOf("onDeviceStatus" to "NO_ON_DEVICE_EXTENSION", "downloadResult" to "skipped"))
            return
        }
        var outcome = "unknown"
        var bytes = 0L
        var error: String? = null
        try {
            ext.download().collect { status ->
                when (status) {
                    is DownloadStatus.DownloadStarted -> {
                        outcome = "started"
                        Log.i(TAG, "On-device model download started")
                    }
                    is DownloadStatus.DownloadInProgress -> {
                        bytes = status.totalBytesDownloaded
                        outcome = "in_progress"
                    }
                    is DownloadStatus.DownloadCompleted -> outcome = "completed"
                    is DownloadStatus.DownloadFailed -> {
                        outcome = "failed"
                        error = status.exception.message
                        Log.w(TAG, "On-device model download failed", status.exception)
                    }
                    else -> Log.i(TAG, "Download status: $status")
                }
            }
        } catch (e: Exception) {
            outcome = "failed"
            error = "${e.javaClass.simpleName}: ${e.message}"
            Log.w(TAG, "download() threw", e)
        }
        result.success(
            mapOf(
                "onDeviceStatus" to onDeviceStatus(model),
                "downloadResult" to outcome,
                "bytesDownloaded" to bytes,
                "error" to error,
            )
        )
    }

    private suspend fun handleGenerate(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureFirebase(result)) return
        val prompt = call.argument<String>("prompt")
        if (prompt.isNullOrBlank()) {
            result.error("BAD_ARGS", "prompt is required", null)
            return
        }
        val modeName = call.argument<String>("mode") ?: "PREFER_ON_DEVICE"
        val mode = parseMode(modeName)
        if (mode == null) {
            result.error("BAD_ARGS", "unknown mode: $modeName", null)
            return
        }
        val cloudModel = call.argument<String>("cloudModel")?.takeIf { it.isNotBlank() } ?: DEFAULT_CLOUD_MODEL
        val maxOut = call.argument<Int>("maxOutputTokens")

        val model = buildModel(cloudModel, mode, maxOut)
        val statusBefore = onDeviceStatus(model)
        val online = isOnline()
        val diagnostics = mutableMapOf<String, Any?>(
            "mode" to modeName,
            "cloudModel" to cloudModel,
            "onDeviceStatusBefore" to statusBefore,
            "online" to online,
        )

        val started = SystemClock.elapsedRealtime()
        try {
            val response = model.generateContent(prompt)
            val latency = SystemClock.elapsedRealtime() - started
            val route = when (response.inferenceSource) {
                InferenceSource.ON_DEVICE -> "ON_DEVICE"
                InferenceSource.IN_CLOUD -> "IN_CLOUD"
                else -> "UNKNOWN"
            }
            diagnostics["text"] = response.text ?: ""
            diagnostics["route"] = route
            diagnostics["latencyMs"] = latency
            diagnostics["fallbackReason"] = fallbackReason(mode, route, statusBefore, online)
            Log.i(TAG, "generate: mode=$modeName route=$route statusBefore=$statusBefore online=$online ${latency}ms")
            result.success(diagnostics)
        } catch (e: Exception) {
            diagnostics["latencyMs"] = SystemClock.elapsedRealtime() - started
            Log.w(TAG, "generate failed: mode=$modeName statusBefore=$statusBefore online=$online", e)
            val code = if (e is FirebaseAIException) e.javaClass.simpleName else "NATIVE_${e.javaClass.simpleName}"
            result.error(code, e.message ?: e.toString(), diagnostics)
        }
    }

    /** Hardware/OS facts for the tester's report. No identifiers (no serial, IMEI, account, or token value). */
    private fun deviceInfo(): Map<String, Any?> {
        val mem = ActivityManager.MemoryInfo()
        (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(mem)
        val tokenResId = context.resources.getIdentifier("firebase_app_check_debug_token", "string", context.packageName)
        val hasBuildToken = tokenResId != 0 && context.getString(tokenResId).isNotBlank()
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "totalRamGb" to Math.round(mem.totalMem / 1e9 * 10) / 10.0,
            "firebaseConfigured" to FirebaseApp.getApps(context).isNotEmpty(),
            "appCheckBuildToken" to hasBuildToken,
        )
    }

    // ---------------------------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------------------------

    /** Returns false (and answers the call) when google-services.json was not present at build time. */
    private fun ensureFirebase(result: MethodChannel.Result): Boolean {
        if (FirebaseApp.getApps(context).isEmpty()) {
            result.error(
                "FIREBASE_NOT_CONFIGURED",
                "No FirebaseApp. Add android/app/google-services.json (see docs/SPIKE_CHECKLIST.md) and rebuild.",
                null,
            )
            return false
        }
        if (!appCheckInstalled) {
            // Debug provider: logs a debug token to logcat on first use; register it in the Firebase console.
            FirebaseAppCheck.getInstance().installAppCheckProviderFactory(DebugAppCheckProviderFactory.getInstance())
            appCheckInstalled = true
        }
        return true
    }

    private fun buildModel(cloudModel: String?, mode: InferenceMode, maxOutputTokens: Int?): GenerativeModel =
        Firebase.ai(backend = GenerativeBackend.googleAI()).generativeModel(
            modelName = cloudModel?.takeIf { it.isNotBlank() } ?: DEFAULT_CLOUD_MODEL,
            onDeviceConfig = OnDeviceConfig(mode = mode, maxOutputTokens = maxOutputTokens),
        )

    private suspend fun onDeviceStatus(model: GenerativeModel): String {
        val ext = model.onDeviceExtension ?: return "NO_ON_DEVICE_EXTENSION"
        return try {
            when (ext.checkStatus()) {
                OnDeviceModelStatus.AVAILABLE -> "AVAILABLE"
                OnDeviceModelStatus.DOWNLOADABLE -> "DOWNLOADABLE"
                OnDeviceModelStatus.DOWNLOADING -> "DOWNLOADING"
                OnDeviceModelStatus.UNAVAILABLE -> "UNAVAILABLE"
                else -> "UNKNOWN"
            }
        } catch (e: Exception) {
            Log.w(TAG, "checkStatus() threw", e)
            "ERROR: ${e.javaClass.simpleName}"
        }
    }

    private fun parseMode(name: String): InferenceMode? = when (name) {
        "PREFER_ON_DEVICE" -> InferenceMode.PREFER_ON_DEVICE
        "ONLY_ON_DEVICE" -> InferenceMode.ONLY_ON_DEVICE
        "PREFER_IN_CLOUD" -> InferenceMode.PREFER_IN_CLOUD
        "ONLY_IN_CLOUD" -> InferenceMode.ONLY_IN_CLOUD
        else -> null
    }

    /** Human-readable reason when the served route differs from the preferred one. Diagnostic only. */
    private fun fallbackReason(mode: InferenceMode, route: String, statusBefore: String, online: Boolean): String? =
        when {
            mode == InferenceMode.PREFER_ON_DEVICE && route == "IN_CLOUD" ->
                if (statusBefore != "AVAILABLE") "On-device model not ready on this phone ($statusBefore)."
                else "On-device model was available but the SDK fell back (request type or on-device error; see logcat)."
            mode == InferenceMode.PREFER_IN_CLOUD && route == "ON_DEVICE" ->
                if (!online) "No connection, so the SDK used the on-device model." else "Cloud call failed; SDK used on-device."
            else -> null
        }

    private fun isOnline(): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }
}
