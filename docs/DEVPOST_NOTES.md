# Devpost write-up notes (collected during the build)

Facts to use in the submission text. Each one is observed, dated and sourced; do not embellish.

## Why Niko Rada shows verified corpus text instead of free-form generation
- 25 Nov 2026, spike run on a Samsung Galaxy A16 (cloud route, Firebase AI Logic): asked an open question in Sheng
  without corpus grounding, the cloud model **answered in Kiswahili, not Sheng**, and called tear gas
  **"machozi ya pilipili"** ("pepper tears"), which is wrong. Source: owner's spike report, recorded in
  `docs/RESEARCH_HYBRID_ANDROID.md` (section f).
- This is why answers are grounded in the 41 verified cards, cited, refused when out of corpus, and why Kiswahili users
  see the verified Kiswahili card text rather than generated Kiswahili.

## Honest limitation (say it plainly)
- A budget phone without Gemini Nano, during a total network shutdown, gets neither model route. Observed on the
  Galaxy A16: offline requests failed in 50–95 ms. Niko Rada then switches to limited mode: verified cards and contacts,
  no AI (`docs/LIMITED_MODE.md`).
