# Niko Rada: an offline safety companion for when the network goes dark

*Build with Gemma — GDG on Campus UoN · Track: Civic Engagement & Accessibility*

**Niko Rada** — "I'm aware," in Sheng/Kiswahili.

---

## The problem

When Kenyans protest, two things happen with grim reliability — both documented in the last 24 months, not speculation.

**The network goes dark.** On 25 June 2024, connectivity dropped roughly 40% nationwide across 20+ networks; telcos cited "undersea cables," but NetBlocks found no physical damage consistent with that. In June 2025 the Communications Authority ordered media to stop live-broadcasting protests. A May 2025 High Court order now bars shutdowns outright — but a court order doesn't restore your signal in the moment tear gas is fired around you.

**People are traced and taken.** Enforced disappearances rose 450% from 2023 to 2024. Victims — disproportionately young men aged 18–34 — were reportedly targeted in part for online activity, with surveillance leveraging mobile networks, electricity-token data, and CCTV.

The exact moment a person most needs guidance and coordination — caught in tear gas, unsure where's safe, trying to reach family, watching someone get grabbed — is precisely the moment their phone's internet is cut and any cloud-dependent app becomes dead weight.

The Kofi Annan Foundation's Electoral Vulnerability Index (July 2026) puts Kenya at roughly 84% probability of election-related violence in August 2027. This is not a hypothetical scenario — it's a scheduled event with a documented playbook, and no tool built to depend on a live network will be there for it.

## The insight

Kenya has already proven that information infrastructure changes the death toll. The 2007–08 post-election violence killed 1,133 people; 2013 was comparatively peaceful, in real part because of deliberately built peace-messaging and early-warning systems (Uwiano, local peace committees, SMS trees). Niko Rada extends that same idea to the individual — and fixes its one fatal assumption. Those systems assumed the network was up. Niko Rada is designed to assume it is down.

The enabling technical fact is simple: an open-weights model running *on the device* keeps working when the network is cut, and nothing it processes has anywhere to leave from. That property — not a chat feature bolted onto a cloud API — is the actual safety guarantee, and it's why an open model like Gemma is the right tool rather than a convenience.

## How we used Gemma 4 — and an honest status report

Niko Rada is architected as a Flutter (Dart) client with three Gemma-driven capabilities, each grounded in a curated, source-cited safety corpus rather than the model's general knowledge: **grounded guidance** (panic-button and free-text Q&A, answered only from vetted cards, always cited, always closing with a bilingual disclaimer), **structured extraction** (a messy spoken or typed account of a witnessed incident turned into a strict JSON report matching the Missing Voices/KHRC documentation schema), and **language-aware response** (English, Kiswahili, or Sheng on toggle).

The client-side engine is fully built against `flutter_gemma` + `flutter_gemma_litertlm` — six screens (panic grid, chat, incident logger, settings/language toggle, a resumable model-download flow with a Limited Mode so the app is never a dead end, and the shell/splash), a retrieval layer, and the three prompt templates above, all wired to the real `flutter_gemma` API (`getActiveModel()` → `createChat()` → `generateChatResponseAsync()`). `flutter analyze` passes with zero issues across the codebase.

**What we have not verified: live on-device generation.** We could not get a completed Gemma 4 E2B generation to run to completion in our own development environment before submission — the LiteRT-LM FFI path failed identically in a plain terminal on our Linux dev machine, so this is a real engine/environment issue on our box, not a sandbox artifact, and not something we're papering over. We are reporting this plainly rather than claiming a result we don't have.

To still prove the AI pipeline itself works end-to-end, we built `notebook/notebook.ipynb`, a Kaggle-runnable notebook that loads the **exact same corpus** (`assets/corpus/cards.jsonl`, 41 verified bilingual cards) and the **exact same prompt templates**, ported line-for-line from `lib/prompts/prompts.dart` and `lib/services/rag.dart` — not a parallel reimplementation. It demonstrates, with real model output: grounded, cited answers for all 5 priority panic-button scenarios; the same query answered in English, Kiswahili, and Sheng; the refusal path (an out-of-corpus question returns "no verified guidance" rather than an improvised answer, because retrieval short-circuits before the model is ever called); and incident extraction into the app's exact JSON schema.

