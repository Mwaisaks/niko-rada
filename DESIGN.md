# Niko Rada — DESIGN.md

> **The offline safety companion for when the network goes dark.**
> An Android app where Gemma 4 runs entirely on the phone. Install it once on Wi-Fi; then, during a protest or blackout, it gives grounded, verified safety guidance in airplane mode — in English, Kiswahili, or Sheng — with nothing ever leaving the device.

- **Hackathon:** Build with Gemma: GDG on Campus UoN
- **Track:** Civic Engagement & Accessibility
- **Prize target:** Overall 1st ($650) + Best Civic/Accessibility Niche ($250)
- **Model:** Gemma 4 E2B (`.litertlm`) via `flutter_gemma` (LiteRT-LM / MediaPipe), on-device, Android
- **Delivery:** installable APK + clonable notebook (submission-safe fallback)
- **This document is the scope + Codex build spec. `PLAN.md` is the phased build.**

> Name: **Niko Rada** ("stay alert" — common Kiswahili-Sheng phrase, used here descriptively). Earlier drafts of this
> document used the working name "Salama" (safety/peace), then "Niko Rada"; every instance below refers to the
> same product now shipping as Niko Rada.
>
> **Architecture pattern credit:** the on-device-Flutter-Gemma approach (install-once-then-offline, per-agent tool scoping, cited + confidence-gated outputs, multilingual code-switch) is modelled on Eugene Mutembei's *The Campus Collective* (GDG Embu). Niko Rada is a distinct product — different domain (protest/blackout safety, not campus survival), different corpus, different scenario, and a deliberately simpler agent design.

> **Status at submission:** this document is the design spec this build targets. The app (`lib/`) is fully built against it and compiles clean, but **on-device Gemma generation is not yet verified on hardware** — see [`WRITEUP.md`](WRITEUP.md) and [`README.md`](README.md) for the honest current status. The pipeline described here (retrieval → grounded generation → extraction) is proven working in [`notebook/notebook.ipynb`](notebook/notebook.ipynb) with the real corpus and prompts.

---

## 1. The problem

When Kenyans protest, two things happen with grim reliability — both documented in the last 24 months, not speculation:

1. **The network goes dark.** On 25 June 2024, connectivity dropped ~40% nationwide across 20+ networks; telcos blamed "undersea cables" while NetBlocks found no physical damage. In June 2025 the Communications Authority ordered media to stop live-broadcasting protests. A May 2025 High Court order now bars shutdowns — but a court order doesn't restore your signal in the moment.
2. **People are traced and taken.** Enforced disappearances rose 450% from 2023 to 2024. Victims — mostly young men 18–34 — were targeted for online posts. Surveillance reportedly leveraged mobile networks, electricity tokens, and CCTV.

The exact moment a person most needs guidance and coordination — caught in tear gas, unsure where's safe, trying to reach family, watching someone get grabbed — is the moment their phone's internet is cut and any cloud app is dead weight.

**The Kofi Annan Foundation's Electoral Vulnerability Index (July 2026) puts Kenya at ~84% probability of election-related violence in August 2027.** A scheduled event with a documented playbook.

## 2. The insight

Kenya already proved that *information infrastructure changes the death toll*. The 2007–08 post-election violence killed 1,133 people; 2013 was comparatively peaceful, largely because of deliberately built peace-messaging and early-warning systems (Uwiano, local peace committees, SMS trees). Niko Rada extends that to the individual and fixes its fatal flaw: **those systems assumed the network was up. Niko Rada assumes it is down.**

The enabling technical fact: **an open-weights model on the device keeps working when the network is cut, and nothing it processes ever leaves the phone.** That single property is both the feature and the safety guarantee — and it's why Gemma is the right tool, not a bolted-on chatbot. On a budget Tecno/Infinix with 6–8 GB RAM (the phone most Kenyan students and workers actually own), on-device is the *only* shape that works.

## 3. Solution overview

