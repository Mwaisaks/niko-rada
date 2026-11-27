# Chrome Prompt API test — owner's 16 GB Ubuntu laptop (prepared 27 Nov 2026)

Goal: see whether Chrome on the laptop can run Gemini Nano on-device (`availability` → `'available'`, then a real
`prompt()` reply). This decides whether the web companion (`docs/WEB_COMPANION_PLAN.md`) can show **real on-device**
inference. About 15 minutes plus the model download.

Sources read 27 Nov: https://developer.chrome.com/docs/ai/prompt-api (updated 21 Oct 2026),
https://developer.chrome.com/docs/ai/get-started, https://firebase.google.com/docs/ai-logic/hybrid/web/get-started.
**Confirmed** = on those pages. **Unconfirmed** = not stated there.

## 0. Before you start
- **Chrome version:** open `chrome://version`. The Prompt API status table lists the web API in **Chrome 148**; the
  Firebase hybrid web page says Chrome Desktop **139+**. Update Chrome to the latest stable first.
- **Requirements (confirmed):** Linux is supported; **22 GB free** on the disk holding the Chrome profile
  (`df -h ~/.config/google-chrome`); either a GPU with **more than 4 GB VRAM** or **16 GB RAM and 4+ cores** (your laptop
  should qualify on the CPU path); an **unmetered** network for the one-time download (not a phone hotspot that Chrome
  sees as metered).
- On 26 Nov `LanguageModel.availability()` already returned `'downloadable'` on this laptop, so the machine is eligible.
- Open a normal **https** page in a regular (not Incognito) window, for example `https://example.com`, then DevTools →
  Console. Don't use `about:blank` or `chrome://` pages: whether the API is exposed there is unconfirmed. The API is
  available to top-level windows and same-origin iframes only (confirmed), not in Web Workers.

## 1. Paste into the Console (one block)

The options object is the **same** for `availability()` and `create()` (the docs require this). English only for input
and output: Chrome accepts `en`, `ja`, `es`, `de`, `fr`; Kiswahili is not on-device.

```js
// Niko Rada — Chrome Prompt API check. Paste into the DevTools Console of an https page.
const NR_OPTS = {
  expectedInputs:  [{ type: 'text', languages: ['en'] }],
  expectedOutputs: [{ type: 'text', languages: ['en'] }],
};

async function nrCheck() {
  if (typeof LanguageModel === 'undefined') {
    console.warn('LanguageModel is undefined: see section 3 of CHROME_PROMPT_API_TEST.md');
    return 'undefined';
  }
  const a = await LanguageModel.availability(NR_OPTS);
  console.log('availability:', a, '| user activation:', navigator.userActivation.isActive);
  return a;
}

// Creates a session (starts the download if needed), sends one single-turn prompt, prints the reply.
async function nrRun() {
  const t0 = performance.now();
  const session = await LanguageModel.create({
    ...NR_OPTS,
    monitor(m) {
      m.addEventListener('downloadprogress', (e) =>
        console.log(`download: ${Math.round(e.loaded * 100)}%`));
    },
  });
  console.log('session ready in', Math.round(performance.now() - t0), 'ms;',
              'context:', `${session.contextUsage}/${session.contextWindow}`);
  const prompt =
    'Classify this message. Reply with ONE line only, in the format type|severity|active.\n' +
    'type is one of: tear_gas, abduction, arrest, checkpoint, network_blackout, medical, surveillance, ' +
    'protest_rights, other. severity is low, medium, high or critical. ' +
    'active is yes or no.\nMessage: "Police are firing tear gas at our street right now and my eyes are burning."';
  const t1 = performance.now();
  const reply = await session.prompt(prompt);
  console.log('reply in', Math.round(performance.now() - t1), 'ms:', JSON.stringify(reply));
  session.destroy();
  return reply;
}

await nrCheck();
```

Then, depending on what `nrCheck()` printed:

| `availability` | What to do |
|---|---|
| `'available'` | Run `await nrRun()`. Done when a reply such as `tear_gas|high|yes` prints. |
| `'downloadable'` | The download needs a **user gesture**. Click anywhere on the page, then *immediately* run `await nrRun()` (or run `document.body.addEventListener('click', () => nrRun(), { once: true })` and click the page). Watch the `download: N%` lines. |
| `'downloading'` | A download is already running. Watch `chrome://on-device-internals`; run `await nrCheck()` every few minutes until `'available'`, then `await nrRun()`. |
| `'unavailable'` | See section 3. |

A user gesture in the page counts; whether typing in the DevTools console counts as one is unconfirmed, which is why
the click handler is the fallback.

**Expected result (pass):** `availability: available`, a `reply in … ms` line with a one-line answer. Record the Chrome
version, the reply, both timings and the `context` line in section 4. Also run it once with Wi-Fi **off** after the
download: a reply then proves it ran on-device.

## 2. Check what Chrome reports
- `chrome://on-device-internals` → **Model Status** (model version, size, download state) and the **Broker State** tab
  (eligibility errors). The getting-started page uses this page for model size and debugging.
- Optional: the "Web AI Studio" extension (https://web-ai.studio/extension) checks hardware eligibility (mentioned by
  Google's getting-started page; not tried).

## 3. If something goes wrong

**`LanguageModel` is undefined**
1. Check `chrome://version`. Below 148 (web API) → update Chrome, restart, retry.
2. Check you are on an **https** page in a normal window (not `about:blank`, Incognito, a `chrome://` page, an
   extension page or a worker).
3. Open `chrome://flags`, search for **`prompt-api`**. The Firebase hybrid page asks for
   `chrome://flags/#prompt-api-for-gemini-nano-multimodal-input` → **Enabled**; if a plain
   `#prompt-api-for-gemini-nano` flag also exists, enable it too. Relaunch Chrome. (Only the multimodal flag is named in
   the docs read today; any other flag name is **unconfirmed**.)
4. If Chrome is a Snap or Flatpak build or Chromium rather than Google Chrome, install Google Chrome stable from
   google.com (`.deb`). Whether Chromium builds ship the on-device model is unconfirmed.

**`availability` is `'unavailable'`**
1. Make sure both `availability()` and `create()` get **exactly** `NR_OPTS`. A language Chrome doesn't support (for
   example `sw`) makes the session unsupported.
2. `df -h ~/.config/google-chrome`: at least 22 GB free.
3. `chrome://on-device-internals` → Broker State: read the error (performance class, disk, enterprise policy).
4. Restart Chrome fully (`pkill chrome`), open the page, run `await nrCheck()` again. Google's checklist: restart →
   on-device-internals → Broker State → `LanguageModel.availability()` in DevTools → wait and retry.
5. Still unavailable → record the Broker State text in section 4. That means no on-device demo on the laptop; the web
   companion would be cloud-only and isn't worth building.

**`'downloadable'` never moves to downloading**
- Make sure a click happened just before `create()` (`navigator.userActivation.isActive` should print `true`).
- Make sure the network isn't metered (Ubuntu Settings → Wi-Fi → connection → "Metered connection" off).

**`prompt()` throws**
- `QuotaExceededError`: the prompt is too long for the context window (unlikely with this prompt).
- `NotSupportedError` or similar: the options differ between `availability()` and `create()`.

## 4. Results (owner fills in)
| Field | Value |
|---|---|
| Date / time (EAT) | |
| Chrome version (`chrome://version`) | |
| Flags changed | |
| `availability` before / after download | |
| Download time | |
| Model version (on-device-internals) | |
| Reply (verbatim) | |
| Session create time / prompt time | |
| Works with Wi-Fi off after download? | |
| Broker State errors, if any | |