**Model actually run on Kaggle:** `google/gemma-4-e2b-it`, 4-bit quantized on a single T4 GPU — the real Gemma 4 E2B, not a smaller fallback. All four demo sections ran clean, top-to-bottom, no errors. Sample results: the tear-gas panic button returned a 6-step grounded answer citing ICRC/EFF and closing with the disclaimer; the same query reproduced correctly in English, Kiswahili, and Sheng; an out-of-corpus query ("best chapati recipe") retrieved zero cards and returned the fixed refusal string without the model ever being called; and a messy spoken-style account of a street abduction parsed into valid JSON matching the app's `IncidentReport` schema, with no fields missing. Full outputs are saved in `notebook/notebook.ipynb`.

## Why on-device, open-weights Gemma matters

Even though we have not yet demonstrated it running on a phone, the architecture is built around one non-negotiable: **a cloud LLM dies the instant the network is cut — precisely the scenario this app exists for.** On-device inference is the only class of tool that survives that moment, and that's a property of the model class, not an implementation detail we could substitute away.

It's also the actual privacy guarantee, not a slogan: no data leaves the device, no server to subpoena, no telco in the inference path — a direct architectural answer to the documented mobile-network and metadata surveillance described above. Gemma 4 E2B's small footprint (~2.6 GB) targets the 6 GB+ RAM class of budget Android phones that most Kenyan students and workers actually own — the population that needs this most, not a flagship-only demo. And because it's open-weights, the model is inspectable — "trust in the technology" is a named risk driver in the EVI report, and an auditable model is a substantive answer to that, not a marketing line.

## Local languages

The three prompt templates carry explicit language instructions for English, Kiswahili, and Sheng — the Nairobi street mix of the two, which is how the target user actually speaks under stress. This is currently **prompt-level only**: we specify register and give Sheng vocabulary hints (*sema, fanya, gari, fiti, mbaya*) mixed with clear Kiswahili for safety-critical terms, verified working in the notebook's trilingual demo. It has **not** been reviewed by a native Sheng speaker for naturalness or for any safety-critical mistranslation, and we're not claiming otherwise — that review is a hard requirement before any real-world release, not a nice-to-have.

## Responsible AI & honest limitations

The corpus is grounded-only and cited: the model answers strictly from 41 vetted knowledge cards (ICRC, EFF Surveillance Self-Defense, Kenya Red Cross, the Constitution of Kenya 2010, KHRC, LSK, IMLU, Amnesty Kenya, KNCHR, Missing Voices) and refuses rather than improvises when nothing relevant is retrieved. Every contact number was checked against the organisation's own site or multiple independent reputable sources; two numbers from an earlier pass were found wrong and corrected, and one organisation (Missing Voices) has no phone hotline at all — we did not invent one. Guidance is de-escalation-biased throughout. The incident logger is local-only, easy to clear, and never auto-transmits.

Limitations, stated plainly: **on-device inference is unverified** — see above. **Device testing is pending real hardware** — our only test phone is 4 GB RAM, below Gemma 4 E2B's floor, so budget-device behaviour (including the Limited Mode fallback path) is unconfirmed. **Sheng is unreviewed**, as above. This tool is scoped to the protest/blackout/targeted-grab band; it does not and cannot protect against organised mass violence.

## Challenges & roadmap

The dominant challenge was the LiteRT-LM FFI engine failing to complete inference in our development environment, discovered late and not resolved before submission — this is the top item for the next session, alongside first real-device verification once 6 GB+ hardware is available. Also cut for time: native Sheng review, a QLoRA fine-tune (unneeded for the current prompting approach), any backend/report-transmission layer, mesh/Bluetooth transport (Briar is advised, not reimplemented), and iOS (LiteRT-LM's Swift API isn't public yet). All are explicit roadmap items, not silent gaps.
