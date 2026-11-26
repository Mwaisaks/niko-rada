# Research: remote Nano devices, Chrome on-device, Web hybrid, Flutter web effort (26 Nov 2026)

Time-boxed (about 30 min). **Confirmed** = read on the linked page. **Unconfirmed** = not found or inferred.

## Owner's result: Chrome on the 16 GB Ubuntu laptop
`await LanguageModel.availability()` returned **`'downloadable'`**. Chrome considers the machine eligible, and the model
can be downloaded after a user gesture. Chrome also warned "No output language was specified … supported output language
code: [de, en, es, fr, ja]", so pass `expectedOutputs: [{type: 'text', languages: ['en']}]`. Kiswahili is not among
the on-device languages, which matches the Android language design (Kiswahili/Sheng generation → cloud).

## ML Kit GenAI device list (live page, read 26 Nov)
Source: https://developers.google.com/ml-kit/genai, "Custom generation and agent device support" (Prompt API / direct
model access):

- **Gemini Nano 2:**
  - POCO F7 Ultra, F8 Pro, F8 Ultra, X7 Pro, X8 Pro
  - realme GT 7
  - Redmi Turbo 5
  - vivo T4 Ultra, X200 FE
  - Leitzphone powered by Xiaomi
  - Xiaomi 15, 15T, 15 Ultra, 17, 17T, 17 Ultra
- **Gemini Nano 3:**
  - Acer / ASUS / HP Googlebook 14, Dell XPS Googlebook, Lenovo Googlebook 15
  - Google Pixel 9, 9 Pro, 9 Pro XL, 9 Pro Fold
  - OPPO Reno 14 Pro 5G, Reno 15 Pro 5G, Reno 15 Pro Mini 5G, Reno 15 Pro Max 5G, Reno 16 Pro 5G
  - realme GT 7T
