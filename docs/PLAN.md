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
- [x] **Spike** on branch `spike/hybrid-inference`: Kotlin wrapper over the Firebase hybrid SDK + MethodChannel + debug screen
      showing response and route. Builds cleanly without committed secrets.
      (Done 23 Nov: debug APK builds with no `google-services.json`; findings in `docs/RESEARCH_HYBRID_ANDROID.md`.)
- [x] `docs/SPIKE_CHECKLIST.md`: Firebase console steps + how to run on the 4 GB phone and the borrowed Nano phone.
- [ ] (Owner) Create Firebase project, enable Firebase AI Logic (Gemini Developer API), App Check debug token.
- [ ] (Owner) Run the spike: cloud path on the 4 GB phone; on-device path on the Nano phone; airplane-mode test.
- [ ] Record platform decision + hardware plan in the Decision log (only after owner confirms).
- Acceptance: spike works on a real phone (both routes seen); decision written down.

## Phase 1 — Tue 24 Nov: swap the AI layer (starts only after owner confirms the spike works on a real phone)
- [ ] Dart `InferenceService` over the Kotlin platform channel; migrate every existing model call to it.
- [ ] Port the five-step agent loop (Triage, Retrieve, Guide, Branch, Plan) from the notebook into Dart; Triage and Plan
      prompts are new in the app.
- [ ] Remove `flutter_gemma` / `flutter_gemma_litertlm` and the model-download screen from the runtime path.
- Acceptance: no direct model calls outside `InferenceService`; agent loop demoable on-device and in cloud.

## Phase 2 — Wed 25 Nov: hybrid behaviour and UX
- [ ] Routing rules (default on-device; cloud only with consent; offline → on-device only; no Nano + no consent → limited mode)
      with unit tests (supported / unsupported / offline / cloud error / consent denied).
- [ ] Route badge + fallback reason in the UI; clear offline state and "no on-device model" state.
- [ ] Consent screen for cloud use of crisis content; revocable in Settings.
- Acceptance: toggling airplane mode visibly changes behaviour, no crashes.

## Phase 3 — Thu 26 Nov: safety, design, Firebase extras
- [ ] Safety layer: refusal gate stays before the model, output checks, vetted contacts constants, human escalation path,
      disclaimers, prompt-injection tests.
- [ ] Design pass on the main flow (consistent, mobile-first, accessible).
- [ ] Only if it improves the demo: Remote Config for routing defaults.

## Phase 4 — Fri 27 Nov: QA and freeze
- [ ] Test matrix: online/offline × Nano present/absent × consent given/denied × cloud error × EN/SW/Sheng.
      Log results in `docs/TEST_MATRIX.md`.
- [ ] Release APK built and installed from a clean state on both phones.
- [ ] **Feature freeze at end of day.**
- [ ] Only if time remains: PIN-gate + panic-wipe.

## Phase 5 — Sat 28 Nov: submission assets
- [ ] README: value proposition, architecture diagram, where Firebase AI Logic is called, setup/run steps, license, limitations.
- [ ] "What we built during the window" summary (diff against `c745a39`, honest).
- [ ] Re-verify every statistic against its primary source before using it.
- [ ] Devpost text: Firebase AI Logic usage, features, value proposition.
- [ ] Demo video script (≤ 3:00): problem (20s) → airplane mode, on-device answer (45s) → budget phone online, cloud with
      consent (45s) → safety/escalation (30s) → architecture + impact + honest limitation (30s). Filmed on real phones.

## Phase 6 — Sun 29 Nov: submit
- [ ] Final video uploaded to YouTube (public), links tested.
- [ ] Repo clean (no secrets, license visible in About, README final), APK attached to a GitHub release.
- [ ] Submit on Devpost with **Android** selected, by evening EAT. Monday is buffer only.

## Out of scope
HackSocial, mesh relay, Briar handoff, LSK / Missing Voices sync, Sheng native review.

## Decision log
(Claude Code: record decisions here with date and reason, only after the owner confirms.)
