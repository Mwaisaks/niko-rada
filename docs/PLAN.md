# Plan — Niko Rada × #BuildHybridAI

Dates are EAT. Today is Mon 23 Nov. Hard deadline is Tue 1 Dec 1:00am EAT; we aim to submit Sun 29 Nov evening.
Repo: existing public `Mwaisaks/niko-rada` (no new repo). Pre-window baseline: commit `c745a39`.
The previous Gemma/Kaggle sprint plan is archived at `docs/archive/PLAN-gemma-sprint-2026-07.md`.

## Prize strategy
- **Floor (realistic target): Best Android App ($3,000)** — one polished Android app.
- **Stretch: Grand ($10k) / 1st ($7k) / 2nd ($4k)** — won on Impact + Quality of the Idea + a demo where the hybrid behaviour is
  obvious and the story (privacy + no-signal + reach) is credible. An excellent single platform can still win.
- Every task below should move one of the four judging criteria. If it doesn't, cut it.

## Platform decision
**Android, keeping the Flutter app.** Firebase's hybrid on-device API on Android is native Kotlin (`firebase-ai` +
`firebase-ai-ondevice`, experimental, on-device via the ML Kit Prompt API / Gemini Nano). A Kotlin platform-channel wrapper
around the Firebase hybrid SDK is called from a Dart `InferenceService`. `flutter_gemma` leaves the runtime path.
**Fallback if the Nano phone gate fails: Web (Chrome Desktop).**

Hardware facts and risks:
1. The owner's phone has 4 GB RAM and is not on the ML Kit Prompt API supported-device list → expected to hit the cloud path.
   Good for demoing fallback, useless for demoing on-device.
2. On-device needs a supported physical phone (Pixel 9+, Galaxy S25+, etc.). Emulators generally cannot run Nano. The owner
   will borrow a Nano-capable phone. Unlocked bootloaders are not supported.
3. On-device is validated for English and Korean only; Kiswahili/Sheng quality on Nano is unknown until tested.
4. On-device is experimental (Firebase) / beta (ML Kit); foreground-only; per-app quota (`BUSY`).

## Phase 0 — Mon 23 Nov: setup, audit, feasibility
- [x] Repo hygiene: Apache-2.0 `LICENSE`, `.gitignore` covers Firebase config/secrets, secrets scan of tree + history.
- [x] Audit the repo and fill the AUDIT section in `docs/NIKO_RADA_CONTEXT.md`; run existing tests.
- [x] Research the current Firebase AI Logic hybrid docs for Android (APIs, modes, device list, route indicator, Flutter support).
      → `docs/RESEARCH_HYBRID_ANDROID.md` (on branch `spike/hybrid-inference`).
- [x] **Spike** on branch `spike/hybrid-inference`: Kotlin wrapper over the Firebase hybrid SDK + MethodChannel + debug screen
      showing response and route. Builds cleanly without committed secrets.
      (Done 23 Nov: debug APK builds with no `google-services.json`. Not yet run on a phone.)
- [x] `docs/SPIKE_CHECKLIST.md` (on the spike branch): Firebase console steps + how to run on the 4 GB phone and the borrowed Nano phone.
- [ ] (Owner) Create Firebase project, enable Firebase AI Logic (Gemini Developer API), App Check debug token.
- [ ] (Owner) Run the spike: cloud path on the 4 GB phone; on-device path on the Nano phone; airplane-mode test.
- [x] Record platform decision + hardware plan in the Decision log (owner confirmed 23 Nov).
- Acceptance: spike works on a real phone (both routes seen); decision written down.

## Phase 1 — Tue 24 Nov: swap the AI layer (starts only after owner confirms the spike works on a real phone)
Audit finding that shapes this phase: the five-step loop exists only in the notebook (cell 22). The app has Retrieve +
Guide and a manually triggered extraction. Triage and Plan are new Dart work.

