# Niko Rada

**An offline safety companion for when the network goes dark.**

Built for *Build with Gemma: GDG on Campus UoN* — Track: Civic Engagement & Accessibility.

Niko Rada is an Android app where **Gemma 4 E2B runs entirely on the phone**. Install it once on Wi-Fi; after that it gives grounded, cited, bilingual (English/Kiswahili/Sheng) safety guidance in airplane mode — during a protest, a blackout, or any moment the network is cut. Nothing it processes ever leaves the device.

"Niko Rada" is a common Kiswahili-Sheng phrase meaning "stay alert"; used here descriptively.

Full product spec: [`DESIGN.md`](DESIGN.md). Build plan: [`PLAN.md`](PLAN.md). Submission writeup: [`WRITEUP.md`](WRITEUP.md).

---

## Current status (honest, as of submission)

This project has two halves:

| Part | State |
|---|---|
| **The brain** — corpus, retrieval, prompts, RAG pipeline, real Gemma 4 E2B generation | ✅ Working, demoed in [`notebook/notebook.ipynb`](notebook/notebook.ipynb) |
| **The body** — the Flutter/Android app (`lib/`) — UI, engine wiring, panic grid, logger | ✅ Builds clean (`flutter analyze` passes), ⚠️ on-device inference not yet verified on hardware |

The Flutter app is fully written against the real `flutter_gemma` + `flutter_gemma_litertlm` API (see [`lib/services/gemma_service.dart`](lib/services/gemma_service.dart)), but we did not get a completed on-device Gemma generation running end-to-end before the deadline — see [`WRITEUP.md`](WRITEUP.md) for the specifics and what's blocking it. The Kaggle notebook proves the same corpus, retrieval logic, and prompt templates (ported line-for-line from `lib/`) produce real grounded, cited, multilingual answers.

**Why publish the app code anyway:** it's the intended shipping product, it compiles cleanly, and it's the fastest path to a working APK once the remaining device issues are resolved (see roadmap in `WRITEUP.md`).

---

## Repo layout

```
lib/
├── main.dart
├── models/            # KnowledgeCard, IncidentReport
├── services/
│   ├── gemma_service.dart   # init, installModel, answer(), extractIncident()
│   ├── rag.dart              # keyword/similarity retrieval over the corpus
│   ├── extractor.dart        # free text/voice → strict-JSON incident report
│   └── store.dart            # local persistence (reports, language pref)
├── prompts/prompts.dart      # grounded-answer + extraction prompt templates
├── providers/app_state.dart
├── theme/app_theme.dart
└── ui/                       # panic_grid, chat_screen, logger_screen, settings_screen, download_screen, response_screen
assets/corpus/
├── cards.jsonl        # 41 vetted, bilingual (en/sw) knowledge cards
└── SOURCES.md         # provenance + verification log for every card and contact
notebook/notebook.ipynb  # Kaggle-runnable proof of the same pipeline (real Gemma 4 E2B output)
```

## Running the app

```bash
flutter pub get
flutter run -d linux   # or macos/windows/android — same Dart API everywhere
```

On first run you'll hit the download screen (F0): it pulls the `.litertlm` Gemma 4 E2B weights (~2.6 GB) from `litert-community/gemma-4-E2B-it-litert-lm` on Hugging Face. Do this on Wi-Fi. After that, the app makes **zero network calls at inference time** — you can turn on airplane mode and it still answers.

