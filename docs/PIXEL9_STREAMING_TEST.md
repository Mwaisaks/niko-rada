# Streamed Pixel 9 test — Android Studio device streaming (prepared 27 Nov 2026)

Goal: get one on-device result from a Nano-capable phone. The Pixel 9 is on the live ML Kit Prompt API list under
**Gemini Nano 3** (`docs/RESEARCH_REMOTE_AND_WEB.md`). We want `checkStatus()` = `AVAILABLE` and one reply
"answered by: ON DEVICE". Budget: **one 15–20 minute session.** The free Spark minutes are limited (30 per project
per month in the 26 Nov research), and **the device is wiped and factory-reset when you return it**, so do everything
in one session.

Source read 27 Nov: https://developer.android.com/studio/run/android-device-streaming. **Unconfirmed** marks steps the
page doesn't state (APK install mechanics, logcat, screenshots, network, Play Store/AICore updates).

## 0. Prepare on the laptop before reserving the device (nothing here uses streaming minutes)

1. Firebase/App Check:
   - `android/app/google-services.json` is in place (gitignored).
   - A debug token for this test is registered in the console: *Security → App Check → Apps → Android app → ⋮ → Manage
     debug tokens*, named "pixel9-streaming".
   - The token is set in `android/local.properties` (`nikoRada.appCheckDebugToken=…`, gitignored) or in
     `NIKO_RADA_APP_CHECK_DEBUG_TOKEN`. Never put it in a tracked file.
2. Build **two** APKs from `main`, both as judge builds (release AOT, debuggable, so the debug token is read):
   ```bash
   flutter pub get
   # a) the test screen (status, download, generate, triage, "Copy results")
   NIKO_RADA_JUDGE_BUILD=true flutter build apk --release -t lib/main_spike.dart --target-platform android-arm64
   cp build/app/outputs/flutter-apk/app-release.apk ~/nr-spike-judge.apk
   # b) the real judge app (Ask/Actions screens with route badge)
   NIKO_RADA_JUDGE_BUILD=true flutter build apk --release --target-platform android-arm64
   cp build/app/outputs/flutter-apk/app-release.apk ~/nr-judge.apk
   ```
   Both share the application ID `com.nikorada.niko_rada`, so they **replace each other** on install. Install (a)
   first, then (b).
   Confirm the token is inside without printing it:
   `aapt2 dump resources ~/nr-spike-judge.apk | grep -c firebase_app_check_debug_token` → `1`.
   - Whether `main_spike.dart` builds in judge mode has **not been tried yet**. Run build (a) now. If it fails, fall
     back to the debug spike build in `docs/SPIKE_CHECKLIST.md` B2.4 (`flutter build apk --debug -t lib/main_spike.dart`).
3. Install the latest stable Android Studio (Jellyfish or later), open this repo's `android/` folder or the Flutter
   project, and make sure `adb` works locally (`adb version`).
4. Open a terminal for the logs, ready to run (step 2.5):
   `mkdir -p ~/nr-pixel9 && cd ~/nr-pixel9`

## 1. Reserve the device (docs-confirmed steps)
1. Android Studio → **View → Tool Windows → Device Manager** → **Firebase** button near the top.
2. **Log in to Google** if asked, then authorize Android Studio for Firebase.
3. Select the **hackathon Firebase project**. The window shows the remaining minutes. (Permission error → you need
   Editor/Owner; the page lists the IAM roles *Firebase Test Lab Direct Access Admin* and *Service Usage Consumer*.)
   Click **Confirm**.
4. In the device list pick **Pixel 9** (or 9 Pro / 9 Pro XL; all Nano 3), then click **Start**. The **Running Devices**
   window opens once the device is reserved. Use **Extend Reservation** in its toolbar if needed.

## 2. Install and test (≈ 10 minutes)
1. In a terminal: `adb devices` should list the streamed device. The page says it connects over "ADB over SSL" and that
   ADB tools work, so this is implied but **unconfirmed**. If several devices show, add `-s <serial>` below.
2. Note the Android build: `adb shell getprop ro.build.fingerprint > ~/nr-pixel9/fingerprint.txt`.
3. Check AICore is present (read-only):
   `adb shell pm list packages | grep -i aicore` → expect `package:com.google.android.aicore`.
   `adb shell dumpsys package com.google.android.aicore | grep versionName >> ~/nr-pixel9/fingerprint.txt`
