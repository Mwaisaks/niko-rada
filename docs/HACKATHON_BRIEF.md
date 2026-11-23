# #BuildHybridAI 2026 — brief

Source: https://firebasehybridaihackathon.devpost.com/ (re-check the Rules and FAQs pages before submitting; this brief was written from the overview page).

## Theme
Build apps that use **Firebase AI Logic Hybrid Inference**: prompts run on-device when a local model is available and fall
back to the cloud when it isn't. Open to new projects and significantly updated existing apps.

## Dates
- Deadline: **Mon 30 Nov 2026, 2:00pm PST** (Tue 1 Dec, 1:00am EAT). Our internal deadline: Sun 29 Nov evening EAT.
- Optional Google Account Quota (only for advanced features such as image generation): Sprint 3 (final) request by Wed 25 Nov 10:00 AM PT, account sent Fri 27 Nov, valid 4 days. Text inference is free within limits, so likely not needed.

## Platforms (pick at least one; the submission is categorised by the platform selected)
- **Web (Chrome):** Gemini Nano via Firebase AI Logic. Web app or Chrome extension. On-device inference is Chrome on Desktop only (v139+; Firebase AI Logic Web SDK v12.5.0+), built on Chrome's Prompt API.
- **Android (our platform):** Gemini Nano via Firebase AI Logic (hybrid API is experimental; uses ML Kit Prompt API on-device; native Kotlin only, no Flutter support in `firebase_ai`). Guide: https://firebase.google.com/docs/ai-logic/hybrid/android/get-started
- **iOS:** Apple Foundation Models via Firebase AI Logic.
- Multi-platform apps get strong consideration for the Grand Prize; an outstanding single-platform app can still win.

## Prizes ($30,000)
| Prize | Cash | Extras |
|---|---|---|
| Grand Prize | $10,000 | Interview, featured Firebase blog post, social mention |
| 1st Runner Up | $7,000 | Interview, featured blog post, social mention |
| 2nd Runner Up | $4,000 | Social mention |
| Best iOS App | $3,000 | Social mention |
| Best Android App | $3,000 | Social mention |
| Best Web/Chrome App | $3,000 | Social mention |

Our target: **Best Android App** as the floor; Grand / 1st / 2nd as stretch.
Open question (check Rules): whether one project can win both an overall prize and a platform prize.

## Judging criteria (the four things to tailor everything to)
1. **Technological Implementation** — how well it is built and how effectively it uses Firebase AI Logic hybrid inference.
2. **Design** — a complete, coherent product experience, not a technical proof of concept.
3. **Potential Impact** — a credible, specific case for a real problem and real audience, supported by what the demo shows.
4. **Quality of the Idea** — creative, non-obvious use of Firebase AI Logic; genuine understanding of the problem space.

## Requirements
- Gen AI app using Firebase AI Logic, plus supported Firebase products where useful (App Check required; Remote Config, Firestore, Authentication encouraged).
- Any coding tool is allowed as long as the app's AI runs on Firebase AI Logic. Firebase agent skills are recommended.
- **Existing app:** provide a summary of what was built during the submission period; if it already has public usage, a description of the core value the existing app provides (optionally how widely used).
- **Text description:** how Firebase AI Logic is used, features/functionality, value proposition.
- **Public repo** (GitHub/GitLab) with all source, assets and instructions, a detectable open-source license shown in the About section (Apache preferred), the value proposition detailed, and Firebase AI Logic **imported and actually called at runtime** (not just named in the README).
- **Demo video:** ≤ 3 minutes (only the first 3 are judged), public on YouTube, English or English subtitles, shows the project working on the platform it was built for.
- Strongly encouraged: a hosted URL / installable build for judges to test.
- Free to use; all materials in English; eligible countries exclude only a short list (Kenya is eligible).
- More than one project may be submitted if substantially different.

## Submission checklist
- [ ] Platform selected on Devpost matches what the video shows
- [ ] Repo public, license visible, README complete, no secrets in history
- [ ] Firebase AI Logic call sites easy to find (point to the file in the README)
- [ ] "What we built during the window" summary written (existing repo: diff against pre-window baseline `c745a39`, dated commits)
- [ ] Description covers: Firebase AI Logic usage, features, value proposition
- [ ] Demo video ≤ 3:00 on YouTube (public), English
- [ ] APK release link tested from a clean device
- [ ] Submitted at least 6 hours before the deadline
