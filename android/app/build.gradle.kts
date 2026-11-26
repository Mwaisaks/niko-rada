import java.util.Properties

// Optional App Check debug token for remote testers (no logcat needed). NEVER commit it.
// Source, in order: env NIKO_RADA_APP_CHECK_DEBUG_TOKEN, then `nikoRada.appCheckDebugToken=` in android/local.properties
// (gitignored). firebase-appcheck-debug reads R.string.firebase_app_check_debug_token in debuggable builds only.
val appCheckDebugToken: String = System.getenv("NIKO_RADA_APP_CHECK_DEBUG_TOKEN")
    ?: rootProject.file("local.properties").takeIf { it.exists() }?.let { f ->
        Properties().apply { f.inputStream().use { load(it) } }.getProperty("nikoRada.appCheckDebugToken")
    }
    ?: ""

// Values from env first, then android/local.properties (gitignored). Passwords are read from the environment ONLY,
// never from a file.
val localProps: Properties = Properties().apply {
    rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}
fun setting(env: String, prop: String): String? = System.getenv(env) ?: localProps.getProperty(prop)

// Release signing: one dedicated keystore kept OUTSIDE the repo.
//   NIKO_RADA_KEYSTORE_PATH  or nikoRada.keystorePath   (absolute path)
//   NIKO_RADA_KEY_ALIAS      or nikoRada.keyAlias
//   NIKO_RADA_KEYSTORE_PASSWORD, NIKO_RADA_KEY_PASSWORD  (environment only)
// If any is missing, release builds fall back to the debug keystore (with a warning).
val releaseKeystorePath: String? = setting("NIKO_RADA_KEYSTORE_PATH", "nikoRada.keystorePath")
val releaseKeyAlias: String? = setting("NIKO_RADA_KEY_ALIAS", "nikoRada.keyAlias")
val releaseStorePassword: String? = System.getenv("NIKO_RADA_KEYSTORE_PASSWORD")
val releaseKeyPassword: String? = System.getenv("NIKO_RADA_KEY_PASSWORD") ?: releaseStorePassword
val hasReleaseKeystore = listOf(releaseKeystorePath, releaseKeyAlias, releaseStorePassword).all { !it.isNullOrBlank() } &&
    file(releaseKeystorePath!!).exists()

// Judge build: a release-mode (AOT, small) APK that is still debuggable, so the App Check debug provider accepts the
// built-in debug token (it reads the token only in debuggable apps). For hackathon judging only; never for real users.
//   NIKO_RADA_JUDGE_BUILD=true flutter build apk --release --target-platform android-arm64
val judgeBuild: Boolean = setting("NIKO_RADA_JUDGE_BUILD", "nikoRada.judgeBuild")?.toBoolean() ?: false

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nikorada.niko_rada"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nikorada.niko_rada"
        // 26+: required by firebase-ai-ondevice
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        resValues = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        debug {
            // Empty unless a token is supplied (see top of file); empty means the SDK generates one and logs it.
            resValue("string", "firebase_app_check_debug_token", appCheckDebugToken)
        }
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                logger.warn("niko_rada: release keystore not configured; signing release with the debug keystore.")
                signingConfig = signingConfigs.getByName("debug")
            }
            if (judgeBuild) {
                isDebuggable = true
                resValue("string", "firebase_app_check_debug_token", appCheckDebugToken)
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Firebase config is NOT committed (public repo). If android/app/google-services.json is present, apply the
// google-services plugin so FirebaseApp auto-initialises. Without it the app still builds; the hybrid spike screen
// then reports "Firebase not configured" instead of crashing. See docs/SPIKE_CHECKLIST.md.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn("niko_rada: android/app/google-services.json not found; building without Firebase config.")
}

dependencies {
    // Firebase AI Logic hybrid inference (Android). Versions per
    // https://firebase.google.com/docs/ai-logic/hybrid/android/get-started (on-device SDK is not in the BoM yet).
    implementation("com.google.firebase:firebase-ai:18.2.0")
    implementation("com.google.firebase:firebase-ai-ondevice:16.0.0-beta08")
    // App Check debug provider: fine for the hackathon submission; swap for Play Integrity before any real release.
    implementation("com.google.firebase:firebase-appcheck-debug:20.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