Niko Rada is an offline-first **Android app**. After a one-time model download on Wi-Fi, a Gemma 4 E2B model runs on-device via `flutter_gemma`. Everything — chat, retrieval, structured extraction, language switching — works in airplane mode. Answers are grounded in a **curated, verified corpus** of protest-safety, first-aid, blackout-communication, and human-rights-documentation guidance (EFF, Access Now, ICRC, Amnesty Kenya, KHRC, Missing Voices). The model never invents survival advice; it retrieves, grounds, and cites.

Three things the model does, all locally:
- **Grounded guidance** — answers "what do I do right now" from the vetted corpus, in the user's language.
- **Structured extraction** — turns a panicked free-text/spoken account of a witnessed incident into a clean, standardised report, saved locally to send when networks return.
- **Language-aware response** — English by default, Kiswahili or Sheng on toggle, code-switching as real Nairobi speech does.

## 4. Primary user & the live scenario (this is the demo)

**Primary user:** an ordinary Nairobian — student, worker, bystander — caught in or near a protest with dead/degraded connectivity. Not a trained activist. Scared, rushed, thumbs shaking, on a budget Android.

> Amina is near Kimathi Street. Police fire tear gas. Her phone shows "No Internet." She opens Niko Rada — installed weeks ago. She taps the big red **"Machozi ya kutoa / Tear gas"** button. In under a few seconds, offline, Gemma gives three calm, ordered steps sourced from ICRC/EFF guidance, in Kiswahili because that's her setting. She taps **"Fikia watu wangu / Reach my people"** and gets blackout-comms options and her pre-set family rendezvous. Leaving, she sees a man forced into an unmarked car. She taps **"Nimeshuhudia utekaji / I witnessed an abduction,"** speaks what she saw (transcribed on-device), and Niko Rada structures it into a report — stored locally — ready to send to LSK / Missing Voices the moment signal returns.

Every step happens with **Wi-Fi and mobile data OFF.** That is the demo's most important beat.

## 5. Feature scope

### In scope (the 2-day build)

| # | Feature | What it does | Gemma's role |
|---|---------|--------------|--------------|
| F0 | **First-run model install** | One-time `.litertlm` download on Wi-Fi with resumable/backoff download, size check, and a Limited Mode so the app is never a dead-end without the model | (enables everything) |
| F1 | **Offline grounded chat** | Free-text Q&A answered only from the vetted corpus, cited, with a safety disclaimer, in the chosen language | Grounded generation |
| F2 | **Panic quick-actions** | Big, high-contrast, bilingual buttons ("Tear gas", "Being followed", "Someone was grabbed", "Network down — reach my people", "Prepare my phone"). Each pre-seeds a query and returns a concise grounded answer | Grounded generation |
| F3 | **Offline incident logger** | Capture what/where/when/who (text or voice); Gemma structures it into the Missing Voices/KHRC schema; saved locally to a "pending send" queue | Structured extraction (+ on-device audio) |
| F4 | **Language toggle** | English / Kiswahili / Sheng in Settings; affects UI strings and model output language | Multilingual generation |

### Explicitly out of scope (writeup as roadmap — do NOT build now)

