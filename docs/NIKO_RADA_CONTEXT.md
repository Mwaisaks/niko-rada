# Niko Rada — product context

> Sections marked **AUDIT** are filled by Claude Code from the actual repo. Facts only; do not invent details.
> If this doc and the repo disagree, the repo wins and this doc gets fixed.

## What it is
Niko Rada ("stay alert", a common Kiswahili-Sheng phrase) is an offline, on-device crisis-safety agent for Kenya: protests,
tear gas, network blackouts, abductions/enforced disappearances, arrests. Open-source (Apache-2.0), Flutter, Android.
The name is **Niko Rada**. It was renamed "Kaa Rada" only for a Kaggle sprint; do not use that name.

Before this hackathon the app ran Gemma 4 E2B-it on-device through `flutter_gemma` + `flutter_gemma_litertlm`.
**On-device inference was never verified on a physical phone.** The owner's phone has 4 GB RAM, below the 6 GB floor the
old Gemma build assumed. The pipeline was proven only in a Kaggle notebook (`notebook/notebook.ipynb`).

## The product: the agent loop
1. **Triage** — classify the situation: type, severity, `is_active_incident`.
2. **Retrieve** — keyword/similarity retrieval over the vetted corpus (pure code, no model).
3. **Guide** — grounded, cited, numbered immediate-action steps from the retrieved cards only.
4. **Branch** — if Triage says active incident, extract a structured who/what/where/when report.
5. **Plan** — prioritised plan: DO NOW / WHO TO CONTACT / WHAT TO DOCUMENT, every item citing a card id.

Approach: RAG + prompt engineering. **No fine-tuning.**
- Corpus: 41 bilingual EN/Kiswahili knowledge cards across 6 domains (first_aid, evasion_safety, blackout_comms,
  documentation, rights, contacts). Contact numbers verified on each organisation's own site; provenance in
  `assets/corpus/SOURCES.md`.
- Grounded-only and cited. Out-of-corpus input is refused **before it reaches the model** (retrieval returns nothing →
  fixed refusal string).
- Responses in English, Kiswahili or Sheng (prompt-level; Sheng not natively reviewed).

## Who it is for
People in Kenya caught in a protest, blackout or targeted-grab situation who need calm, correct next steps and a way to
reach the right human help (lawyers, medics, rights orgs), plus the contacts they reach.

## Why it fits #BuildHybridAI (the story)
- **Privacy:** crisis details are the most sensitive data a person has. On-device inference keeps them on the phone.
- **Connectivity:** on-device inference works with no signal at all, which is exactly when shutdowns happen.
- **Reach:** most Kenyan phones cannot run Gemini Nano. The cloud fallback (with consent) means the app still helps
  people on budget phones while they have data.
- **Honest limitation (say it in the pitch):** a low-end phone without Nano, during a total shutdown, gets neither path.
  The app must still be useful then: the corpus cards and vetted contacts are readable without any model.

## Evidence / statistics
Statistics in `DESIGN.md` / `WRITEUP.md` (June 2024 ~40% connectivity drop, 450% rise in enforced disappearances
2023→2024, Electoral Vulnerability Index ~84%, 1,133 deaths in 2007–08) come from the owner's notes. **Re-verify each one
against its primary source before it goes into the README or Devpost text.** Do not add usage numbers, partnerships or
outcomes; none exist.

## Scope for this build
In: Firebase AI Logic hybrid inference behind one `InferenceService`, the five-step agent loop in the app, route badge +
fallback reason, cloud consent, safety gates, tests, polished main flow.

Out: HackSocial, the mesh relay, Briar handoff, LSK / Missing Voices sync, Sheng native review.
Only if time remains after Phase 4: PIN-gate + panic-wipe.

## AUDIT — current state of the repo (Mon 23 Nov 2026, at commit `dc848c8`)

