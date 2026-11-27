# Plan: minimal plain-JavaScript web companion (prepared 27 Nov 2026 — NOT started)

**Status: plan only. Nothing is built until the owner says "go".** If approved, all work goes on branch
`feat/web-companion` and lives under `web/` (plus one sync script and one parity fixture). It does **not** touch
`lib/`, `android/` or the Android scope freeze. It is not a Flutter web port.

## Why, and the go/no-go test
- No Nano phone is confirmed (A16, S24 Ultra, S22 Ultra all `UNAVAILABLE`). Chrome on the owner's 16 GB laptop
  reported `'downloadable'` on 26 Nov.
- If `docs/CHROME_PROMPT_API_TEST.md` reaches `'available'` and a real `prompt()` reply, the web companion is the only
  way to **film real on-device Gemini Nano through Firebase AI Logic** this week.
- **Build it only if** the Chrome test passes (or the owner decides otherwise at 12:00). If Chrome stays
  `'unavailable'`, the companion would be cloud-only and adds nothing to the Android app. Don't build it then.
- Whether Devpost lets one submission name two platforms, and which one to select, is the owner's call. Default: keep
  **Android** as the platform and present web as "the same agent, on-device in desktop Chrome".

## What it does (Android parity, cut to the core)
1. **Ask box + 4 panic buttons** (tear gas, abduction/arrest, injury, network blackout). They send the same strings as
   `lib/ui/panic_grid.dart`.
2. **Out-of-corpus gate first, before any model call.** It is a port of `RagService` (`lib/services/rag.dart`): whole-word
   and stem matching, ≥ 2 matching words or ≥ 50% coverage, same synonym list. Refusal never reaches a model.
3. **Triage** (single-turn, one line `type|severity|active`, strict parser), ported from `lib/agent/triage.dart`.
4. **Guide** (single-turn, 2 cards, numbered steps with `[card-id]` citations, validator: unknown citations rejected,
   phone numbers must come from the cards), ported from `lib/agent/guide.dart`. Verified Kiswahili card text is shown
   directly; the model works in English only.
5. **Route badge on every answer**: "On device" / "Cloud", from `result.response.inferenceSource` (`ON_DEVICE` /
   `IN_CLOUD`, SDK ≥ 12.5.0), plus the fallback reason when the cloud served it.
6. **Cloud consent**: off by default, a sheet explaining what is sent, revocable from a settings toggle. Without
   consent, the model runs in `ONLY_ON_DEVICE`; with consent, in `PREFER_ON_DEVICE`. This mirrors `resolveMode` in
   `lib/inference/hybrid_inference_service.dart`.
7. **Limited mode**: offline with no on-device model, or no consent with no on-device model. Show the top 2 gated cards
   plus the emergency contacts card (`contacts-001`), with no model, as in `docs/LIMITED_MODE.md`.
8. **"Get the on-device model" button**: calls `model.initializeDeviceModel(progressCb)` on a click (user gesture), shows
   progress. Requires JS SDK ≥ 12.14.0.

Not in scope: the Log tab / Branch report, voice, PWA offline install, Sheng UI, accounts, analytics.

## Facts this plan relies on (read 27 Nov)
**Confirmed:**
- Imports: `initializeApp` from `firebase/app`; `getAI, getGenerativeModel, GoogleAIBackend, InferenceMode` from
  `firebase/ai`; `initializeAppCheck` from `firebase/app-check`.
- Setup: `getGenerativeModel(ai, { mode, inCloudParams: { model, generationConfig }, onDeviceParams: { createOptions:
  { expectedInputs, expectedOutputs } } })`.
- Modes: `PREFER_ON_DEVICE`, `ONLY_ON_DEVICE`, `PREFER_IN_CLOUD`, `ONLY_IN_CLOUD`.
- Route: `result.response.inferenceSource` is `ON_DEVICE` or `IN_CLOUD`.
- Device model: `initializeDeviceModel()` exists from **12.14.0** and must be called on or after a user interaction.
  `ONLY_ON_DEVICE` waits for the download; the `PREFER_*` modes fall back to the cloud meanwhile.
- `topK` and `temperature` were removed from the on-device create options in 13.0.0. Don't set them.
- Latest JS SDK on 16 Nov: **13.4.0**. Pin it.
- On-device limits: single-turn text, about 9,216 tokens, JSON/enum output supported, no tools.
- Chrome on-device languages: en, ja, es, de, fr. Chrome Desktop 139+ per Firebase; 148 per Chrome's status table.
- Firebase names the flag `chrome://flags/#prompt-api-for-gemini-nano-multimodal-input` → Enabled.
- **App Check is enforced** for Firebase AI Logic in all projects since 2 Nov 2026. Requests without a valid token
  return 403.