4. Install the test screen: `adb install -r ~/nr-spike-judge.apk`. If `adb` isn't available, deploy from Android Studio
   instead: run `lib/main_spike.dart` on the streamed device. That builds a debug APK, which also reads the token.
5. Start logs: `adb logcat -c && adb logcat -s NikoRadaHybrid:I flutter:I > ~/nr-pixel9/logcat.txt &`
   The plugin logs every call as `generate: mode=… route=… statusBefore=… online=… Nms` (tag `NikoRadaHybrid`).
6. On the device, open **Hybrid inference test**:
   1. Check the top line: "Google Pixel 9 · Android … · … GB RAM". It must **not** say "Firebase NOT configured".
   2. **1 · Check status**. Note the status.
   3. If `DOWNLOADABLE`/`DOWNLOADING`: **Download on-device model**, wait (download size unknown), then **Check status**
      again. Repeat every ~30 s for up to 5 minutes. Trust `checkStatus()`, never the download result (lesson from
      the A16).
   4. If `AVAILABLE`: run **Generate** online with `PREFER_ON_DEVICE`, then the **Triage** test. Look for
      "answered by: ON DEVICE".
   5. Only if `AVAILABLE`: turn on airplane mode in the device's quick settings and run **Generate** again. Whether
      the streaming connection survives airplane mode is **unconfirmed**; do this **last**, and Wi-Fi off alone is
      enough if airplane mode is greyed out.
7. **Capture the report:**
   - Tap **Copy results**. Clipboard sync between the streamed device and the laptop is **unconfirmed**. Try pasting
     on the laptop; if nothing comes through, open **Messages** or **Keep** on the device, paste, and screenshot.
   - Screenshots over ADB (implied by the ADB wording):
     `adb exec-out screencap -p > ~/nr-pixel9/01-status.png` (repeat with 02, 03, … after each step).
   - If ADB doesn't work, use the screenshot button in the Running Devices toolbar, if it has one (unconfirmed), or a
     laptop screenshot of the window.
   - Stop logcat (`kill %1`). `logcat.txt` holds routes and latencies. It doesn't contain the token or prompt text.
8. Optional, if minutes remain and status was `AVAILABLE`: `adb install -r ~/nr-judge.apk`, open Ask, ask
   "What do I do about tear gas?" and screenshot the route badge ("ON DEVICE").
9. **Return and Erase Device** from Device Manager's overflow menu. Unused minutes go back to the project.

## 3. If status stays `UNAVAILABLE` or `DOWNLOADABLE`
- Run `adb shell dumpsys package com.google.android.aicore | grep -E "versionName|enabled"`. Is AICore present and
  enabled?
- The fix on a real phone is updating **AICore** and **Private Compute Services** in the Play Store. Whether the
  streamed device has a Google account or Play Store access is **not stated**. Try opening the Play Store once and do
  not spend more than 3 minutes on it.
- Whether the streamed device has internet at all is **not stated**. A cloud call that works (`IN_CLOUD` in logcat)
  proves it has.
- Stop after ~15 minutes. Record the result as "Pixel 9 streamed: <status>" and fall back to the Chrome laptop test.

## 4. After the session
- Record the result in `docs/RESEARCH_HYBRID_ANDROID.md` (f) and the PLAN Decision log (status, route, latency, AICore
  version, fingerprint). Do not record the token or any device serial.
- **Delete the "pixel9-streaming" debug token** in Manage debug tokens unless it is the judge token.
- Honest limit for the pitch: a streamed lab device proves the code path runs on-device on a supported phone. It is
  not a phone-in-hand airplane-mode demo; say so in the video and Devpost text.

## 5. Results (owner fills in)
| Field | Value |
|---|---|
| Date / time (EAT), minutes used | |
| Device / Android build (fingerprint) | |
| AICore version | |
| `checkStatus()` before / after download | |
| Generate route + latency (online) | |
| Triage accepted? route | |
| Offline generate route (if done) | |
| Report text / screenshots saved in | `~/nr-pixel9/` (outside the repo) |