**Biggest finding: the five-step agent loop exists only in the Python notebook, not in the Flutter app.** The app has
two model uses: grounded answer (Retrieve + Guide) and incident extraction (the Branch prompt, triggered manually from the
logger). Triage and Plan prompts and the loop orchestration live only in `notebook/notebook.ipynb` (cell 22,
`triage_prompt`, `plan_prompt`, `run_agent_loop`). Phase 1 must port them to Dart.

### Platform / stack
- Flutter (local: Flutter 3.44.7, Dart 3.12.2; CI pins 3.44.9), Android only in practice (`android/`, plus a `linux/`
  desktop target used for the failed desktop spike). No `ios/` or `web/` folder.
- Android: package / applicationId `com.nikorada.niko_rada`, `minSdk = 26`, `ndk.abiFilters = arm64-v8a`,
  AGP 9.0.1, Kotlin plugin 2.3.20, Gradle 9.1.0, Java/JVM 17. `MainActivity.kt` is a bare `FlutterActivity`.
- State: `provider` (`lib/providers/app_state.dart`). Storage: `shared_preferences` (`lib/services/store.dart`).
- Declared but unused deps: `drift`, `drift_flutter`, `sqlite3_flutter_libs`, `go_router`, `lottie`, `permission_handler`.
- CI: `.github/workflows/build-apk.yml` (manual dispatch) → analyze + debug arm64 APK artifact.

### Entry points and main user flows
- `lib/main.dart`: `AppState.init()` → splash → if no model, `DownloadScreen` (F0) → `_MainShell` with 4 tabs:
  - **Actions** `lib/ui/panic_grid.dart` (F2): scenario buttons → `ResponseScreen` with a preset query.
  - **Ask** `lib/ui/chat_screen.dart` (F1): free text → `ResponseScreen`.
  - **Log** `lib/ui/logger_screen.dart` (F3): free text → `ExtractorService.extract()` → saved report. Voice records
    audio but transcription is not implemented (`logger_screen.dart:71-74`, "transcription coming in next build").
  - **More** `lib/ui/settings_screen.dart` (F4): EN / Kiswahili / Sheng toggle.
- `lib/ui/response_screen.dart:38` streams `GemmaService.answer()` and renders it with `flutter_markdown`.

### How the model runs today
`flutter_gemma` ^1.3.1 + `flutter_gemma_litertlm` ^1.1.0, Gemma 4 E2B-it `.litertlm` (~2.6 GB) downloaded on first run from
`huggingface.co/litert-community/gemma-4-E2B-it-litert-lm`. One shared `InferenceChat` session is reused for every call
(`gemma_service.dart:103-106`), so calls are **not** independent single-turn requests: history accumulates across prompts.

### Every flutter_gemma call (exact paths)
| File:line | Call |
|---|---|
| `lib/services/gemma_service.dart:1-2` | imports `flutter_gemma`, `flutter_gemma_litertlm` |
| `lib/services/gemma_service.dart:30` | `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()])` |
| `lib/services/gemma_service.dart:36` | `FlutterGemma.hasActiveModel()` |
| `lib/services/gemma_service.dart:40-47` | `FlutterGemma.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm).fromNetwork(...)` + `withProgress` + `install()` |
| `lib/services/gemma_service.dart:104` | `FlutterGemma.getActiveModel(maxTokens: 1024)` |
| `lib/services/gemma_service.dart:105` | `_model.createChat(modelType: ModelType.gemma4)` |
| `lib/services/gemma_service.dart:111-113` | `chat.addQueryChunk(Message.text(...))`, `chat.generateChatResponseAsync()`, `TextResponse` |
| `lib/services/gemma_service.dart:120-121` | `_chat.close()`, `_model.close()` |
| `tool/preflight_generate.dart:10,27-30` | standalone probe: `FlutterGemma.installModel(...).fromFile(<scratch /tmp path>)` (not part of the app) |
| `android/app/src/main/AndroidManifest.xml:4-6,42-46` | foreground-service permissions + `ModelInstallService` for the download |