**Unconfirmed:**
- Loading the SDK from the gstatic CDN as ES modules without a bundler. The docs read today show only
  `npm install firebase`. Task 1 checks this first.
- Whether `maxOutputTokens` in `generationConfig` applies on-device.
- Whether reCAPTCHA Enterprise needs billing enabled on the project.

## Files (all new, on `feat/web-companion`)
```
web/
  index.html                  # single page: status strip, panic buttons, ask box, answer card, consent sheet, settings
  styles.css                  # same palette/typography tokens as lib/theme/app_theme.dart; light/dark; mobile-first
  app.js                      # UI wiring and state (consent, online/offline, model status), no model calls
  inference.js                # the ONLY model caller: Firebase init, App Check, getGenerativeModel, generate(),
                              #   availability(), initializeDeviceModel(); returns {text, route, fallbackReason}
  routing.js                  # resolveMode(preference, cloudConsent) → mode (port of hybrid_inference_service.dart:17)
                              #   + limited-mode decision from online state and LanguageModel.availability()
  rag.js                      # corpus load + out-of-corpus gate + top-k retrieval (port of lib/services/rag.dart)
  agent.js                    # Triage + Guide prompts and strict parsers/validators (ports of lib/agent/*.dart)
  firebase-config.example.js  # placeholder web config (committed)
  firebase-config.js          # real web config + reCAPTCHA site key (gitignored until the owner approves publishing)
  corpus/cards.jsonl          # COPY of assets/corpus/cards.jsonl, written by the sync script, never edited by hand
  test/
    rag.test.mjs              # gate parity against test/fixtures/gate_parity.json; corpus hash check
    agent.test.mjs            # Triage parser, Guide validator cases mirrored from test/*_test.dart
    routing.test.mjs          # supported / unsupported / offline / cloud error / consent denied
  README.md                   # how to run locally, how judges open it
tool/sync_web_corpus.sh       # cp assets/corpus/cards.jsonl web/corpus/cards.jsonl + print sha256
test/fixtures/gate_parity.json  # shared cases: {query, lang, accepted, topIds}; read by a Dart test AND rag.test.mjs
test/gate_parity_test.dart      # Dart side of the parity check (new test file only; no lib/ change)
firebase.json                 # Hosting: public = "web" (only if Firebase Hosting is used)
```
Tests run with `node --test web/test/` (Node 20+, no npm dependencies). The modules under test don't import Firebase.

