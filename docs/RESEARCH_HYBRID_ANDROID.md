# Research — Firebase AI Logic hybrid inference on Android (23 Nov 2026)

Method: official docs read on 23 Nov 2026, plus the published AARs from Google Maven inspected with `javap` to confirm
exact class and method names (the guides show no Kotlin import lines). Firebase agent skills were **not available** in
this Claude Code session, so they were not used.

## (a) Android Kotlin hybrid API and inference modes
Sources: https://firebase.google.com/docs/ai-logic/hybrid/android/get-started ·
https://firebase.google.com/docs/ai-logic/hybrid/android/configuration-options

Note: `https://firebase.google.com/docs/ai-logic/hybrid-on-device-inference?platform=android` serves the **Web** page;
the Android guide is under `/docs/ai-logic/hybrid/android/`.

- Status: **Experimental** (Firebase) on top of the ML Kit Prompt API (**beta**). Needs opt-in `@OptIn(PublicPreviewAPI::class)`.
- Dependencies (latest on Google Maven on 23 Nov): `com.google.firebase:firebase-ai:18.2.0`,
  `com.google.firebase:firebase-ai-ondevice:16.0.0-beta08` (not in the BoM yet), `com.google.firebase:firebase-appcheck-debug:20.1.0`.
  `firebase-ai-ondevice` pulls `com.google.mlkit:genai-prompt:1.0.0-beta5`. minSdk 26 for on-device (24 for `firebase-ai`).
- Confirmed from the AARs:
  - `com.google.firebase.ai.type.PublicPreviewAPI`
  - `Firebase.ai(backend = GenerativeBackend.googleAI())` (`com.google.firebase.ai.ai`, `com.google.firebase.ai.type.GenerativeBackend`)
  - `FirebaseAI.generativeModel(modelName, generationConfig, safetySettings, tools, toolConfig, systemInstruction, requestOptions, onDeviceConfig)`
  - `com.google.firebase.ai.OnDeviceConfig(mode, maxOutputTokens, temperature, topK, seed, candidateCount, modelOption, enableThinking)`
  - `com.google.firebase.ai.InferenceMode`: `PREFER_ON_DEVICE`, `ONLY_ON_DEVICE`, `PREFER_IN_CLOUD`, `ONLY_IN_CLOUD`
  - `GenerativeModel.onDeviceExtension: OnDeviceExtension?` with `checkStatus()`, `download(): Flow<DownloadStatus>`,
    `warmUp()`, `getModelName()`. Also a static `com.google.firebase.ai.ondevice.FirebaseAIOnDevice.checkStatus()/download()`.
  - `com.google.firebase.ai.OnDeviceModelStatus`: `UNAVAILABLE`, `DOWNLOADABLE`, `DOWNLOADING`, `AVAILABLE`
  - `com.google.firebase.ai.DownloadStatus.{DownloadStarted, DownloadInProgress(totalBytesDownloaded), DownloadCompleted, DownloadFailed(exception)}`
  - On-device exceptions: `FirebaseAIOnDeviceNotAvailableException`, `FirebaseAIOnDeviceInvalidRequestException`,
    `FirebaseAIOnDeviceUnknownException` (all `com.google.firebase.ai.type`).
- Mode semantics (configuration-options page):
  - `PREFER_ON_DEVICE`: on-device if available and the request type is supported; otherwise logs an error and **falls back to cloud**.
  - `ONLY_ON_DEVICE`: on-device or **throws**.
  - `PREFER_IN_CLOUD`: cloud if online and available; **if offline, falls back to on-device**; other failures throw.
  - `ONLY_IN_CLOUD`: cloud or throws.