Scope, in priority order:
1. [ ] Dart `InferenceService` over the Kotlin platform channel (the only caller of a model). **Every model call is
       single-turn**: remove the reused `InferenceChat` session (`gemma_service.dart:103-113`).
       Port **Triage** to Dart (prompt from notebook `triage_prompt`), then run **Retrieve** and **Guide** on the new
       `InferenceService`.
       Progress 25 Nov (`feat/inference-interface`, not merged): `lib/inference/inference_service.dart` interface + test
       fake; Triage ported to `lib/agent/triage.dart` (gate first, one-line `type|severity|active` output, strict
       parser, tests). Not yet wired to the Kotlin bridge.
       Progress 25 Nov (`feat/phase1-core`, not merged until the Android/Web decision): `HybridInferenceService`
       wires the interface to the Kotlin bridge with consent-aware mode resolution and an `availability()` pre-flight;
       cloud consent model (`lib/inference/cloud_consent.dart`, default off, revocable); Guide ported
       (`lib/agent/guide.dart`); limited mode + answer flow (`lib/agent/answer_flow.dart`); Triage `arrest` type.
       Progress 26 Nov: the app's answer screen now runs `AnswerFlow` on `HybridInferenceService` (via `AppState`);
       the model-download gate is gone from `main.dart`. The incident logger still uses the old Gemma extractor until
       Branch replaces it.
2. [x] **Branch:** when Triage says `is_active_incident`, extract the structured who/what/where report automatically,
       behind the same out-of-corpus gate as Guide. (26 Nov: `lib/agent/branch.dart`, Log tab; `test/branch_test.dart`.)
3. [ ] **Plan** (DO NOW / WHO TO CONTACT / WHAT TO DOCUMENT): only if time remains after the Phase 2 routing and UI work.
4. [x] Remove `flutter_gemma` / `flutter_gemma_litertlm` and the model-download screen from the runtime path.
       (26 Nov, `feat/remove-gemma`: all Gemma code, the HYBRID_AI flag and the arm64-only ABI filter removed.)

Prompt budget (Nano limits):
- Keep each on-device request under ~4,000 tokens; aim for replies under 256 tokens (`maxOutputTokens`).
- Retrieve **2 cards** instead of 4, unless testing on the Nano phone shows 4 fits the budget.
- Measure each prompt's size (Triage, Guide, Branch, Plan) on the real phone and note it here.

Language design (to test on the borrowed phone):
- Use Nano for short, English-friendly work: triage, card selection, report structuring.
- Show the **verified Kiswahili text from the corpus cards directly** instead of generating Kiswahili on-device.
- Free-form Kiswahili or Sheng generation goes to the cloud, with consent.
- Acceptance: no direct model calls outside `InferenceService`; Triage → Retrieve → Guide (+ Branch for active incidents)
  demoable on-device and in cloud.

## Phase 2 — Wed 25 Nov: hybrid behaviour and UX
- [x] Routing rules (default on-device; cloud only with consent; offline → on-device only; no Nano + no consent → limited mode)
      with unit tests (supported / unsupported / offline / cloud error / consent denied).
- [x] Route badge + fallback reason in the UI; clear offline state and "no on-device model" state.
      (26 Nov: `RouteStatusStrip` on Actions/Ask/answer screens, `RouteBadge` per answer, limited-mode banner.)
- [x] Consent screen for cloud use of crisis content; revocable in Settings.
      (26 Nov: `lib/ui/consent_sheet.dart`, opened from the status strip, the limited-mode banner or Settings.)
- Acceptance: toggling airplane mode visibly changes behaviour, no crashes.

## Phase 3 — Thu 26 Nov: safety, design, Firebase extras
- [ ] Safety layer: refusal gate stays before the model, output checks, vetted contacts constants, human escalation path,
      disclaimers, prompt-injection tests.
- [ ] Design pass on the main flow (consistent, mobile-first, accessible).
- [ ] Only if it improves the demo: Remote Config for routing defaults.

## Phase 4 — Fri 27 Nov: QA and freeze
- [ ] Test matrix: online/offline × Nano present/absent × consent given/denied × cloud error × EN/SW/Sheng.
      Include a row for **on-device Kiswahili/Sheng output quality** (Nano phone, airplane mode).
      Log results in `docs/TEST_MATRIX.md`.
