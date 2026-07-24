# Niko Rada

**An offline safety companion for when the network goes dark.**

Built for *Build with Gemma: GDG on Campus UoN* — Track: Civic Engagement & Accessibility.

Niko Rada ("I'm aware" — Sheng/Kiswahili) is an Android app where **Gemma 4 E2B runs entirely on the phone**. Install it once on Wi-Fi; after that it gives grounded, cited, bilingual (English/Kiswahili/Sheng) safety guidance in airplane mode — during a protest, a blackout, or any moment the network is cut. Nothing it processes ever leaves the device.

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

Android: `minSdk 26` (required by `flutter_gemma`'s `.litertlm` engine). Build a release APK with:

```bash
flutter build apk --release
```

### Known issue: `libLiteRtLm` native library

`flutter_gemma_litertlm`'s native library can fail to bundle correctly after certain rebuilds, surfacing as an opaque `dlopen: no such file` error on first inference. If you hit this:

```bash
flutter clean
rm -rf ~/.pub-cache/hosted/pub.dev/flutter_gemma_litertlm-*/  # clear the native cache
flutter pub get
```

This is the specific failure mode documented in `WRITEUP.md` — see there for the current status of resolving it.

## Running the notebook

`notebook/notebook.ipynb` is Kaggle-runnable top-to-bottom on a single GPU session (tested on a T4). It loads the real `google/gemma-4-e2b` weights via `transformers`, using the **exact same corpus and prompt templates** as the app — not a reimplementation — and demonstrates grounded/cited answers, trilingual generation, the refusal path, and incident extraction.

## Corpus & sources

Every knowledge card in `assets/corpus/cards.jsonl` cites a real authoritative source (ICRC, EFF Surveillance Self-Defense, Kenya Red Cross, KHRC, LSK, IMLU, Amnesty Kenya, KNCHR, Missing Voices). Every contact number was checked against the organisation's own site before inclusion; unverified numbers are excluded, never guessed. Full provenance log: [`assets/corpus/SOURCES.md`](assets/corpus/SOURCES.md).

## License

No license file is currently included; treat as all-rights-reserved pending an explicit license decision.
