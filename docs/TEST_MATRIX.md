# Test matrix — Phase 4 (started 27 Nov 2026)

Two halves:
- **A. Automated:** unit/widget tests with a fake inference service. Run with `flutter test`: **287 passing on 27 Nov**
  (commit after `9845a74`).
- **B. On a real phone:** the owner fills it in. Nothing in B has been run yet unless a cell says so.

Hardware available: Galaxy A16 (SM-A165F, no Nano), friends' S24 Ultra / S22 Ultra (no Nano, UNAVAILABLE), optional
streamed Pixel 9 (`docs/PIXEL9_STREAMING_TEST.md`). **No Nano phone in hand:** every "Nano present" row in B is blocked
unless the Pixel 9 session works.

## A. Automated coverage (fake inference; real corpus, gate, prompts and parsers)

| Network | On-device model | Cloud consent | Language | Expected | Covered by |
|---|---|---|---|---|---|
| offline | absent | any | EN | limited NO_ROUTE, 2 cards + contacts, 0 model calls | `answer_flow_test` "A16 case: offline + no on-device model" |
| online | absent | denied | EN | limited NO_CONSENT + "Allow cloud AI" button, 0 calls | `answer_flow_test` "A16 online, no consent"; `response_screen_test` |
| online | absent | given | EN | cloud answer, cloud badge + fallback reason | `hybrid_inference_service_test` "consent on…A16 online case"; `response_screen_test` "cloud answer" |
| offline | present | any | EN | on-device answer, "Answered on this phone" | `answer_flow_test` "Nano phone offline (English)" |
| online | present | denied | EN | request sent `ONLY_ON_DEVICE` | `hybrid_inference_service_test` "consent off" |
| any | present | denied | SW / Sheng | verified Kiswahili cards, no generation | `answer_flow_test` "Kiswahili without consent" |
| offline | present | given | SW / Sheng | limited OFFLINE | `answer_flow_test` "Kiswahili offline on a Nano phone" |
| online | any | given | SW / Sheng | cloud-only request (`ONLY_IN_CLOUD`) | `guide_test` "Kiswahili generation is requested cloud-only" |
| online | any | given | any | **cloud error** → limited, not an error screen | `answer_flow_test` "cloud error" |
| any | any | revoked mid-session | any | next request has no cloud mode | `hybrid_inference_service_test` "revoking consent" |
| — | — | — | — | Firebase not configured → limited NOT_CONFIGURED | `answer_flow_test`, `hybrid_inference_channel_test` |
| — | — | — | — | off-topic input refused before any model/availability call | `answer_flow_test`, `prompt_injection_test` group 1 |
| — | — | — | — | prompt injection / hostile output never shown | `prompt_injection_test` (37 tests) |
| — | — | — | — | contacts: numbers verbatim from the card, tap-to-call | `contact_lines_test` (13 tests) |

## B. Real phone (owner)

Build: the release judge APK (`NIKO_RADA_JUDGE_BUILD=true flutter build apk --release --target-platform android-arm64`),
installed after uninstalling the old app (clean state). Use the same synthetic questions in every row:
- EN: "There is tear gas. What do I do right now?"
- SW: "Kuna machozi ya kutoa. Nifanye nini?"
- Sheng: set the language to Sheng in Settings, then tap the tear gas panic button
- Off-topic: "What is the best chapati recipe?"

For each row record: route badge text, banner text, time to answer, whether contacts appear, and any crash.

| # | Phone | Network | Consent | Lang | Expected | Result |
|---|---|---|---|---|---|---|
| 1 | A16 | airplane | off | EN | limited "No connection, and this phone can't run the on-device AI", 2 cards, 999/112 bar | |
| 2 | A16 | airplane | on | EN | same as 1 (no route) | |
| 3 | A16 | online | off | EN | limited NO_CONSENT + "Allow cloud AI" | |
| 4 | A16 | online | on | EN | cloud answer, "Answered by cloud AI" + fallback reason, cited steps | |
| 5 | A16 | online | on | SW | cloud answer in Kiswahili, cited | |
| 6 | A16 | online | on | Sheng | cloud answer, cited; note language quality | |
| 7 | A16 | online | off | SW | verified Kiswahili cards, no generation | |
| 8 | A16 | online | on → revoke in Settings | EN | after revoke: limited NO_CONSENT | |
| 9 | A16 | online | on | off-topic | refusal + contacts, no model call | |
| 10 | A16 | any | any | — | tap 999 → dialer opens with 999 (do **not** press call) | |
| 11 | A16 | online | on | EN | Log tab: active incident → report drafted, saved | |
| 12 | A16 | online, then airplane mid-request | on | EN | limited, no crash | |
| 13 | Nano phone | airplane | off | EN | **on-device answer, "Answered on this phone"** | blocked: no Nano phone |
| 14 | Nano phone | airplane | off | SW / Sheng | verified Kiswahili cards; note on-device quality if any generation | blocked |
| 15 | Nano phone | online | on | EN | on-device preferred (badge "on this phone") | blocked |

Cloud error (row type "cloud error") can't be forced reliably on the phone without a quota/App Check failure; it is
covered by the automated tests only. Say so if asked.

## Known gaps (honest list)
- On-device inference has not run on any phone yet (rows 13–15).
- Out-of-corpus gate residual: off-topic text sharing two corpus words passes the gate. The output checks contain it
  (`prompt_injection_test` group 1b).
- On-device Kiswahili/Sheng quality: untested (no Nano phone).
