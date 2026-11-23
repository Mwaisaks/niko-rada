# Phone test checklist

> **Superseded:** this checklist is for the old `flutter_gemma` / Gemma 4 E2B build. For the Firebase AI Logic hybrid build,
> see `docs/SPIKE_CHECKLIST.md`.

Prepared 2026-07-25, on a desktop/laptop with no Android device and no Android SDK
available yet (see `README.md` for the SDK setup that was done this session). This
is the ordered checklist for the first real-hardware session — **do not skip steps
to save time**; each one isolates a different failure mode, and the whole point of
this doc is to know *which* layer broke if something does.

The debug APK (`flutter build apk --debug --target-platform android-arm64`) builds
clean and was verified locally. Nothing below has been run on hardware yet.

## 0. Before you plug anything in

- [ ] Confirm the phone is **6 GB+ RAM**. Gemma 4 E2B needs headroom above its own
      ~2.6 GB footprint for the OS + app + inference buffers; our only test device so
      far is 4 GB, which is below the floor — that's *why* this is untested, not a
      choice. If the borrowed phone is also under 6 GB, expect Limited Mode (step 8)
      to trigger, not a working demo.
- [ ] Enable Developer Options + USB debugging on the phone.
- [ ] `adb devices` shows the phone before doing anything else. If it doesn't, stop
      and fix the USB/driver connection first — nothing past this point works
      without it.

## 1. Install

- [ ] `flutter build apk --debug --target-platform android-arm64` (rebuild fresh —
      don't reuse an old APK in case the corpus/prompts changed since).
- [ ] `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
- [ ] App icon appears, launches without an immediate crash.

## 2. Every screen renders

Walk all five, just navigation — no AI calls yet:

- [ ] Splash/shell loads.
- [ ] Panic grid (all scenario buttons visible, tappable).
- [ ] Chat screen (text input works, keyboard appears).
- [ ] Incident logger (text entry + voice-record button visible).
- [ ] Settings / language toggle (English/Kiswahili/Sheng options present).

If any screen fails here, it's a UI/state bug, unrelated to Gemma — fix before
going further so you're not debugging two problems at once.

## 3. Language toggle

- [ ] Switch language in settings, confirm UI labels actually change. This is
      cheap to check and rules out a wiring bug before you get to the expensive
      model-download step.

## 4. Model download (F0) — **unverified flow, watch closely**

This is flagged because we curled/tested the model URL before but have **never
run the actual in-app resumable download flow end-to-end**.

- [ ] On Wi-Fi, trigger the download screen.
- [ ] Confirm it shows real progress (not stuck at 0% or 100% instantly).
- [ ] Confirm the downloaded size matches expectations (~2.6 GB for Gemma 4 E2B
      `.litertlm` weights).
- [ ] Kill the app mid-download (force-stop), relaunch, confirm it **resumes**
      rather than restarting from zero or corrupting.
- [ ] After completion, confirm the app doesn't re-download on next launch.

If this flow has a bug, it'll most likely show up here first, not later — a
half-downloaded or corrupt model file will surface as a confusing engine-load
error in the next step, not a download error.

## 5. Model load

- [ ] After download completes, the app proceeds to actually load the model
      (`getActiveModel()` → engine init) without hanging or crashing.
- [ ] Note how long this takes — first real signal for whether the phone's RAM/CPU
      can handle Gemma 4 E2B at all.

## 6. **Highest-risk step: on-device `libLiteRtLm` load**

This is the single most likely place for a repeat of the desktop failure. The
desktop build has never gotten a completed generation past this exact layer — the
LiteRT-LM FFI engine failed identically in a plain terminal, not just inside our
dev sandbox. Android is a different native build/ABI path (arm64-v8a prebuilt
`.so`, fetched and SHA256-verified by `flutter_gemma_litertlm`'s build hook — see
`README.md`), so it is **not guaranteed to hit the same bug**, but it's the same
class of failure and the same library family. Watch for:

- [ ] An opaque `dlopen: no such file` or similar native-load error immediately
      after model load starts.
- [ ] If it appears: **do not immediately assume it's the same bug as desktop.**
      First try the documented fix (`flutter clean`, clear
      `~/.cache/flutter_gemma/native`, `flutter pub get`, reinstall) since that's a
      known, different failure mode (stale native-asset cache/ownership marker,
      see package README). Only escalate as "same root cause as desktop" if the
      clean-rebuild fix doesn't help.

## 7. One offline generation, airplane mode

- [ ] Turn on airplane mode (this is the actual point of the whole app — it must
      work with zero network).
- [ ] Trigger one panic-button query (pick a scenario with a strong corpus match,
      e.g. tear gas).
- [ ] Confirm: a real generated answer appears, grounded/cited, closes with the
      bilingual disclaimer — matching what the Kaggle notebook already proved the
      pipeline produces off-device.
- [ ] Confirm no network call is attempted (no spinner waiting on connectivity,
      no error about being offline — the app shouldn't even try).

This is the step that actually closes the gap this whole session was prep for.
Everything before it is prerequisite; this is the proof.

## 8. Graceful Limited Mode on OOM

- [ ] If the model fails to load or generation crashes due to memory pressure
      (likely if the borrowed phone is under 6 GB), confirm the app falls back to
      Limited Mode rather than hard-crashing — this fallback path is itself
      untested, so don't be surprised if it needs a fix too.

## 9. Record the demo

- [ ] Screen-record steps 6–7 (the two highest-value/highest-risk moments) at
      minimum, ideally the full flow from install through one generation. This is
      the evidence that was missing at hackathon submission time — get it before
      the phone has to go back.

## After the session

Update `README.md`'s status table and `WRITEUP.md`'s "what we have not verified"
section with the real outcome — pass, partial, or the specific failure point —
regardless of which way it goes. Don't leave this doc as the only record.
