# Niko Rada — PLAN.md

Phased execution plan for the 2-day sprint, driving Codex/Claude Code against `DESIGN.md`.
**Deadline: submission due Jul 24, 2026 (~2 days). Scope is fixed; do not add features.**
**Delivery: installable Android APK (Flutter + on-device Gemma 4 E2B), with a clonable notebook as fallback.**

**Golden rule:** the app makes **zero network calls at inference time**. The only network use is the one-time model download and the *optional, user-initiated* future report send.

> **Status at submission:** this is the phased plan as written pre-sprint; checkboxes below were not all updated live during the build. Phases 0–6 code exists (app, corpus, retrieval, prompts, notebook); what did **not** land in time is verified on-device inference (Phase 0's acceptance bar) and the APK/hardware demo (Phase 5). See [`WRITEUP.md`](WRITEUP.md) for what actually happened and why — this file is kept as-is for the build history, not edited retroactively to match.

---

## Device & environment strategy (read first)

**You do not need a good phone to build this.** Develop on your laptop; only the final demo needs a real device.

- **Primary dev environment: Flutter *desktop* build on your laptop** (macOS/Windows/Linux — flutter_gemma runs the same Dart API on all of them). Real Gemma 4 inference, lots of RAM, fast iterate loop, no phone flashing. This is where Claude Code / Antigravity do the work.
- **Emulator:** fine for quick UI iteration only. Do NOT rely on it for Gemma inference (no real GPU delegate; slow/flaky).
- **Your Galaxy A16:** verify the RAM variant first (4 / 6 / 8 GB). If 6 GB+, it's a usable spike device; if 4 GB, treat any success as a bonus, not the plan.
- **Final demo:** a borrowed 6 GB+ Android at the hackathon, airplane mode, recorded on the day. Record a **desktop-build backup video beforehand** so you're never empty-handed.
- **Ultimate fallback:** Kaggle notebook (build in parallel, Phase 6).

**Go/no-go:** if the Phase 0 spike (Gemma 4 E2B generating offline) won't work on *either* desktop or a real phone within the first few hours, drop to the notebook path early — not at hour 40.

---

## Timebox

| Day | Focus | Phases |
|-----|-------|--------|
| **Day 1 (engine on the phone)** | flutter_gemma running Gemma 4 E2B offline + corpus + grounded answers | 0, 1, 2, 3 |
| **Day 2 (product)** | Safety UX, languages, logger, harden offline, APK, demo, writeup | 4, 5, 6, 7 |

If Day 1 slips: cut corpus to ~25 cards and drop the logger before you compromise the offline-grounded core.

---

## Repo structure (Flutter)

```
niko_rada/
├── README.md                 # incl. the libLiteRtLm dlopen fix + build steps
├── DESIGN.md
├── PLAN.md
├── pubspec.yaml              # flutter_gemma, flutter_gemma_litertlm, drift, etc.
├── lib/
│   ├── main.dart
│   ├── services/
│   │   ├── gemma_service.dart     # init, installModel, chat, generate (engine-agnostic iface)
│   │   ├── rag.dart              # load cards, keyword/similarity select top-k
│   │   ├── extractor.dart       # free text/voice → strict-JSON report
│   │   └── store.dart           # Drift/SQLite: reports, language pref, chats
│   ├── prompts/prompts.dart     # grounded / extraction / (optional) router prompts
│   ├── ui/
│   │   ├── panic_grid.dart      # F2 big bilingual buttons
│   │   ├── chat_screen.dart     # F1
│   │   ├── logger_screen.dart   # F3
│   │   ├── settings_screen.dart # F4 language toggle
│   │   └── download_screen.dart # F0 first-run install + Limited Mode
│   └── l10n/                    # en / sw UI strings
├── assets/
│   ├── corpus/cards.jsonl       # vetted knowledge cards (bilingual fields)
│   └── corpus/SOURCES.md        # provenance + verification log
├── notebook/
│   └── notebook.ipynb              # clonable Kaggle notebook (submission-safe fallback)
└── assets/demo_backup.mp4        # recorded airplane-mode run (insurance)
```

---

## Phase 0 — flutter_gemma spike on desktop (½ day, do FIRST)

**Goal:** prove Gemma 4 E2B loads and generates offline — on your laptop first, so a phone is never the blocker.

- [ ] Verify your A16 RAM variant (bonus spike target only if 6 GB+).
- [ ] Start from an existing minimal flutter_gemma example app (e.g. the public "Gemma 4 E2B on-device" Flutter samples) — do NOT start from a blank project.
- [ ] Add `flutter_gemma` + `flutter_gemma_litertlm`; `FlutterGemma.initialize([LiteRtLmEngine()])`.
- [ ] **Run the desktop build on your laptop** (`flutter run -d macos|windows|linux`). Real inference, fast loop.
- [ ] `installModel(...).fromNetwork('<gemma-4-E2B-it.litertlm URL>').install()` — confirm the exact ungated litert-community URL/tag.
- [ ] Create chat, generate one response. Then **disconnect the network** and confirm it still generates.
- [ ] Note the `libLiteRtLm` dlopen fix (flutter clean + clear native cache) in README now.
- [ ] `git init`, push public repo.
- [ ] (Optional, timeboxed) repeat the offline generate on the A16 if it's 6 GB+.

**Acceptance:** laptop desktop build, network off, returns a Gemma 4 E2B completion. Latency recorded.
**If this fails within a few hours → invoke the notebook fallback.** Don't grind.

> The phone comes back only in Phase 5 (APK) and the hackathon-day demo. Everything before that is desktop.

---

## Phase 1 — Corpus curation (½ day, parallelisable)

**Goal:** 40–80 vetted, bilingual (en/sw) knowledge cards.

- [ ] `assets/corpus/cards.jsonl` per DESIGN §9 schema (bilingual `_en`/`_sw` fields).
- [ ] Cover all domains: first_aid, evasion_safety, blackout_comms, documentation, contacts, rights.
- [ ] Content ONLY from authoritative sources (EFF SSD, Access Now, ICRC, Amnesty Kenya, KHRC, Missing Voices, PBI, LSK); paraphrase concise + actionable; attribute each.
- [ ] **Verify every contact** against official sites; unverified → `"verified": false` and excluded. Never guess a number.
- [ ] Provide Kiswahili for the 5 demo cards at minimum; rest can be en-only + translated at generation time.
- [ ] Log provenance in `SOURCES.md`.

**Priority (build first):** tear gas · being followed (de-escalate/flight) · network down—reach people · witnessed abduction—what to record · prepare my phone.

**Acceptance:** every card sourced; contacts verified-or-excluded; 5 demo cards strong and bilingual.

---

## Phase 2 — Retrieval (½ day)

**Goal:** given a query (+language), select the most relevant cards, offline, no extra native surface.

- [ ] `rag.dart`: load cards; keyword + simple similarity scoring; return top-k (k≈3–4), optionally domain-filtered.
- [ ] Pick the language field to inject based on the current setting.
- [ ] (Roadmap note in code: swap to flutter_gemma embeddings + vector store later.)

**Acceptance:** "tear gas in my eyes" / "machozi machoni" selects the tear-gas card top-1.

---

## Phase 3 — Gemma integration: grounded answer + extraction (½ day)

**Goal:** the three model uses (DESIGN §11), engine-agnostic behind `gemma_service.dart`.

- [ ] `prompts.dart`: grounded-answer prompt (with `{{language}}`), extraction prompt, optional router prompt.
- [ ] `gemma_service.answer(query, lang)` → (optional route) → retrieve → grounded generate, streamed, cited, disclaimered; refuse if uncovered (below similarity threshold).
- [ ] `extractor.extract(text)` → valid JSON per schema; `"unknown"` for gaps; validate it parses; no invention.
- [ ] Deterministic keyword fallback if a model call returns malformed output.

**Acceptance:** offline, `answer("tear gas","sw")` gives an ordered, cited, Kiswahili response; `extract(messy_text)` returns parseable JSON; refusal path fires on out-of-corpus questions.

---

## Phase 4 — Safety UX + languages + logger (1 day)

**Goal:** an interface a scared person can use, offline, on a small screen.

- [ ] `download_screen.dart` (F0): resumable download w/ backoff, progress, size check, "tumia Wi-Fi" warning, Limited Mode if no model.
- [ ] `panic_grid.dart` (F2): large high-contrast bilingual buttons; each pre-seeds a query → `answer()`. Stream results as numbered steps; show source + disclaimer.
- [ ] `chat_screen.dart` (F1): free-text → `answer()`.
- [ ] `logger_screen.dart` (F3): text or voice (on-device audio) → `extract()` → show structured report → save via `store.dart` to pending-send queue; list saved; "clear all".
- [ ] `settings_screen.dart` (F4): En / Kiswahili / Sheng toggle; persist; drives UI strings + model output language.
- [ ] Design: AMOLED-dark, big fonts, calm colour, minimal typing.

**Acceptance:** full live scenario (DESIGN §14) runs end-to-end in airplane mode, including a language switch and a voice report.

---

## Phase 5 — Offline hardening & APK (½ day)

**Goal:** guarantee + prove the offline claim; produce the installable artifact.

- [ ] Audit: no external API, no CDN fonts, no telemetry in the request path.
- [ ] Cold-start test with network OFF after model download (desktop first).
- [ ] Tune k / thresholds / max tokens for fast, calm answers on CPU.
- [ ] `flutter build apk --release`; attach the APK to a GitHub release.
- [ ] **Record a desktop-build backup video now** (network off) — insurance before you ever touch a phone.
- [ ] At the hackathon: install the APK on a borrowed 6 GB+ Android, run in airplane mode, record `demo_backup.mp4` there.

**Acceptance:** release APK builds; offline run verified on desktop; backup video exists before demo day; borrowed-phone run recorded at the venue.

---

## Phase 6 — Notebook fallback (parallel insurance, ½ day)

**Goal:** a submission-safe demo that never depends on the device build.

- [x] `notebook/notebook.ipynb`: runs the grounded RAG + Gemma pipeline (via any available Gemma 4 runner) end-to-end, showing grounded answers + extraction on the same corpus.
- [ ] Make it clonable and run top-to-bottom.

**Acceptance:** notebook runs clean start-to-finish; usable as the "live demo" attachment if the APK isn't ready.

---

## Phase 7 — Writeup & submission (½ day)

Writeup skeleton (<1500 words, map to rubric):
1. **Title + subtitle** — "Niko Rada: an offline safety companion for when the network goes dark."
2. **Problem** (~250w) — blackouts + tracing, 2024/2025 events, 84% EVI stat. Human.
3. **Insight** (~150w) — info infrastructure cut Kenya's 2007→2013 death toll; Niko Rada assumes the network is *down*.
4. **How it works + how we used Gemma 4** (~500w) — Flutter on-device, install-then-offline, grounded gen + extraction + multilingual/audio, RAG over a vetted corpus. The 30% section — concrete, with the flutter_gemma stack.
5. **Why on-device Gemma** (~200w) — availability under blackout + privacy-by-architecture vs documented surveillance.
6. **Local languages** (~100w) — En/Kiswahili/Sheng, prompt-level, native-speaker-reviewed; honest about Sheng.
7. **Responsible AI + honest limitations** (~150w) — grounded-only, verified contacts, de-escalation, tool-must-not-become-the-threat; Sheng/CPU/hardware-floor caveats.
8. **Challenges & roadmap** (~150w) — device debugging, native-lib fix, scope cuts; fine-tune/backend/mesh/iOS as next.

Submission checklist:
- [ ] Public code repo linked (well-documented; Gemma 4 implementation clearly visible)
- [ ] Live demo attached: **APK release link** + backup video, AND/OR clonable notebook
- [ ] Track: **Civic Engagement & Accessibility**
- [ ] Writeup ≤ 1500 words
- [ ] **Submitted** (not draft) before deadline
- [ ] Confirm this edition's team-size requirement + all members joined the team

**Acceptance:** entry shows as submitted, not draft, with repo + demo attached.

---

## Fallback path (if Phase 0 fails or no device)

Don't lose the hackathon to a toolchain. If on-device Flutter won't come together:
1. **Ship the notebook as the primary demo** (Phase 6) — grounded RAG + Gemma 4, multilingual, fully reproducible. The hackathon explicitly accepts a clonable notebook.
2. Keep the *entire* writeup story intact — the on-device app becomes the "productionisation" you spec in DESIGN.md and show partially.
3. Optionally wrap the pipeline in a simple mobile-styled web demo (MediaPipe web LLM / a Python service) to *show* the UX, and be honest that the native APK is in progress.

## Degrade-gracefully order (if behind, in any path)

1. Keep: F1 grounded chat + F2 panic buttons, offline, 5 demo cards. That alone carries the story.
2. Drop first: F3 logger extraction (→ roadmap).
3. Drop second: voice input, then the optional router.
4. Never drop: **the offline guarantee and grounded-only answers.** That's the identity of the product.