Indirect callers of `GemmaService`: `lib/providers/app_state.dart:20-21` (init, readiness), `lib/ui/download_screen.dart:46`
(install), `lib/ui/response_screen.dart:38` (`answer`), `lib/services/extractor.dart:22` (`extractIncident`, called from
`lib/ui/logger_screen.dart:55`).

### How each agent step builds its prompt
| Step | Where | Prompt |
|---|---|---|
| Triage | notebook only (cell 22, `triage_prompt`) | Classify → JSON `{type, severity, is_active_incident}`; types: tear_gas, abduction, checkpoint, network_blackout, medical, surveillance, protest_rights, other. |
| Retrieve | `lib/services/rag.dart:39-77` `retrieveTopK` (notebook mirrors it) | No model. See corpus below. |
| Guide | `lib/prompts/prompts.dart:10-35` `Prompts.groundedAnswer` | System-style rules (sources only, fixed bilingual refusal sentence, numbered steps, language instruction from `_languageInstruction`, mandatory bilingual disclaimer, `[Source Name]` citation) + `SOURCES:` from `RagService.formatForPrompt` (`[i] title (source)\ncontent`) + `USER SITUATION:`. |
| Branch | `lib/prompts/prompts.dart:38-56` `Prompts.extractIncident` | JSON-only extraction `{who, what, where, when, details, witnesses, source_reliability}`, `"unknown"` for gaps. Parsed by `lib/services/extractor.dart:24-45` (strip fences, fallback regex `{...}`). In the app it runs only from the logger, never conditionally on Triage. |
| Plan | notebook only (cell 22, `plan_prompt` + `format_for_plan`) | Sources keyed by card id; three numbered sections DO NOW / WHO TO CONTACT / WHAT TO DOCUMENT, each item cites `[card_id]`; includes Triage JSON. |
| (router) | `lib/prompts/prompts.dart:62-71` `Prompts.routeQuery` | Defined, **never called**. Domain detection is deterministic keywords instead. |

Prompt sizes matter for Nano (4000-token request cap, short outputs recommended): Guide with 4 cards and Plan are the
largest; measure them in Phase 1.

### Corpus: storage and retrieval
- `assets/corpus/cards.jsonl`: 41 cards, all `verified: true`, all with `content_sw`. Domains: first_aid 11,
  evasion_safety 7, blackout_comms 7, documentation 6, rights 6, contacts 4. Schema in `lib/models/knowledge_card.dart`.
  Provenance: `assets/corpus/SOURCES.md`. Bundled as a Flutter asset (`pubspec.yaml`).
- `RagService.loadCards()` loads once, drops unverified cards, and precomputes each card's word forms from **both**
  its English and Kiswahili text (people code-switch). Display/prompt text still uses the UI language.
- Matching (rewritten 23 Nov on `fix/retrieval-gate`, see `lib/services/rag.dart` class comment): tokenise, drop
  EN/SW stopwords and generic chat words and words under 3 letters; each word → itself + English stem + Kiswahili stem
  (≥ 4 letters) + optional synonym tag (police/officer/polisi, child/son/mtoto). **No raw prefix matching.**
- **Gate:** a card counts only if ≥ 2 distinct query words match it, or matched words cover ≥ 50% of the query's words.
  No card → refusal before any model call. Shared by Guide and extraction (`RagService.passesGate`).
- Ranking: sum of IDF weights of matched words + a small boost for domain keywords (whole words). Domain keywords no
  longer filter cards out (the old filter sent "arrested"/"record" to documentation and "call" to blackout_comms).
- `RagService.explain(query)` returns each passing card with the words that matched.
- Fixture results (`test/fixtures/retrieval_fixture.dart`, k = 4): EN+SW in-corpus top-1/2/4 went from 26/27/30 to
  33/36/36 of 36; Sheng panic queries from 3/5/6 to 6/6/6; off-topic wrongly accepted from 15 to 0 of 30.
