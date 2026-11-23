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

## AUDIT — current state of the repo
_To be filled in Phase 0 (see below once written)._

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