- **Fine-tuning.** Ship stock ungated Gemma 4 E2B. A QLoRA fine-tune (TCC-style) needs big GPU time we don't have and isn't needed for a strong demo. Multilingual is handled by prompting. → roadmap.
- **Backend of any kind.** No Supabase, no manifest, no server. Bundle content packs + corpus in the app; download the model from a public HF/GitHub-release URL. → roadmap: remote content-pack/model manifest for updates.
- **Real network send/sync of reports** (logger prepares; transmission is roadmap).
- **iOS** (LiteRT-LM Swift API not yet public — Android-only, like TCC).
- **Mesh/Bluetooth transport** (Niko Rada *advises on* Briar/mesh; doesn't reimplement it).
- **Multi-agent router** (TCC has 4 agents; Niko Rada stays focused — see §7).

## 6. Why Gemma 4 / why on-device (the 30% argument — make it loudly)

1. **Availability under blackout.** A cloud LLM dies the instant the network is cut — precisely the scenario. On-device Gemma is the only class of model that works here.
2. **Safety by architecture.** No data leaves the device; no server to subpoena, no telco in the path. Directly counters the documented mobile-network/metadata surveillance. On-device open-weights *is* the privacy guarantee.
3. **Runs on the phone people own.** Gemma 4 E2B (~2.6 GB) fits budget Androids with a 6 GB RAM floor — where the tool is needed most. Zero recurring data cost after first download.
4. **Auditable & trustworthy.** "Trust in the technology" is a named election-risk driver in the EVI report. An inspectable open model is a substantive answer, not a slogan.
5. **Genuine, multiple uses** — grounded generation, structured extraction, multilingual/audio — so Gemma is unambiguously *core*.

## 7. Agent design — deliberately simpler than TCC

TCC runs four specialist agents behind a router. Niko Rada does **not** need that. Under stress, focus is the feature. Niko Rada is **one grounded safety persona** plus **one extraction function** (the logger). Panic buttons are pre-seeded prompts into the same persona, not separate agents.

Why: fewer moving parts = fewer edge-model failure modes, faster to build in 2 days, and calmer UX. If time allows, a light deterministic keyword router can map input to a corpus domain to sharpen retrieval — but that's an optimisation, not the architecture.

## 8. System architecture

```
Phone (everything lives here; offline after first run)
├─ Flutter app (Dart) — safety UX: panic grid, chat, logger, settings/language
├─ Gemma 4 E2B via flutter_gemma (LiteRT-LM/MediaPipe) — CPU w/ GPU when available
├─ Grounded-answer pipeline: retrieve vetted cards → prompt Gemma → cited answer + disclaimer
├─ Incident extraction: free text/voice → strict-JSON report (Missing Voices/KHRC schema)
├─ On-device audio input (Gemma 4 E2B) for voice panic + voice reports
├─ Local store (Drift/SQLite) — saved reports "pending send", language pref, chats
└─ Bundled assets — vetted safety corpus (JSONL) · verified contacts · rendezvous helper

No backend. Model downloaded once from a public URL. No network calls at inference time.
```

**Offline guarantee (must be demonstrable):** zero outbound calls at inference. Model + corpus + logic all local. The only thing that ever touches the network is the *optional, user-initiated* future send of a saved report, only when signal returns.

**flutter_gemma call shape (real, current API — for Codex):**
```dart
await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);
await FlutterGemma.installModel(modelType: ModelType.gemma4)
    .fromNetwork('https://<host>/gemma-4-E2B-it.litertlm')
    .install();                       // F0: one-time, resumable
final model = await FlutterGemma.getActiveModel(maxTokens: 2048);
final chat  = await model.createChat();
await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
final answer = await chat.generateChatResponse();   // stream for UX
```

**Known pitfall to pre-empt:** the shared `libLiteRtLm` native library can fail to bundle after certain rebuilds, surfacing as an opaque `dlopen "no such file"` on first inference. Fix: `flutter clean` + clear the flutter_gemma native cache + `flutter pub get`. Bake this into the README and CI notes.

## 9. Knowledge corpus (the heart of the product)

Hand-curated "knowledge cards," each a small chunk of verified guidance with an attributed source. Target **40–80 cards**. Bundled in the app (`assets/corpus/cards.jsonl`).

**Card schema:**
```json
{
  "id": "teargas-001",
  "domain": "first_aid",
  "title_en": "Immediate response to tear gas",
  "title_sw": "Hatua za haraka dhidi ya machozi ya kutoa",
  "content_en": "Move upwind and uphill to open air. Do not rub eyes...",
  "content_sw": "Songa kuelekea upepo unakotoka na mahali pa juu...",
  "source": "ICRC / EFF SSD",
  "source_url": "https://ssd.eff.org/module/attending-protest",
  "region": "general",
  "verified": true
}
```

**Domains:** `first_aid` · `evasion_safety` · `blackout_comms` · `documentation` · `contacts` · `rights`.

**Curation rules (non-negotiable; state in writeup):**
1. Every card cites a real authoritative source (EFF SSD, Access Now, ICRC, Amnesty Kenya, KHRC, Missing Voices, PBI, LSK). No invented advice.
2. **Contacts must be VERIFIED before submission.** Never ship a guessed hotline number — a wrong emergency number is worse than none. Mark unverified `"verified": false` and exclude from retrieval until confirmed (LSK, Amnesty Kenya, IMLU, Kenya Red Cross, Missing Voices, KNCHR from official sites).
3. Guidance is always **de-escalation- and protection-oriented** — move, avoid, document, seek help. Never anything encouraging confrontation, escalation, or harm.
4. Every answer carries a short disclaimer: *guidance, not a guarantee; not legal/medical advice.*

## 10. Multilingual: English · Kiswahili · Sheng

- **Approach:** prompt-level, not fine-tuned. Gemma 4 supports 140+ languages; Kiswahili is well-covered. Sheng is the weak spot → handled with few-shot exemplars in the prompt and a small Sheng glossary card set, **reviewed by native speakers** before submission.
- **UI:** language toggle in Settings (En default). UI strings localised for the panic buttons + core screens (keep the string set small).
- **Corpus:** bilingual card fields (`_en`/`_sw`); Sheng handled at generation time via style exemplars rather than a third stored copy (keeps corpus lean).
- **Honesty (writeup):** Sheng is prompt/exemplar-level, native-speaker-reviewed — not native fluency. State it plainly, as TCC did.

## 11. How Gemma 4 is used (prompt sketches for Codex)

**(a) Grounded generation:**
```
You are Niko Rada, an offline safety companion. Answer ONLY using the SOURCES below.
Reply in {{language}} (English | Kiswahili | Sheng). Be calm, concrete, brief:
numbered steps, most important first. If the sources don't cover it, say so —
never invent safety advice. End with a one-line disclaimer. Cite sources by [title].
SOURCES:
{{retrieved_cards}}
USER SITUATION: {{query}}
```

**(b) Structured extraction (logger):**
```
Extract an incident report as JSON: who, what, where, when, details, witnesses,
source_reliability. Output ONLY valid JSON. "unknown" for missing fields. Do not invent.
ACCOUNT: {{free_text_or_transcript}}
```

**(c) Optional keyword router:** map input → `first_aid|evasion_safety|blackout_comms|documentation|rights|general` to filter retrieval. Deterministic keyword fallback if the model call is malformed (edge-model safety).

## 12. Responsible AI & safety design (first-class; echoes DIRA's RC framing)

- Grounded-only, cited, refuses to improvise. No hallucinated survival advice.
- Verified contacts only (corpus rule #2).
- De-escalation bias — guidance moves people *away* from danger, never toward confrontation.
- Local-only by design — no accounts, no telemetry, no server. Privacy is architectural.
- **The tool must not become the threat.** A phone seized at a checkpoint shouldn't incriminate its owner. Sprint minimum: the logger is local, clearly labelled, easy to clear. Roadmap: PIN-gated logger, panic-wipe, innocuous appearance.
- Honest about limits — Niko Rada helps in the protest/blackout/targeted-grab band; it does not claim to protect against organised mass violence (evidence says nothing at the individual level reliably does). Don't oversell.
- Confidence banner + "verify with a lawyer/office" on sensitive outputs.

## 13. Tech stack

| Layer | Choice | Why |
|-------|--------|-----|
| App | **Flutter (Dart)** — ship Android APK; **develop on the desktop build** | Same Dart API on desktop + Android, so build/test real inference on a laptop (no phone needed); ship APK; iOS blocked upstream |
| Model | **Gemma 4 E2B `.litertlm`** via **`flutter_gemma`** (+ `flutter_gemma_litertlm`) | Runs offline on 6 GB budget phones; clean install/chat API; ungated litert-community weights (no HF login on first run) |
| Inference | LiteRT-LM (CPU, GPU when available) | Works on budget MediaTek CPU fallback; stream tokens for UX |
| Retrieval | **Keyword/similarity inject** of vetted cards into the prompt (primary) | Corpus is tiny (<80 cards); avoids extra native surface under deadline. flutter_gemma's built-in embeddings+vector store = upgrade path |
| Audio | flutter_gemma on-device audio (Gemma 4 E2B) | Voice panic + voice reports, no separate ASR |
| Store | **Drift / SQLite** | Local reports, language pref, chats |
| Demo | Installable **APK** + **clonable Kaggle notebook** | Notebook is the submission-safe fallback if the device build slips |

> **Confirm the exact Gemma 4 E2B `.litertlm` URL/tag** (ungated litert-community) in Phase 0.

## 14. Demo script (rehearse exactly)

1. **Stage (15s):** "84% chance of violence in 2027. When Kenyans protest, the internet gets cut and people get traced. Cloud apps die exactly when you need them."
2. **Install / open the APK on a real budget Android.**
3. **Kill connectivity — visibly.** Airplane mode ON, on camera. "Everything from here runs on this phone."
4. **F2 — tap "Tear gas."** Grounded 3-step answer in ~seconds, offline, in Kiswahili. Point out citation + disclaimer.
5. **F4 — flip to Sheng**, re-ask, show it code-switch.
6. **F2 — "Reach my people."** Blackout-comms + rendezvous.
7. **F3 — "I witnessed an abduction."** Speak a messy account; show on-device transcription → structured report → saved to local pending-send queue.
8. **Close:** "No signal. No server. No data left this phone. Not a limitation we worked around — the whole point, and only an open model like Gemma 4 makes it possible."

## 15. Rubric mapping

| Criterion | Weight | How Niko Rada scores |
|-----------|--------|-------------------|
| Gemma Integration | 30% | On-device Gemma is *the* enabling tech; grounded gen + extraction + multilingual/audio; offline impossible without an open model |
| Innovation & Impact | 30% | Timely, documented, resonant; extends Kenya's proven peace-info idea into the blackout; real user, real scenario, local languages |
| Functionality | 20% | Real APK working fully offline (airplane mode) in a live demo; grounded answers + extraction demonstrable |
| Presentation & Writeup | 20% | Clear arc (problem → insight → build → demo); Responsible-AI section; honest limitations; <1500 words |

## 16. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| **Flutter/on-device is new territory in 2 days** | Start from an existing flutter_gemma example app (not scratch); Phase 0 device spike must pass early; Codex does the bulk of Dart |
| **No good phone during the build** | Resolved: develop + run real inference on the laptop desktop build; borrow a 6 GB+ Android only for the final demo. A16 4 GB is a bonus spike, not the plan. Emulators = UI only, not inference |
| `libLiteRtLm` dlopen / native-asset bundling errors | Documented fix (flutter clean + clear native cache); pin plugin versions |
| Gemma E2B slow on budget CPU | Stream tokens, cap answer length, rich result cards so short answers feel complete |
| Hallucinated safety advice | Strict grounded-only prompt + refuse-if-uncovered; tiny vetted corpus |
| Wrong emergency number shipped | Verified-contacts rule; unverified excluded from retrieval |
| Scope creep (fine-tune, backend, mesh, iOS, 4 agents) | Hard out-of-scope list; all roadmap |
| Live demo fails | Pre-recorded airplane-mode backup video + clonable notebook |

## 17. Post-hackathon roadmap (writeup one-liners)

- QLoRA fine-tune for tighter Kiswahili/Sheng register + exact JSON/tool format (Unsloth), swapped per-device via a remote manifest
- flutter_gemma built-in RAG (on-device embeddings + vector store) over a larger, versioned, community-vetted corpus
- Real report sync to LSK / Missing Voices when signal returns
- Handoff/integration with Briar for actual offline messaging
- Panic-wipe + plausible-deniability hardening; PIN-gated logger
- iOS once LiteRT-LM Swift API ships