- [ ] Release APK built and installed from a clean state on both phones.
- [ ] **Feature freeze at end of day.**
- [ ] Only if time remains: PIN-gate + panic-wipe.

## Phase 5 — Sat 28 Nov: submission assets
- [ ] README: value proposition, architecture diagram, where Firebase AI Logic is called, setup/run steps, license, limitations.
- [ ] "What we built during the window" summary (diff against `c745a39`, honest).
- [x] Statistics verified by the owner (26 Nov). Remaining: fill in each source link in the README Sources table
      (`docs/README_PLAN.md`).
- [ ] Devpost text: Firebase AI Logic usage, features, value proposition.
- [ ] Demo video script (≤ 3:00): problem (20s) → airplane mode, on-device answer (45s) → budget phone online, cloud with
      consent (45s) → safety/escalation (30s) → architecture + impact + honest limitation (30s). Filmed on real phones.

## Phase 6 — Sun 29 Nov: submit
- [ ] Final video uploaded to YouTube (public), links tested.
- [ ] Repo clean (no secrets, license visible in About, README final), APK attached to a GitHub release.
- [ ] Submit on Devpost with **Android** selected, by evening EAT. Monday is buffer only.

## Out of scope
- **iOS** (Apple Foundation Models via Firebase AI Logic): out of scope for this build; listed as future work in the README.
  Do not work on it. (Owner, 26 Nov.)
HackSocial, mesh relay, Briar handoff, LSK / Missing Voices sync, Sheng native review.

## Decision log
(Claude Code: record decisions here with date and reason, only after the owner confirms.)

### 2026-11-23 — Platform: Android (Flutter + Kotlin bridge). Confirmed by owner.
- Keep the Flutter app. A Kotlin wrapper around Firebase AI Logic hybrid inference (`firebase-ai` 18.2.0 +
  `firebase-ai-ondevice` 16.0.0-beta08) is exposed over a MethodChannel and called only from a Dart `InferenceService`.
- Why: `firebase_ai` (Flutter) has no hybrid/on-device API; the native Android SDK does, and the spike compiles against
  it. Best Android App is the floor prize, and a real Flutter app with visible on-device/cloud routing fits it.
- Hardware plan: owner's 4 GB phone (not on the Prompt API device list) demonstrates the cloud path; a borrowed
  Nano-capable physical phone demonstrates on-device. Emulators are not used for on-device.
- **Kill rule:** if no Nano-capable physical phone shows the on-device model as `AVAILABLE` by **Wed 25 Nov, 12:00 EAT**,
  switch to **Web (Chrome Desktop)**.

### 2026-11-23 — Phase 1 scope and language design. Confirmed by owner.
- Priority: Triage → Retrieve/Guide on `InferenceService` → Branch (auto extraction, gated) → Plan only if time remains.
- Single-turn calls only; 2 retrieved cards by default; on-device for short English-friendly work, verified corpus
  Kiswahili shown directly, free-form Kiswahili/Sheng generation in the cloud with consent.

### 2026-11-23 — Leave git history alone (chat log stays in the first commit). Confirmed by owner.
- `Building Niko Rada Offline App.md` (exported IDE chat log) was removed from the tree but remains in commit `cf5e47a`.
- Why: it holds no secrets (only a local username and folder paths). Rewriting history would change every commit hash,
  including the pre-window baseline `c745a39` used for the "what we built during the window" summary, and would need
  force-pushes of every branch plus a GitHub cache purge.

### 2026-11-25 — Spike result, phone 1: Samsung Galaxy A16 (SM-A165F), Android 16, 3.8 GB RAM. Reported by owner.
- **Cloud path works** through Firebase AI Logic (`PREFER_ON_DEVICE` → `IN_CLOUD`, fallback reason shown). Latency:
  first call 11.8 s, then 1.0–4.4 s.
- **On-device: `UNAVAILABLE`, as expected** (A-series is not on the Prompt API device list). `download()` reported
  "completed" five times while status stayed `UNAVAILABLE`: trust `checkStatus()`, never the download result.
