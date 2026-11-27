# Niko Rada — #BuildHybridAI 2026 build

This repo is a revamp of Niko Rada (offline, on-device crisis-safety agent for Kenya; Flutter Android app) rebuilt so its AI
runs through **Firebase AI Logic hybrid inference**: Gemini Nano on-device when the phone supports it, cloud Gemini when not.
It is being submitted to the #BuildHybridAI 2026 hackathon on Devpost (target: Best Android App, $3,000, as the floor;
stretch: Grand / 1st / 2nd). Fallback platform if the Gemini Nano phone gate fails: Web (Chrome Desktop).
This is the existing `Mwaisaks/niko-rada` repo (already public); we keep pushing here. Baseline before the hackathon
window is commit `c745a39`; everything after it is window work.

**Deadline: Mon 30 Nov 2026, 2:00pm PST (= Tue 1 Dec, 1:00am EAT). Internal target: submitted by Sun 29 Nov evening EAT.**
Out of scope, do not work on: HackSocial, the mesh relay, Briar handoff, LSK / Missing Voices sync, Sheng native review.
PIN-gate + panic-wipe only if time remains after Phase 4. The app name is **Niko Rada** ("Kaa Rada" was a Kaggle-sprint
rename only; do not use it).

## Read these first (in order)
1. `docs/HACKATHON_BRIEF.md` — rules, prizes, judging criteria, submission checklist
2. `docs/NIKO_RADA_CONTEXT.md` — product, evidence, agent loop, corpus, current state
3. `docs/PLAN.md` — phased plan with acceptance criteria and checkboxes (update as you go)

## Hard rules
- **Never add Claude as a co-author or collaborator in git commits. No `Co-Authored-By` trailer, ever.**
- This repo is PUBLIC (already) with an open-source license (Apache-2.0, `LICENSE`). Never commit secrets: no `.env`, `google-services.json`
  if it holds anything beyond public client config you are comfortable publishing (ask first), service-account JSON, API keys,
  keystores, or App Check debug tokens. `android/app/google-services.json` is gitignored. Check `.gitignore` and git
  history before every push.
- No real user data, real survivor/victim details or real phone numbers in code, fixtures or the demo. Synthetic data only.
- Do not claim usage numbers, partnerships or outcomes that do not exist. The statistics in the docs are verified by the
  owner (26 Nov); each one is linked to its source in the README (Sources table in `docs/README_PLAN.md`).
- Stay inside this repo.

## Engineering rules
- **All model calls go through Firebase AI Logic hybrid inference.** `flutter_gemma` / Gemma are removed from the runtime path.
  Judges check that Firebase AI Logic is imported and actually called at runtime.
- The hybrid on-device API on Android is native (Kotlin: `firebase-ai` + `firebase-ai-ondevice`, experimental). Flutter UI and
  agent loop stay in Dart; one `InferenceService` (Dart) calls a Kotlin platform channel that wraps the Firebase hybrid SDK.
  Do not substitute a hand-rolled "try Nano, then call cloud" wrapper for the Firebase hybrid SDK without asking me first.
- Do not guess SDK/API names from memory. Read the current Firebase AI Logic hybrid docs and use the Firebase agent skills.
- On-device models are single-turn text (and single image), ~4000-token request limit, short outputs (docs recommend
  ≤256 tokens), foreground only, and only English and Korean are validated on-device. Keep each model step of the agent
  loop (Triage, Guide, Branch/report, Plan) a single-turn call with compact prompts. Retrieve is pure Dart, no model.
- Keep the existing safety design: grounded-only answers with citations, out-of-corpus input refused before it reaches any
  model, no fine-tuning, vetted contact numbers from the corpus/constants only (never from model output).
- The agent loop (Triage, Retrieve, Guide, Branch, Plan) exists today only in `notebook/notebook.ipynb`; the app has
  Retrieve + Guide and manual extraction. Phase 1 order: Triage → Retrieve/Guide on `InferenceService` → Branch (automatic
  report for active incidents, behind the same out-of-corpus gate) → Plan only if time remains after Phase 2.
- Every model call is single-turn. No reused chat sessions.
- Prompt budget for Nano: each request under ~4,000 tokens, replies under ~256 tokens; retrieve 2 cards by default.
- Language design: Nano does short English-friendly work (triage, card selection, report structuring); show the verified
  Kiswahili corpus text directly instead of generating it on-device; free-form Kiswahili/Sheng generation goes to the
  cloud, with consent.
- Cloud use of crisis content requires explicit, revocable user consent in the UI. Default is on-device; offline = on-device only.
  Minimise what is sent to the cloud (no names/locations unless the user chooses).
- The UI must show which route served each response (on-device vs cloud) and, on fallback, why.
- Firebase AI Logic requires App Check. Debug provider/token is fine for the submission; keep tokens out of git.
- Tests: routing logic (supported / unsupported / offline / cloud error / consent denied) and the safety gates.
- Small and finished beats broad. Design is a judging criterion.
- Honest limitation to keep in the pitch: a low-end phone without Nano during a total network shutdown gets neither path.

## Working agreements
- Platform decision (23 Nov): Android, Flutter + Kotlin bridge. Kill rule: no Nano phone showing the on-device model as
  available by Wed 25 Nov 12:00 EAT → switch to Web (Chrome Desktop). See the Decision log in `docs/PLAN.md`.
- Do not start Phase 1 (Dart port, removing `flutter_gemma`) until the owner confirms the spike ran on a real phone.
- Small, focused commits with plain descriptive messages. Tick checkboxes in `docs/PLAN.md` as you go.
- When a decision is mine (platform, cutting scope), give 2–3 options with a recommendation and wait.
- If docs contradict the repo, trust the repo and fix the docs.
- Scope freeze (Android app): end of Sat 28 Nov (moved from Fri 27 Nov by the owner). After that: bug fixes, docs, README,
  video, submission only.

## Definition of done
- Real Gemini Nano on-device inference on a supported physical Android phone AND real cloud fallback, both demonstrable.
- Public repo, license visible in the About section, README with setup steps and value proposition.
- Installable build (APK link/release) for judges; hosted URL not required for Android.
- Demo video ≤ 3 min, public on YouTube, English, filmed on the real phone: airplane mode → on-device; online + consent → cloud.
- Devpost text: how Firebase AI Logic is used, features, value proposition, and what was built during the window vs the old app.