- **Gemini Nano 4:**
  - Google Pixel 10 / 10 Pro / 10 Pro XL / 10 Pro Fold, Pixel 11 / 11 Pro / 11 Pro XL / 11 Pro Fold
  - Honor 600 Pro, Magic 7, Magic 7 Pro, Porsche Design Magic 7 RSR, Magic 8 Pro, Magic V5, Magic V6, MagicPad 4
  - iQOO 13, 15
  - Lenovo Idea Tab Pro Gen 2, Legion Tab Gen 5 (8.8"), Yoga Tab Plus Gen 2
  - Motorola Edge 70 Pro, Edge 70 Pro+, Razr 60 Ultra, Razr Ultra 2025, Razr Fold, Signature
  - OnePlus 13, 13s, 15, 15R, Pad 3
  - OPPO Find N5, N6, X8, X8 Pro, X9, X9 Pro, X9s, X9 Ultra, X10, X10 Pro Max
  - POCO F9 Pro, X8 Pro Max
  - realme GT 7 Pro, GT 8 Pro
  - Samsung Galaxy S25, S25+, S25 Edge, S25 Ultra, S26, S26+, S26 FE, S26 Ultra, Tab S12+, Tab S12 Ultra, Z Flip7,
    Z Flip8, Z Fold7, Z Fold8, Z Fold8 Ultra, Z TriFold
  - Sharp AQUOS R11
  - Sony Xperia 1 VIII
  - vivo X200, X200 Pro, X200T, X300, X300 FE, X300 Pro, X300 Ultra, X500 Pro, X500 Pro Max, X Fold3 Pro, X Fold5,
    X Fold6
  - Xiaomi 15T Pro, 17T Pro, Pad Mini

Page note: "Model availability and version may vary depending on the device's RAM configuration, OS version, and AICore
update status." A separate, different table covers the summarization/proofreading/rewriting/image-description APIs.

**Differences from the owner's search results ("nano-v2" / "nano-v3"):**
- The live page never uses "nano-v2", "nano-v3" or any similar string. It only has the headings "Gemini Nano 2 / 3 / 4".
- `getBaseModelName()` is documented only as "return the version of Gemini Nano on a device". Its return format is
  **unconfirmed**.
- Galaxy S25 is listed under **Nano 4**, not Nano 3. Galaxy S24 is **not listed at all**. Pixel 9 = Nano 3,
  Pixel 10 = Nano 4.

## (a) Remote devices with an available on-device model
None of the services documents AICore or Gemini Nano on its devices. Whether the model is available there is
**unconfirmed for all three**.

| Service | Relevant devices | APK install | Cost / limits | Notes |
|---|---|---|---|---|
| **Android Studio device streaming** (https://developer.android.com/studio/run/android-device-streaming) | Pixel 9 / 9 Pro / 9 Pro XL / 9 Pro Fold (all **Nano 3**), Pixel 9a, plus partner labs (Samsung, Xiaomi, OPPO, OnePlus, vivo, Transsion); Pixel 10 not listed | Deploy from Studio / ADB over SSL (implied, not stated) | Spark: 30 free min per project per month; Blaze: +$0.15/min (https://firebase.google.com/docs/test-lab/usage-quotas-pricing) | Device is wiped and factory-reset after each session, so the model download (size unknown) happens every session. Interactive. |
| **Samsung Remote Test Lab** (https://developer.samsung.com/remote-test-lab) | Featured: Galaxy S26 Ultra, Z Fold8, Z Flip8 (all **Nano 4** on the ML Kit list) | Unconfirmed (device-list page did not load) | Unconfirmed | Interactive remote control. |
| **Firebase Test Lab** (https://firebase.google.com/docs/test-lab/android/available-testing-devices) | Device list only via `gcloud firebase test android models list` | Yes, but automated runs only (instrumentation/Robo/Game Loop) | Spark: 5 physical-device runs/day | Not interactive, so it can't film a demo. Could log `checkStatus()` from an instrumentation test. |

**Cheapest experiment:** a 15-minute device-streaming session on a Pixel 9 (free on Spark).
1. Install the debug APK.
2. Open the hybrid debug screen and press Check status.
3. Press Download and wait.
4. Press Check status again.

`AVAILABLE` plus an "answered by: ON DEVICE" reply would prove on-device inference. It probably can't be filmed as a
phone-in-airplane-mode demo, and Pixel 9 is Nano 3 (see the "Gemini Nano 4" question). The Samsung Remote Test Lab
S26 Ultra (Nano 4) is the next thing to try if RTL allows APK install and network.

## (b) Chrome on-device Prompt API: desktop requirements
**Confirmed** (https://developer.chrome.com/docs/ai/get-started, https://developer.chrome.com/docs/ai/prompt-api):
- **OS:** Windows 10/11, macOS 13+, **Linux**, or ChromeOS on Chromebook Plus. Not Android, iOS or other ChromeOS.
- **Disk:** at least 22 GB free on the volume holding the Chrome profile. The model is removed if free space later
  falls below 10 GB.
- **Hardware:** GPU with strictly more than 4 GB VRAM, **or** CPU with 16 GB RAM or more and 4 or more cores.
- **Network:** unmetered, for the one-time download.
- **Availability values:** `unavailable` / `downloadable` / `downloading` / `available`.
  - Pass the same options to `availability()` as to `prompt()`.
  - The download needs a user gesture (`navigator.userActivation.isActive`) before `create()`.
  - Debug via `chrome://on-device-internals`.
- **Languages:** "en", "ja", "es", "de", "fr" for input and output.

**Unconfirmed:**
- The minimum Chrome version for the web API. The Prompt API status table says Chrome 148 (web) and 138 (extensions);
  Firebase says Chrome 139+.
- The model's download size.

**Next step on the laptop:**
1. Open `chrome://on-device-internals`.
2. Trigger the download with a click (`LanguageModel.create({expectedOutputs:[{type:'text',languages:['en']}]})`).
3. Wait for `availability()` to return `'available'`.

## (c) Firebase AI Logic Web SDK, hybrid
**Confirmed** (https://firebase.google.com/docs/ai-logic/hybrid/web/get-started,
https://firebase.google.com/docs/ai-logic/hybrid/web/configuration-options):
- **Versions:** Firebase JS SDK **v12.5.0+** for on-device; Chrome on desktop **139+**. The default cloud model is
  `gemini-3.5-flash-lite` from JS SDK v13.0.0.
- **Setup:** `getGenerativeModel(ai, { mode: InferenceMode.PREFER_ON_DEVICE | ONLY_ON_DEVICE | PREFER_IN_CLOUD |
  ONLY_IN_CLOUD, onDeviceParams: { createOptions: { expectedInputs, expectedOutputs, initialPrompts } } })`.
- **Model download:** `model.initializeDeviceModel(cb)` after a user interaction. `ONLY_ON_DEVICE` waits for the
  download; the `PREFER_*` modes fall back to the cloud meanwhile.
- **Route reporting:** `result.response.inferenceSource` is `ON_DEVICE` or `IN_CLOUD` (JS SDK v12.5.0+). This is the
  same signal the Android bridge uses.
- **On-device limits:**
  - Single-turn text (no chat).
  - About 9,216 tokens on-device (the Android limit is about 4,000).
  - No function calling.
  - JSON/enum structured output is supported.
- **App Check is enforced.** For development, set `self.FIREBASE_APPCHECK_DEBUG_TOKEN = true` before
  `initializeAppCheck` and register the printed token. Production needs an attestation provider; the page doesn't name
  reCAPTCHA Enterprise (**unconfirmed**).

## (d) Effort estimate: Flutter web build (estimate only; not started)
**Already portable** (pure Dart, about 1,500 lines with tests):
- `lib/agent/` (Triage, Guide, Branch, AnswerFlow)
- `RagService` (loads the corpus with `rootBundle`, which works on web)
- `CloudConsentStore` and `StoreService` (`shared_preferences` has a web implementation)
- All screens

Since `flutter_gemma` was removed, the Dart code no longer imports `dart:io`.

**What would be needed:**
1. **`flutter create --platforms web .`** to add `web/`. Trivial.
2. **`WebHybridInferenceService implements InferenceService`:**
   - About 120 lines of Dart (`dart:js_interop`) plus about 100 lines of JS in `web/`.
   - The JS loads the Firebase JS SDK (v12.5+) as an ES module, initializes App Check and AI Logic, and exposes
     `generate(prompt, mode, maxOutputTokens) → {text, inferenceSource}` and `availability()`. `availability()` wraps
     `LanguageModel.availability()` with English expected outputs, plus `navigator.onLine`.
   - It reuses `resolveMode` and the consent logic unchanged.
   - The platform is picked in `AppState` with `kIsWeb`.
   - **Main risk:** JS interop and module loading under Flutter web, and App Check on web.
3. **Dependencies that fail or degrade on web:**
   - `record` + `path_provider` (Log tab voice note): hide the mic on web.
   - `drift`, `drift_flutter`, `sqlite3_flutter_libs`, `permission_handler`, `go_router`, `lottie`, `flutter_markdown`
     are **not imported anywhere in `lib/` any more**, so they can simply be removed from `pubspec.yaml`. That also drops
     the stray non-arm64 sqlite libraries from the APK.
4. **Offline on web:** the page must already be loaded. For the demo, use DevTools offline or the airplane toggle
   after load. A real offline PWA needs the Flutter service worker; a small extra.

**Estimates:**

| Scope | What it includes | Effort |
|---|---|---|
| Smallest demo | Ask screen + panic grid, English, route badge, consent sheet, limited mode; in Chrome on the laptop: `PREFER_ON_DEVICE` answers ON_DEVICE, and with Nano unavailable or forced `ONLY_IN_CLOUD` it answers IN_CLOUD. Log tab hidden. | ~1 day, including App Check web setup and one day-of-work risk buffer for interop |
| Parity with Android | Adds the Log tab, then polish and tests for the web service | +0.5–1 day |

**Cost to Android:** this would eat Fri 27 Nov (scope freeze) and push Android QA/APK work into Saturday. Recommendation
for the owner: only do it if on-device on a phone stays unproven **and** the laptop reaches `'available'`. Even then it
would be a second platform in the same submission, not a replacement for the Android work.