- **Offline with no Nano:** every call failed in 50–95 ms with a generic `UnknownException` ("Something unexpected
  happened."). This is the "neither path" case; the app must map it to a typed error and fall back to limited mode.
- **Triage format: 6 of 6 replies accepted** by the strict parser (all via cloud). The Sheng police-arrest situation was
  labelled `abduction`; the type list has no "arrest" type (taxonomy gap, not a format failure).
- App Check: a debug token built into the APK worked for a remote phone (token value not recorded anywhere).
- **Kill rule status:** the deadline (Wed 25 Nov 12:00 EAT) passed with no Nano-capable phone tested. On-device
  remains unproven. Decision on Android vs Web: **pending owner**.

### 2026-11-25 — Limited mode, tap-to-call, Triage "arrest" type. Confirmed by owner.
- Limited mode (`docs/LIMITED_MODE.md`): show **2 cards**; **always show the emergency contacts card**
  (`contacts-001`); detect with a **pre-flight check plus the `NO_ROUTE` backstop**; **defer the incident form**.
- Tap-to-call: add in Phase 2 if the dependency is small (a `tel:` dialer link).
- Triage gets an **`arrest`** type (the Sheng police-arrest situation was labelled `abduction` because none existed).
  Keep the strict one-line format.

### 2026-11-25 — Android vs Web: decision due Thu 26 Nov 09:00 EAT. Rule confirmed by owner.
Friends are testing the spike APK on their phones. For each report:
- On-device status `AVAILABLE` **and** Generate/Triage steps show "answered by: ON DEVICE" → **Android confirmed**.
- `UNAVAILABLE` after AICore updates and a download attempt → **that phone is unsupported** (not a verdict on Android).
- No usable report by Thu 26 Nov 09:00 EAT → **decide together with the owner**.
Nothing merges into `main` from `feat/phase1-core` until this is decided.

### 2026-11-26 — Platform stays Android; on-device still unproven. Confirmed by owner.
- No friend's phone has reported on-device `AVAILABLE` with an "answered by: ON DEVICE" reply.
- Decision: keep building Android (all remaining work is Dart/UI). Keep looking for a Nano-capable phone until the
  scope freeze (end of Fri 27 Nov). If none is found, the demo shows cloud + limited mode, and the video and Devpost text
  say plainly that on-device inference was not filmed on a supported phone.
- `feat/phase1-core` may now merge into `main`.

## Open risks (from Phase 0 research; unconfirmed)
1. **On-device Kiswahili/Sheng quality.** Google validates only English and Korean on-device. Mitigation: language design
   above; test on the Nano phone (Phase 4 matrix row).
2. Behaviour of `PREFER_ON_DEVICE` / `ONLY_ON_DEVICE` when offline on a phone without Nano (expected: error; that is the
   "neither path" limitation). Test: `SPIKE_CHECKLIST.md` C.5.
3. Whether `systemInstruction` is honoured on-device (not documented). Keep all rules inside the prompt text.
4. Whether App Check requires registering Play Integrity before debug tokens can be added in the console.
5. Cloud-model pricing/quota on the free plan (pricing and quota pages not read). Default model `gemini-3.5-flash-lite`.
6. Emulator support for on-device (docs silent; assume none).
7. Model names were cross-checked against two docs pages only; the models page was partly truncated when read.
8. ~~Out-of-corpus gate is too permissive~~ **Resolved 23 Nov** (`fix/retrieval-gate`): whole-word/stem matching,
   ≥ 2 matching words or ≥ 50% coverage, domain keywords boost instead of filter. Fixture: 0 of 30 off-topic checks
   accepted (was 15); in-corpus top-4 36/36 (was 30/36), Sheng panic 6/6. Residual: an off-topic text that happens to
   share two corpus words (e.g. "share photos") would still pass; synonyms are a short hand-written list.
   The notebook still holds the old retrieval port.
   25 Nov follow-up (`fix/retrieval-2`): fixed three gaps found by the spike's Triage test ("teargas" as one word,
   object markers like "ananifuata", abduction text ranking the bleeding card above the witnessing card).
