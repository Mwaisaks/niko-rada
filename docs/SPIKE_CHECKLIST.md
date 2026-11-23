# Hybrid inference spike — owner checklist

Branch: `spike/hybrid-inference`. Goal: prove on a real phone that Firebase AI Logic hybrid inference answers
**on-device** (Gemini Nano) on a supported phone and **in the cloud** on an unsupported one, and that the app shows which.

What's in the spike:
- `android/app/src/main/kotlin/com/nikorada/niko_rada/HybridInferencePlugin.kt` — Kotlin wrapper over the Firebase hybrid SDK
  (`firebase-ai` 18.2.0 + `firebase-ai-ondevice` 16.0.0-beta08), MethodChannel `niko_rada/hybrid_inference`.
- `lib/spike/hybrid_inference_channel.dart` — Dart client. `lib/spike/hybrid_debug_screen.dart` — debug screen.
- `lib/main_spike.dart` — separate entrypoint (skips the old Gemma download screen).

Never commit `google-services.json` or the App Check debug token. Both are gitignored / stay in the console.

---

## A. Firebase console (you do these, in order)

1. **Create the project.** https://console.firebase.google.com → Add project → name e.g. `niko-rada`. Google Analytics
   is not needed (turn it off). Spark (free) plan is fine for the spike.
2. **Enable Firebase AI Logic with the Gemini Developer API.** In the project: left menu → *AI Logic* (under Build / AI)
   → *Get started* → choose **Gemini Developer API** → follow the prompts. This enables the APIs and creates the Gemini
   API key that Firebase keeps server-side. Do **not** copy that key into the app or the repo.
3. **Register the Android app.** Project settings → *Your apps* → Add app → Android.
   - Android package name: **`com.nikorada.niko_rada`** (must match exactly; it's `applicationId` in
     `android/app/build.gradle.kts`).
   - Nickname: `Niko Rada Android`. SHA-1 optional for now.
4. **Download `google-services.json`** and put it at **`android/app/google-services.json`**.
   - Check it is ignored: `git check-ignore -v android/app/google-services.json` must print a `.gitignore` line.
   - `git status` must not list it. If it ever shows up, stop and tell Claude.
   - Skip the "add SDK" steps in the wizard; the dependencies are already in the branch.
5. **App Check (required by Firebase AI Logic).**
   1. Console → *App Check* → *Apps* tab → your Android app. If it asks for an attestation provider first, register
      **Play Integrity** (needs the SHA-256 of the signing key: `cd android && ./gradlew signingReport`, debug variant).
   2. Build and launch the spike once (section B), tap **Check status**. The debug provider prints a token to logcat:
      `adb logcat | grep -i -E "debug secret|DebugAppCheck"`
      (expected line: "Enter this debug secret into the allow list in the Firebase Console…").
   3. Console → App Check → Apps → your app's ⋮ menu → **Manage debug tokens** → Add → paste the token, name it after the
      phone (e.g. `owner-4gb-phone`). Repeat for the borrowed phone (each install gets its own token).
   4. Treat tokens like passwords: never paste them into the repo, screenshots or the demo video. Delete them from the
      console after the hackathon.
   5. If calls fail with App Check / 403 errors, check enforcement in App Check → APIs → Firebase AI Logic, and that the
      token is registered for this exact install.

## B. Build and install

```bash
git checkout spike/hybrid-inference
flutter pub get
# phone connected with USB debugging on:
flutter run -t lib/main_spike.dart
# or build an APK to sideload:
flutter build apk --debug -t lib/main_spike.dart --target-platform android-arm64
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
Keep the app in the **foreground** during every on-device test (on-device inference is foreground-only).
Useful logs: `adb logcat -s NikoRadaHybrid` (route, status, latency per call).

## C. Phone 1 — your 4 GB phone (expected: cloud path)

Not on the ML Kit Prompt API device list, so on-device should be `UNAVAILABLE`.
1. Wi-Fi/data on. **Check status** → expect `Firebase: configured · on-device model: UNAVAILABLE · online`.
2. Mode `PREFER_ON_DEVICE`, EN preset, **Generate** → expect badge **In the cloud**, "Why: On-device model not ready on
   this phone (UNAVAILABLE)".
3. Mode `ONLY_ON_DEVICE`, **Generate** → expect an error (likely `FirebaseAIOnDeviceNotAvailableException`). Note the code.
4. Mode `ONLY_IN_CLOUD`, SW preset and Sheng preset → cloud answers; note Kiswahili/Sheng quality.
5. **Airplane mode on.** Mode `PREFER_ON_DEVICE`, **Generate** → expect an error: neither path works. This is the honest
   limitation for the pitch; note the error code shown.

## D. Phone 2 — borrowed Gemini Nano phone (expected: on-device path)

Before borrowing, check the model is on the Prompt API list: https://developers.google.com/ml-kit/genai#prompt-device
(e.g. Pixel 9 / 10 series, Galaxy S25 / S26, recent OnePlus / Xiaomi / vivo / OPPO flagships). Bootloader must be
locked. Emulators won't work.
1. Update **Android AICore** and **Private Compute Services** from the Play Store. Wi-Fi on.
2. Install the spike, register this phone's App Check debug token (A.5).
3. **Check status** → expect `DOWNLOADABLE`, `DOWNLOADING` or `AVAILABLE`. If `DOWNLOADABLE`, tap
   **Download on-device model** and wait (can take minutes, Wi-Fi). Re-check until `AVAILABLE`.
   If it stays `UNAVAILABLE`, the phone isn't supported → stop and tell Claude (this triggers the Web fallback decision).
4. Online, `PREFER_ON_DEVICE`, EN preset → expect **On your device**. Note latency.
5. **Airplane mode on.** `PREFER_ON_DEVICE` → expect **On your device**, `offline`. This is the money shot for the demo.
6. Still offline: SW and Sheng presets → note whether Nano answers sensibly (only EN/KO are validated on-device).
7. Still offline: `ONLY_IN_CLOUD` → expect an error. `PREFER_IN_CLOUD` → expect **On your device** with "Why: No
   connection…".
8. Back online: `ONLY_IN_CLOUD` → **In the cloud**.
9. Screen-record steps 4–7.

## E. Report back to Claude

Paste this table (and any error codes / logcat lines from `NikoRadaHybrid`):

| Phone (model, RAM, Android ver) | Step | Mode | Network | Status before | Badge / error | Latency | Notes (language quality) |
|---|---|---|---|---|---|---|---|

The spike passes when D.5 shows **On your device** in airplane mode and C.2 shows **In the cloud** with a reason.
Phase 1 does not start until you confirm that.
