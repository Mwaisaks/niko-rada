# README plan (for the #BuildHybridAI submission)

The current `README.md` still describes the earlier Gemma sprint build. It gets rewritten in Phase 5 to this outline.
Judges may judge from the README, Devpost text and video alone, so everything that matters must be readable there.

## Outline
1. **What it is** (2–3 lines): Niko Rada, a crisis-safety guide for Kenya; grounded, cited answers; works with no signal.
2. **Why** (value proposition) with the verified statistics, each linked to its source (table below).
3. **How Firebase AI Logic hybrid inference is used**
   - Architecture diagram: Flutter UI → Dart `AnswerFlow` (gate → Retrieve → Guide) → `InferenceService` →
     MethodChannel → Kotlin `HybridInferencePlugin` → Firebase AI Logic (`PREFER_ON_DEVICE` / `ONLY_ON_DEVICE` /
     `ONLY_IN_CLOUD`) → Gemini Nano on-device or Gemini in the cloud.
   - Call sites, as links: `android/app/src/main/kotlin/com/nikorada/niko_rada/HybridInferencePlugin.kt`
     (the only place a model is called), `lib/inference/hybrid_inference_service.dart` (consent → mode),
     `lib/agent/answer_flow.dart`.
   - Routing table: on-device by default; cloud only with consent; offline → on-device only; neither → limited mode.
4. **Safety design**: out-of-corpus gate before any model; citations required; phone numbers only from verified cards;
   output validation; cloud consent off by default and revocable.
5. **Screenshots**: route badge (on-device / cloud + fallback reason), consent sheet, limited mode.
6. **Install the APK** (GitHub release link) and **build from source** (setup steps below).
7. **Built during the window**: summary of the diff against `c745a39`, honest.
8. **Limitations**: on-device validated for English only; a budget phone without Nano during a total shutdown gets no
   model (limited mode instead); state whether on-device was filmed on a supported phone.
9. **Future work**: iOS (Apple Foundation Models through Firebase AI Logic; out of scope for this build), Play Integrity
   instead of the App Check debug provider, native Sheng review, incident sync to legal-aid partners.
10. **License**: Apache-2.0.

## Sources table (statistics verified by the owner, 26 Nov 2026)
Fill in each link before the README is published. Do not add a statistic without a source link.

| Statistic | Used in | Source (link) |
|---|---|---|
| ~40% connectivity drop, June 2024 | Why | TODO: link |
| 450% rise in enforced disappearances, 2023→2024 | Why | TODO: link |
| Electoral Vulnerability Index ~84% | Why | TODO: link |
| 1,133 deaths in the 2007–08 post-election violence | Why | TODO: link |
| Corpus card sources (ICRC, EFF, KRCS, KHRC, LSK, IMLU, …) | Safety design | `assets/corpus/SOURCES.md` |

## Setup for judges (build from source)
The repo contains **no Firebase config**. `android/app/google-services.json` is gitignored; judges create their own
Firebase project. Steps to put in the README:

1. Install Flutter (stable) and the Android SDK (platform 36). A physical Android phone; for on-device inference, one
   from the ML Kit GenAI supported-device list (https://developers.google.com/ml-kit/genai). Other phones use the cloud
   route.
2. Create a Firebase project → **AI Logic** → get started with the **Gemini Developer API**.
3. Add an Android app with package name `com.nikorada.niko_rada`. Download `google-services.json` into `android/app/`.
   `android/app/google-services.json.example` shows the expected shape; never commit the real file.
4. **App Check** (required by Firebase AI Logic): register the app with App Check, then open
   App Check → Apps → ⋮ → **Manage debug tokens** and create a debug token.
5. Put the token in `android/local.properties` (gitignored) as `nikoRada.appCheckDebugToken=<your token>`, or export
   `NIKO_RADA_APP_CHECK_DEBUG_TOKEN`. Without it, run the app once and copy the token the SDK prints to logcat
   (`DebugAppCheckProvider`), then register that one in the console.
6. `flutter pub get && flutter build apk --debug --target-platform android-arm64`, install, open the app.
7. Without step 2–5 the app still runs: it reports "AI not set up" and works in limited mode (verified cards and
   contacts).

## Rules this README must respect
- No production API keys, live secrets, tokens or PII in the README, the Devpost form or the testing instructions.
- The APK we publish keeps working until at least 16 Dec 2026 (judging period 10–16 Dec).