- `notebook/notebook.ipynb` still contains the **old** retrieval port; it is no longer line-for-line with `rag.dart`.

### Refusal gate
`lib/services/gemma_service.dart:61-69`, inside `GemmaService.answer()`: if `retrieveTopK` returns no cards, yield a fixed
bilingual refusal string and return before any model call. Since 23 Nov the same gate guards incident extraction
(`ExtractorService.extract` → `RagService.passesGate`). The Guide prompt also carries a model-side refusal rule
(`prompts.dart:21`). The notebook loop stops at Retrieve
with the same refusal.

### Data stored locally
`shared_preferences` only: language, onboarded flag, incident reports as a JSON string list (`store.dart`). Audio
recordings go to a path from `path_provider` (`logger_screen.dart`). Model weights in flutter_gemma's storage. No encryption.

### Tests
- `test/widget_test.dart` is the only test. **It fails** (run 23 Nov 2026, `flutter test`): `ProviderNotFoundException`,
  because it pumps `NikoRadaApp` without the `ChangeNotifierProvider<AppState>` that `main()` adds. Stale test, not a
  regression. `flutter analyze`: no issues.
- No tests for retrieval, the refusal gate, prompts or extraction parsing.
- Run: `flutter pub get && flutter analyze && flutter test`.

### Secrets / config / licenses
- Scan of working tree and full git history (5 commits): no API keys, tokens, private keys, keystores, `.env`,
  `google-services.json` or service-account files. Nothing to rotate.
- `LICENSE` (Apache-2.0) added 23 Nov (commit `dc848c8`); the public repo had no license before that.
- `.gitignore` now covers `google-services.json`, `.env*`, keystores, `key.properties`, `local.properties`,
  service-account JSON and App Check debug-token files.
- Not secrets but worth cleaning before judging: `Building Niko Rada Offline App.md` (root) is an exported IDE chat log
  with local home-directory paths; `tool/preflight_generate.dart` hard-codes a scratch `/tmp` path.

### Known bugs / rough edges
- Agent loop missing from the app (see top).
- Shared chat session leaks earlier prompts into later ones (`gemma_service.dart:103-113`).
- `google_fonts` fetches fonts over the network at runtime (`lib/theme/app_theme.dart:46-49`); offline it falls back to the
  default font. Bundle the font or drop the package.
- Voice logging records audio but never transcribes it.
- No language-aware refusal for Sheng beyond reusing Kiswahili; Sheng unreviewed.
- `README.md`/`WRITEUP.md` still describe the Gemma build and "Build with Gemma: GDG on Campus UoN"; rewrite in Phase 5.

## Target architecture (proposal, confirm after the spike)
- Platform: Android, keeping the Flutter app. Firebase's hybrid on-device API on Android is native Kotlin
  (`com.google.firebase:firebase-ai` + `com.google.firebase:firebase-ai-ondevice`, experimental). A Kotlin wrapper around
  it is exposed through a Flutter platform channel and called only from a Dart `InferenceService`.
  `flutter_gemma` leaves the runtime path. Fallback if the Nano phone gate fails: Web (Chrome Desktop).
- Routing:
  - Default `PREFER_ON_DEVICE` for every agent step; crisis text goes to the cloud only with explicit, revocable consent.
  - No consent → on-device only (`ONLY_ON_DEVICE`); if Nano is unavailable, show corpus cards + contacts without a model
    ("limited mode").
  - Offline → on-device only.
- UI shows the route that served each response ("On your device" / "In the cloud", from the SDK's `inferenceSource`)
  and, on fallback, why.
- Firebase products: App Check (required; debug provider for the submission). Remote Config only if it shows in the demo.
- Safety layer around every model call: refusal gate before the model, grounded prompts, output checks, vetted contacts
  from the corpus/constants only (never from model output), visible disclaimers, human escalation path.
- Language risk: Firebase's docs say only English and Korean are validated for on-device inference. Kiswahili/Sheng output
  quality from Nano must be checked on the real phone.
