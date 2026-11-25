# Limited mode — proposal (awaiting owner decision)

Status: proposal, 25 Nov 2026. Nothing below is implemented yet except the typed `NO_ROUTE` error it relies on
(`lib/spike/hybrid_inference_channel.dart`, branch `spike/hybrid-inference`).

## Why
On the Galaxy A16 spike run, every request made offline failed in 50–95 ms with a generic `UnknownException`: no
network, and no on-device model. That is the honest limitation in the pitch ("a low-end phone without Nano during a
total shutdown gets neither path"). Limited mode is what the app does then: still useful, never a dead end.

## When it turns on
- `NO_ROUTE`: offline and the on-device model is not `AVAILABLE`.
- Online, no on-device model, and the user has **not** consented to cloud use of crisis content (no allowed route).
- `OFFLINE` for a request that only the cloud could serve (e.g. free-form Kiswahili/Sheng generation).

Detection, two layers:
1. **Pre-flight (primary):** before a model call, if the device is offline and the cached on-device status is not
   `AVAILABLE`, skip the call and go straight to limited mode. No failed call, no spinner.
2. **Backstop:** if a call still fails with `NO_ROUTE` (or the consent rule above blocks it), switch to limited mode.
`download()` results are never used to decide this (on the A16 it reported "completed" while status stayed `UNAVAILABLE`).

## What it shows (retrieval only, no generation, no network)
The out-of-corpus gate still runs first. Off-topic input gets the usual refusal plus contacts, as today.

For in-corpus input:
1. **Banner** (EN/SW): "No connection, and this phone can't run the on-device AI. Showing verified guidance from the
   library." / "Hakuna mtandao, na simu hii haiwezi kuendesha AI ya ndani. Tunaonyesha mwongozo uliothibitishwa kutoka
   maktaba."
2. **The top retrieved cards, verbatim** (k = 2, same retrieval as Guide), in the UI language: title, the card's
   numbered steps, and the citation (`source`, `source_url`). Sheng users get the Kiswahili card text. This text is
   human-written and verified, so it is safer than generated text and needs no model.
3. **Verified contacts:** always `contacts-001` (emergency numbers), plus any `contacts` card that retrieval returned
   (LSK legal aid, IMLU, Missing Voices). Numbers come only from the corpus, never from a model. Tap-to-call / SMS
   should work offline: voice and SMS often survive a data shutdown. (Needs a dialer intent; not in the app yet.)
4. **The usual disclaimer** (bilingual).

## What is skipped
- **Triage, Guide generation, Plan:** need a model. The cards replace Guide.
- **Branch (automatic report):** needs Triage. Instead offer the incident logger as a plain form (who / what / where /
  when / details), saved locally, no model. Optional; hide it if there is no time.

## Guarantees (test these)
- Zero `InferenceService` calls in limited mode (fake records no calls).
- Same cards as Guide would have used for that query (shared `RagService`).
- Contacts shown only from the corpus; no phone number appears anywhere else.
- Out-of-corpus input still refused in limited mode.
- Visible "limited mode" state in the UI; a retry action when the network returns.

## Demo value
This is the 20 seconds of the video that makes the honest limitation credible: airplane mode on a budget phone →
the app still shows cited, verified steps and who to call, and says plainly why it isn't using AI.

## Decisions for the owner
1. Cards shown: **2** (matches Guide's budget; recommended) or 3.
2. Always show `contacts-001` even when not retrieved: **yes** (recommended).
3. Pre-flight skip + `NO_ROUTE` backstop (recommended) vs. always try the call first.
4. Plain incident form in limited mode: include only if Phase 2/3 time allows (recommended: defer).