## Keeping the corpus and the gate in sync with Dart
- **Corpus:** `assets/corpus/cards.jsonl` is the single source of truth. `tool/sync_web_corpus.sh` copies it
  byte-for-byte into `web/corpus/`. `rag.test.mjs` compares the SHA-256 of both files and **fails** if they differ, so
  an edit to the Dart corpus without a re-sync turns the web tests red. (Not a symlink: Firebase Hosting and some
  static hosts don't follow symlinks out of the public folder.)
- **Gate behaviour:** `test/fixtures/gate_parity.json` holds about 40 cases (in-corpus EN/SW, panic strings, the 30
  off-topic checks from `test/fixtures/retrieval_fixture.dart`). Each case lists the expected accept/refuse decision
  and top-2 card ids. `test/gate_parity_test.dart` runs them through `RagService`; `rag.test.mjs` runs them through
  `rag.js`. A change to either implementation that changes a decision fails one side.
- Synonyms, stop words and thresholds are copied as constants at the top of `rag.js`, with a comment naming the Dart
  source line. The parity fixture is the real guard.

## App Check in the browser
- **Local development (owner only):**
  1. In `inference.js`, before `initializeAppCheck`, set `self.FIREBASE_APPCHECK_DEBUG_TOKEN = true` when
     `location.hostname === 'localhost'`.
  2. The SDK prints `AppCheck debug token: "…"` in the DevTools console.
  3. Register it: Firebase console → **Security → App Check → Apps → web app → ⋮ → Manage debug tokens**.
  4. The token stays in that browser's storage. It is **never** written into a file.
  5. `initializeAppCheck` is still called with the production provider object (below); the debug flag overrides it on
     localhost.
- **Judges (hosted):** use **reCAPTCHA Enterprise** as the web attestation provider. It is the web option named on the
  Firebase AI Logic App Check page.
  1. Create a reCAPTCHA Enterprise key for the hosted domain.
  2. Register it for the web app under App Check.
  3. Put the site key in `firebase-config.js`.
  - Judges then need nothing: real attestation, no debug token shipped. The site key and web API key are public client
    config by design, but CLAUDE.md says to **ask the owner before committing** them. Until then they stay in the
    gitignored `firebase-config.js`, and the hosted copy is deployed from the owner's machine.
- **Never** ship a fixed debug-token string in the page (anyone could read it from the source).
- Restrict the web API key (HTTP referrer = the hosting domain + `localhost`; API allowlist: Firebase AI Logic,
  App Check, Installations), as done for the Android key (`docs/RESEARCH_JUDGE_BUILD.md` (c)).

## How a judge runs or opens it
- **Open the hosted URL** (Firebase Hosting on the same project, e.g. `https://<project>.web.app`) in **desktop
  Chrome**. Without on-device support, and after the judge consents, they get the cloud route with the badge
  "Cloud · on-device not available in this browser". With a capable machine they can click "Get the on-device model"
  and see "On device".
- The README gives the Chrome requirements (Linux/macOS 13+/Windows 10+, 22 GB free disk, >4 GB VRAM or 16 GB RAM +
  4 cores), the flag, and `chrome://on-device-internals`.
- **Build from source:** `cd web && python3 -m http.server 8080`, then open `http://localhost:8080` with the judge's
  own Firebase project config and a debug token they register. Steps go in `web/README.md`.
- The **video** shows the on-device route on the owner's laptop with Wi-Fi off after the download, since few judges
  will have a capable machine.

## Task list, in order (estimates in hours)
| # | Task | Est. |
|---|---|---|
| 0 | Branch `feat/web-companion`. Check that `https://www.gstatic.com/firebasejs/13.4.0/firebase-app.js`, `firebase-ai.js` and `firebase-app-check.js` load as ES modules in Chrome. If `firebase-ai.js` doesn't exist there, switch to a 10-line Vite setup (`npm i firebase@13.4.0`, `vite build` → `web/dist`). | 0.5 |
| 1 | Skeleton: `index.html` + `inference.js` with App Check (debug on localhost) + one `generateContent` printing `inferenceSource`. **Gate:** one `ON_DEVICE` reply on the laptop with Wi-Fi off. Stop the whole plan here if this fails. | 1.5 |
| 2 | `tool/sync_web_corpus.sh`, `rag.js` port, `gate_parity.json` + Dart parity test + `rag.test.mjs` (hash check + parity). | 3.0 |
| 3 | `agent.js`: Triage + Guide prompts and strict parsers/validator, `agent.test.mjs`. | 2.0 |
| 4 | `routing.js` + `routing.test.mjs` (5 routing cases), wired into `inference.js`. | 1.0 |
| 5 | UI: status strip, panic buttons, ask box, answer card with citations and route badge + fallback reason; `styles.css` from the app theme, mobile-first, dark mode. | 2.5 |
| 6 | Consent sheet + settings toggle (consent kept in `localStorage`, default off, wrapped in try/catch → treated as "no consent"). | 1.0 |
| 7 | Limited mode (offline / no route → 2 cards + contacts card) and "Get the on-device model" button with progress. | 1.0 |
| 8 | Hosting: reCAPTCHA Enterprise key, App Check registration, `firebase deploy --only hosting`, API key restriction, smoke test from a second browser profile. | 1.5 |
| 9 | `web/README.md`, a root README section, 30–45 s of video on the laptop (Wi-Fi off → ON DEVICE; consent → cloud). | 1.0 |
| | **Total** | **≈ 15 h** (about 2 working days; realistically Fri afternoon to Sun) |

## What gets cut first (in this order)
1. **Hosting + reCAPTCHA Enterprise (task 8).** Fall back to "build from source" plus the video. Judges then can't
   open it in one click: a real cost, but the Android APK is the primary install.
2. **Panic buttons.** Keep the ask box only.
3. **Triage.** Guide only, gate first. The badge still proves the route.
4. **Dark mode / visual polish** beyond the shared palette.
5. **Dart-side parity test.** Keep the corpus hash check and the JS gate tests, and spot-check 10 queries by hand.

Never cut: the gate before the model, the citation/number validator, the consent default (off), the route badge, and
App Check (no shipped debug token).

## Risks
- **SDK loading without a bundler** (task 0). Mitigation: Vite. +0.5 h.
- **Download time / disk** on the laptop. Do it once, early (the Chrome test doc).
- **On-device quality for Guide** with 2 cards in English. Measure in task 1. If replies fail the validator, the web
  route falls back to showing the cards (limited-mode presentation) on-device and uses the cloud only with consent.
- **Time:** it competes with Android QA, README, video and Devpost on Sat–Sun. If task 1 isn't green by Fri 18:00 EAT,
  stop and put the time back into Android.