Android: `minSdk 26` (required by `flutter_gemma`'s `.litertlm` engine). Requires the Android SDK (platform 36, build-tools 36.0.0) — `flutter doctor` will tell you if it's missing; see the Android setup note below if so. Build a debug or release APK with:

```bash
flutter build apk --debug --target-platform android-arm64    # verified building clean, see status below
flutter build apk --release --target-platform android-arm64
```

**Always pass `--target-platform android-arm64`.** `flutter_gemma_litertlm` only ships a prebuilt native library for `android_arm64` (no `armeabi-v7a`/`x86_64` build exists), so a non-restricted APK would install and then crash with `dlopen` on any non-arm64 device anyway. `android/app/build.gradle.kts` also declares `ndk.abiFilters = ["arm64-v8a"]`, but note: the Flutter Gradle plugin unconditionally resets `abiFilters` to its own full platform list on every build unless `-Pdisable-abi-filtering=true` is also passed (there's no clean `flutter build apk` CLI flag for that), so the declared `abiFilters` alone does **not** trim third-party AAR native libs (e.g. `sqlite3_flutter_libs`, the `jni` package) down to arm64-only — only `--target-platform android-arm64` reliably restricts Flutter's own engine + Dart AOT snapshot. In practice this leaves ~3 MB of harmless unused `armeabi-v7a`/`x86_64` `.so` files (`libsqlite3.so`, `libdartjni.so`) in the APK; the on-device inference layer (`libLiteRtLm.so` and its accelerators/companions) is correctly arm64-only either way since Native Assets only ever fetches the `android_arm64` bundle.

Verified locally (2026-07-25, desktop-only, no phone): `flutter build apk --debug --target-platform android-arm64` builds clean (`✓ Built build/app/outputs/flutter-apk/app-debug.apk`, ~196 MB), `flutter analyze` stays at 0 issues. **This confirms the build compiles and packages correctly — it does not confirm on-device inference runs**, which is still unverified on real hardware (see `docs/PHONE_TEST.md`).

### Android SDK setup (if `flutter doctor` shows no Android toolchain)

```bash
mkdir -p ~/Android/Sdk/cmdline-tools
curl -sSL -o /tmp/cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
cd /tmp && unzip -q cmdline-tools.zip && mv cmdline-tools ~/Android/Sdk/cmdline-tools/latest
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
yes | sdkmanager --sdk_root="$ANDROID_HOME" "platform-tools" "platforms;android-36" "build-tools;36.0.0"
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses
flutter config --android-sdk "$ANDROID_HOME"
```

Add the `export` lines to your shell profile (`~/.zshrc`/`~/.bashrc`) so they persist. No Android Studio needed — the command-line tools are sufficient. The NDK (28.2.13676358) and a couple of extra platforms get auto-installed by the first Gradle build itself (licenses must already be accepted, hence the step above).

### Known issue: `libLiteRtLm` native library

`flutter_gemma_litertlm`'s native library can fail to bundle correctly after certain rebuilds, surfacing as an opaque `dlopen: no such file` error on first inference. If you hit this:

```bash
flutter clean
rm -rf ~/.cache/flutter_gemma/native        # Linux; macOS: ~/Library/Caches/flutter_gemma/native
flutter pub get
```

This is a known limitation of Dart's Native Assets build hooks (shared-library "ownership" tracked across builds — see the package's own README troubleshooting section for the exact mechanism). It's the specific failure mode documented in `WRITEUP.md` — see there for the current status of resolving it on the desktop Linux build specifically (separate from the Android path this section covers).

## Running the notebook

`notebook/notebook.ipynb` is Kaggle-runnable top-to-bottom on a single GPU session (tested on a T4). It loads the real `google/gemma-4-e2b` weights via `transformers`, using the **exact same corpus and prompt templates** as the app — not a reimplementation — and demonstrates grounded/cited answers, trilingual generation, the refusal path, and incident extraction.

## Corpus & sources

Every knowledge card in `assets/corpus/cards.jsonl` cites a real authoritative source (ICRC, EFF Surveillance Self-Defense, Kenya Red Cross, KHRC, LSK, IMLU, Amnesty Kenya, KNCHR, Missing Voices). Every contact number was checked against the organisation's own site before inclusion; unverified numbers are excluded, never guessed. Full provenance log: [`assets/corpus/SOURCES.md`](assets/corpus/SOURCES.md).

## License

No license file is currently included; treat as all-rights-reserved pending an explicit license decision.
