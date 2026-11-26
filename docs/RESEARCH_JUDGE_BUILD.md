# Research: Nano versions, judge build, API key restriction, APK size (26 Nov 2026)

Status legend: **Confirmed** = read in the linked page or measured here. **Unconfirmed** = inference or not found.
The Devpost Rules page returned HTTP 403 to automated fetching; the rules facts in `HACKATHON_BRIEF.md` are the owner's
reading, not re-checked here.

## (a) "Gemini Nano 4" in the rules vs the device lists
- **Confirmed:** the ML Kit GenAI overview (https://developers.google.com/ml-kit/genai) lists supported devices under
  three headings: **Gemini Nano 2** (e.g. Xiaomi 15, POCO X7 Pro, vivo X200 FE), **Gemini Nano 3** (e.g. Pixel 9 series,
  OPPO Reno 14 Pro 5G) and **Gemini Nano 4** (Pixel 10 and Pixel 11 series, Samsung Galaxy S25/S26 and Z Fold/Flip
  models). It says "Different versions of Gemini Nano run on different devices", that availability "may vary depending
  on the device's RAM configuration, OS version, and AICore update status", and that `getBaseModelName()` reports which
  version a device runs.
- **Confirmed:** neither the Prompt API page (https://developers.google.com/ml-kit/genai/prompt/android) nor the Firebase
  hybrid page (https://firebase.google.com/docs/ai-logic/hybrid/android/get-started) names a Nano version. Firebase says
  only that on-device works "on specific devices" and links to the ML Kit list.
- **Unconfirmed:**
  - The exact rules sentence about "Gemini Nano 4" (page not readable here).
  - Whether the rules require Nano 4 specifically, or just mean any Gemini Nano through Firebase AI Logic.
  - Whether "nano-v2" / "nano-v3" are the strings `getBaseModelName()` returns. No page uses those strings; they most
    likely correspond to the "Gemini Nano 2/3" headings.
- **Best reading:** "Gemini Nano 4" = the Nano 4 column (Pixel 10/11, Galaxy S25/S26, recent Z Fold/Flip). A Nano 2/3
  phone probably still runs the Firebase hybrid path, but whether that satisfies the rules is the owner's call.
- **Suggestion:** when a friend's phone reports `AVAILABLE`, also record `getBaseModelName()` (small addition to the
  spike's `deviceInfo`), so the video and Devpost text can name the exact version.

## (b) Smallest judge build that still passes App Check
Background, **confirmed** from the docs and from our own spike:
- The debug provider shows its token in logcat, or the token is created in the console (App Check → Apps → ⋮ → Manage
  debug tokens). The docs say "do not ship your debug token or debug build in production builds"
  (https://firebase.google.com/docs/app-check/android/debug-provider).
- Our build sets the `firebase_app_check_debug_token` resource for **debug builds only**, from `local.properties` or an
  environment variable. The SDK reads that resource only when the app is debuggable (`docs/RESEARCH_HYBRID_ANDROID.md`,
  from `javap`). A token built into a debug APK worked on the remote Galaxy A16.
- Firebase AI Logic says to register a production attestation provider (e.g. Play Integrity) "before releasing to end
  users".

| Option | Size (measured or estimated) | Works for a sideloaded judge APK? | Risk |
|---|---|---|---|
| 1. Debug APK + built-in debug token (what we have) | 208 MB file today; **~90 MB** after removing flutter_gemma (estimate: 190.5 − 100.0 MB of contents) | **Yes, verified** on the A16 | The token is extractable from a public APK. Anyone with it can call our AI Logic endpoint until it is revoked. |
| 2. Release-mode build (AOT) with `isDebuggable = true` in a separate "judge" build type, plus the same token resource | **~24 MB** after removing flutter_gemma (estimate: 123.4 − 100.0 MB) | **Unconfirmed:** should work, because the SDK checks "debuggable", not the build type. Needs one test build on the A16. | Same token exposure as option 1. Not Play-uploadable, which doesn't matter here. |
| 3. Release build + **Play Integrity** provider, set up for apps distributed outside Play | ~24 MB | **Unconfirmed.** Firebase's Android guide says Play Integrity supports apps "published on Google Play, outside Google Play, or both", but off-Play apps can't get `PLAY_RECOGNIZED`; `PlayIntegrityConfig.allowUnrecognizedVersion` (default false) has to be enabled. ([PlayIntegrityConfig](https://firebase.google.com/docs/reference/appcheck/rest/v1beta/projects.apps.playIntegrityConfig.md.txt), [App Check Android](https://firebase.google.com/docs/app-check/android?authuser=0), [verdicts](https://developer.android.com/google/play/integrity/verdicts?authuser=2)) | New Kotlin code, plus Play Integrity setup we haven't tested. Judges' devices must pass device integrity. Too risky before the scope freeze. |
| 4. Play Console internal testing track | ~24 MB | Needs each judge's email | Not practical. |

**Recommendation:** option 2 if one test build passes on the A16, otherwise option 1. Either way:
- Use a dedicated hackathon Firebase project with a quota or budget cap.
- Keep the token valid until at least 16 Dec.
- Revoke it after judging.
- Never put the token value in the repo, the README, the Devpost form or the testing instructions.

## (c) Restricting the Firebase API key to our package and signing certificate
- **Confirmed** (https://docs.cloud.google.com/docs/authentication/api-keys, Android section read via summary):
  1. Google Cloud console → APIs & Services → Credentials → the "Android key (auto created by Firebase)".
  2. Under **Application restrictions**, choose **Android apps**, then **Add**: package `com.nikorada.niko_rada` + the
     **SHA-1** of the certificate that signs the APK we publish. Save.
  - Only one restriction type applies at a time. The allowed-apps list replaces the previous one, so list every app.
  - CLI equivalent: `gcloud services api-keys update KEY_ID --allowed-application=sha1_fingerprint=…,package_name=…`.
  - Requests carry `X-Android-Package` / `X-Android-Cert` headers.
- **Confirmed** (https://firebase.google.com/docs/projects/api-keys):
  - Also set **API restrictions**, keeping **Firebase AI Logic API** (`firebasevertexai.googleapis.com`), **Firebase
    App Check API** and **Firebase Installations API** on the allowlist.
  - **Never** add the Generative Language (Gemini Developer) API to a Firebase key.
  - Firebase keys do not control access to backend resources; App Check does. A missing API gives
    `API_KEY_SERVICE_BLOCKED` / 403.
- **Our gap:** the release build is signed with the local **debug keystore** (`android/app/build.gradle.kts`). The
  SHA-1 registered must be the one of the keystore that signs the published APK. To print it:
  `cd android && ./gradlew signingReport` (prints the SHA-1, no secret). Back the keystore up; losing it means
  re-registering.
- **Unconfirmed:** that `firebase-ai` 18.2.0 sends the Android identification headers. Verify with one cloud call
  after restricting. A 403 means the restriction or the allowlist is wrong.

## (d) Why the debug APK is ~215 MB, and what removing flutter_gemma saves
Measured on 26 Nov from `unzip -lv` (compressed sizes, MiB). The debug APK file is 218.3 MB (208 MiB); its entries sum
to 190.5 MiB.

| Part | Debug | Release | Removable? |
|---|---|---|---|
| flutter_gemma native libs: `libLiteRtLm.so` 23.8, Qualcomm QNN HTP libs (`libQnnHtpV73/75/79/81Skel` ≈ 42.4, stubs, `libQnnHtp`, `libQnnSystem`), LiteRT GPU/WebGPU/OpenCL accelerators ≈ 18.3, samplers 2.6, `libGemmaModelConstraintProvider.so` 4.5 | **100.0** | **100.0** | **Yes**, removing flutter_gemma / flutter_gemma_litertlm |
| `libflutter.so` (engine) | 35.8 | 11.0 | Release mode only |
| Dart code: debug `kernel_blob.bin` 20.2 + snapshots (JIT) vs release AOT | ~25 | small | Release mode only |
| `libVkLayer_khronos_validation.so` (Vulkan validation layer from Flutter's **debug** engine artifact, not flutter_gemma) | 14.5 | 0 | Release mode only |
| dex (Kotlin/Java incl. Firebase) | 9.5 | smaller | No |
| non-arm64 `libsqlite3.so` / `libdartjni.so` | 3.1 | 3.1 | Possibly (drop `sqlite3_flutter_libs` if unused) |

- Release APK today: **129.7 MB** (contents 123.4 MiB), of which flutter_gemma is 100.0 MiB.
- **Removing flutter_gemma saves ~100 MiB in both build types:**
  - debug: ~90 MiB (estimate)
  - release-mode: ~24 MiB (estimate)

  Confirm by rebuilding after the removal.