- The SDK does **not** download the on-device model automatically; call `download()`. There is no default cloud model;
  `modelName` must be set. Spike default: `gemini-3.5-flash-lite` (stable, "billing not required" per
  https://firebase.google.com/docs/ai-logic/models).
- Limits on-device: single-turn text (+ one Bitmap image), no chat, no tools/grounding; streaming supported;
  structured output supported; ~4000-token request cap; docs advise outputs ≤ 256 tokens; foreground only; per-app quota
  (`BUSY`, `PER_APP_BATTERY_USE_QUOTA_EXCEEDED`); **only English and Korean validated on-device**. Firebase AI
  monitoring shows no data for on-device calls. App Check is enforced for AI Logic; debug provider for development.

## (b) ML Kit GenAI Prompt API device / OS requirements
Sources: https://developers.google.com/ml-kit/genai (Device support) · https://developers.google.com/ml-kit/genai/prompt/android ·
https://developers.google.com/ml-kit/genai/prompt/android/get-started

- Android API 26+. Runs through the **AICore** system service. Not supported on unlocked bootloaders. Foreground only.
- Supported devices (Prompt API table, grouped by Nano version): Pixel 9 / 10 / 11 series; Samsung Galaxy S25 / S26,
  Z Flip7/8, Z Fold7/8, Z TriFold, Tab S12; OnePlus 13/15; OPPO Find X / N, Reno 14–16 Pro; vivo X200 / X300 / X500, T4 Ultra;
  Xiaomi 15 / 17 series; Honor Magic 7/8; Motorola Edge 70 Pro / Razr; realme GT 7 series; POCO F9 Pro / X8 Pro Max;
  Redmi Turbo 5; Sony Xperia 1 VIII; Sharp AQUOS R11; and others. **No Galaxy A-series or other entry-level phone.**
- "Availability and version may vary depending on the device's RAM configuration, OS version, and AICore update status."
- Input limit < 4000 tokens; long outputs discouraged.

## (c) Flutter / Dart packages
Sources: https://pub.dev/packages/firebase_ai · https://firebase.google.com/docs/ai-logic/hybrid/llms.txt

- `firebase_ai` 5.2.0 (FlutterFire, latest seen) has **no** hybrid / on-device API (no `InferenceMode`, `OnDeviceConfig`,
  or on-device types). Firebase lists hybrid guides for Android, Web and Apple only, not Flutter.
- Third-party Flutter plugins wrap ML Kit / Gemini Nano directly (e.g. `google_mlkit_genai_prompt`, `gemini_nano_android`,
  `flutter_local_ai`); none goes through Firebase AI Logic, so they would not satisfy the hackathon's requirement.
- Conclusion: a Kotlin platform-channel wrapper around `firebase-ai` + `firebase-ai-ondevice` is the way to use Firebase
  hybrid inference from this Flutter app (what the spike does).

## (d) Telling which route served a response
- `GenerateContentResponse.inferenceSource: com.google.firebase.ai.InferenceSource` → `ON_DEVICE` or `IN_CLOUD`
  (confirmed in the AAR and on the get-started page).
- The SDK does **not** report *why* it fell back. The spike derives a reason from `onDeviceExtension.checkStatus()`
  before the call plus device connectivity (diagnostic only; routing is still the SDK's).

## (e) App Check for a remote tester without logcat (researched 23 Nov)
Sources: https://firebase.google.com/docs/app-check/android/debug-provider ·
https://firebase.google.com/docs/ai-logic/app-check · https://firebase.google.com/docs/app-check/enable-enforcement ·
plus `firebase-appcheck-debug:20.1.0` inspected with `javap`.

**(a) Pre-registered debug secret — works, but the build-time route is not on the Android docs page.**
- Docs confirm: tokens can be created in the console (App Check → Apps → ⋮ → Manage debug tokens); for CI the token is
  passed as the instrumentation argument `firebaseAppCheckDebugSecret` (tests only). The Android page shows no way to set
  the secret for a normal app launch.
- The library itself (20.1.0) resolves the secret in this order: an internal provider hook → string resource
  **`firebase_app_check_debug_token`** (used only if the app is debuggable; release builds log a security warning and
  ignore it) → a UUID saved in SharedPreferences → a new UUID logged to logcat. Its log text also suggests
  `firebase appcheck:debugtokens:create` (Firebase CLI) and "then rebuild the app".
- Implemented on the spike branch: `android/app/build.gradle.kts` sets that resource for **debug builds only** from
  `NIKO_RADA_APP_CHECK_DEBUG_TOKEN` or `nikoRada.appCheckDebugToken` in `android/local.properties` (gitignored).
  Verified by building with a fake token and reading it back from the APK with `aapt2`. **Not yet verified against
  the real App Check backend** (needs the Firebase project).

**(b) Leaving App Check unenforced — possible until 21 Jan 2027, but may not be enough.**
- Docs: "On November 2, 2026, Firebase automatically enforced Firebase App Check for Firebase AI Logic in all projects."
  A new project is therefore expected to start enforced. Unenforcing is "strongly NOT recommended" and possible until
  21 Jan 2027, when it is re-enforced permanently.
- Console path: Security → App Check → **APIs** tab → Firebase AI Logic → *Set up* → Baseline protection
  "Unenforced (monitoring only)".
- Catch: for "certain commonly abused models" a request without a valid token gets `PERMISSION_DENIED: To access this
  model, you must enforce Firebase App Check...` even when unenforced. The docs do not list which models; whether
  `gemini-3.5-flash-lite` is one is **unconfirmed**.
- Enforcement changes can take up to 15 minutes to apply (stated for enabling; no time stated for disabling).

**Recommendation:** use (a). It keeps enforcement on and gives a remote tester a working build. Use (b) only as a
short-lived fallback if (a) fails, and re-enforce immediately after.

## Could not confirm
- Exact behaviour of `PREFER_ON_DEVICE` / `ONLY_ON_DEVICE` when **offline** on an unsupported phone (expected: error;
  test C.5 in `SPIKE_CHECKLIST.md`).
- Whether Nano answers Kiswahili / Sheng acceptably (not validated by Google).
- Whether `systemInstruction` is honoured on-device (not stated). The spike passes everything in the prompt.
- Whether the App Check console flow requires registering Play Integrity before debug tokens can be added.
- Whether a build-time `firebase_app_check_debug_token` is accepted by the real App Check backend (code path confirmed,
  not yet exercised).
- Which "commonly abused" models reject unverified requests even with App Check unenforced.
- Pricing / quota numbers for the cloud model on the free plan (pricing and quota pages not read).
- Whether emulators can run the on-device path (docs silent; assume no).
- The models page was partly truncated when read; model names were cross-checked against two pages only.
