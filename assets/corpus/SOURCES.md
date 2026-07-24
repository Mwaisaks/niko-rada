# Niko Rada — Knowledge Corpus Sources

All knowledge cards in `cards.jsonl` are derived from the authoritative sources listed below.
This log records provenance and verification status for each source.

Last full contact-verification pass: **2026-07-23**.

---

## Sources Used

| Source | URL | Domains | Verified |
|--------|-----|---------|---------|
| EFF Surveillance Self-Defense | https://ssd.eff.org/module/attending-protest | evasion_safety, documentation, blackout_comms | ✅ |
| ICRC First Aid | https://www.icrc.org/en/first-aid | first_aid | ✅ |
| Kenya Red Cross | https://redcross.or.ke | first_aid, contacts | ✅ |
| Access Now Digital Security Helpline | https://www.accessnow.org/help | blackout_comms, evasion_safety | ✅ |
| Missing Voices Kenya | https://missingvoices.or.ke | documentation, rights, contacts | ✅ (URL corrected — see below) |
| KHRC (Kenya Human Rights Commission) | https://www.khrc.or.ke | rights, documentation, contacts | ✅ |
| Amnesty International Kenya | https://www.amnestykenya.org | rights, contacts | ✅ (URL corrected — see below) |
| LSK (Law Society of Kenya) | https://www.lsk.or.ke | rights, contacts | ✅ |
| KNCHR (Kenya National Commission on Human Rights) | https://www.knchr.org | rights, contacts | ✅ |
| IMLU (Independent Medico-Legal Unit) | https://www.imlu.org | documentation, contacts | ✅ |
| Constitution of Kenya 2010 | https://www.kenyalaw.org | rights, evasion_safety | ✅ |
| Briar Project | https://briarproject.org | blackout_comms | ✅ |
| Signal Foundation | https://signal.org | blackout_comms | ✅ |
| Nairobi Hospital | https://www.nairobihospital.org | contacts | ✅ |
| Aga Khan University Hospital Nairobi | https://agakhanhospitals.org/en/kenya | contacts | ✅ |

---

## Contact Verification Log (2026-07-23 pass)

This pass re-checked every phone number against the organisation's own website (direct fetch) or, where the
primary site blocked automated access, against multiple independent, reputable secondary sources (noted below).
**Two numbers from the previous pass were found to be wrong and have been corrected.** No number in the corpus
was invented — anything that could not be confirmed either way is flagged below and excluded from the app's
retrieval via `"verified": false` if it appears at all.

| Organisation | Number in corpus now | Verified against | Status | Note |
|---|---|---|---|---|
| General Emergency (Kenya) | 999 / 112 | Standard national emergency numbers | ✅ Verified | Unchanged |
| Kenya Red Cross Ambulance | **1199** (toll-free) | Corroborated via Daily Nation, HapaKenya, Pulse.co.ke (redcross.or.ke itself returned HTTP 403 to automated fetch, twice) | ✅ Verified (secondary-source corroborated) | **CORRECTED** — old corpus had `0800 720 141`, which no source could confirm. Replaced with `1199`, consistently cited by multiple independent Kenyan outlets as the free 24/7 ambulance line. |
| Nairobi Hospital Emergency | +254 20 284 5000 | Direct fetch, nairobihospital.org/contacts.html | ✅ Verified | Unchanged — confirmed correct |
| Aga Khan University Hospital (Nairobi) | +254 20 366 2000 (main), +254 20 366 2025 (adult casualty) | Direct search corroboration, two independent queries | ✅ Verified | Main number unchanged; added the more specific Adult Casualty line |
| KHRC | +254 20 204 4545 / +254 20 210 6763 (landline), +254 722 264 497 / +254 733 629 034 (mobile) | Direct fetch, khrc.or.ke | ✅ Verified | **CORRECTED** — old corpus had `+254 20 387 4998`, which does not appear on the official site. Replaced. |
| Amnesty International Kenya | +254 759 464 346 | Direct fetch, amnestykenya.org/contact-us/ | ✅ Verified | **CORRECTED** — old corpus had `+254 20 428 2340` (wrong number) and cited `amnesty.or.ke` (wrong domain, returns 404). Correct domain is `amnestykenya.org`. |
| LSK | +254 799 595 800 | Direct fetch, lsk.or.ke | ✅ Verified | New addition — not previously in the corpus |
| KNCHR toll-free | 0800 720 627 | Corroborated via The Star (2026-06-25, "KNCHR issues emergency hotlines" for protest-related reports) alongside SMS 22359 | ✅ Verified | Unchanged, now corroborated by a specific protest-context source |
| KNCHR head office | +254 20 396 9000 | Direct fetch, knchr.org/contact-us | ✅ Verified | New addition |
| IMLU | 0800 721 401 (toll-free) | Direct fetch, imlu.org | ✅ Verified | New addition — not previously in the corpus |
| Missing Voices | *(no phone number claimed)* | Direct fetch, missingvoices.or.ke | ✅ Verified (website/report-form only) | **URL CORRECTED** — old corpus cited `missingvoices.net`, which no longer resolves (DNS failure). Correct domain is `missingvoices.or.ke`. No phone hotline found on the site after two checks (About page + homepage) — they operate via a "Report Incident" web form. The card does **not** invent a phone number for them. |

**Could not verify / explicitly excluded:** none outstanding — every contact currently in `cards.jsonl` is backed by
at least one of: a direct fetch of the organisation's own site, or multiple independent reputable secondary
sources. If a future pass cannot confirm a number, the rule below applies.

---

## Curation Rules (Non-Negotiable)

1. Every card cites a real authoritative source. No invented advice.
2. Contacts must be verified against official sites (or, if the official site blocks automated access, corroborated
   by multiple independent reputable secondary sources) before shipping. Wrong numbers are worse than none.
3. Any contact that cannot be verified either way must be set `"verified": false` in `cards.jsonl` — this
   automatically excludes it from retrieval in `rag.dart`. Never invent or guess a number.
4. All guidance is de-escalation and protection oriented — move, avoid, document, seek help.
5. Every answer carries a disclaimer: *guidance, not a guarantee; not legal/medical advice.*

---

## Cards Summary (41 cards, 2026-07-23)

| Domain | Count |
|--------|-------|
| first_aid | 11 |
| evasion_safety | 7 |
| blackout_comms | 7 |
| documentation | 6 |
| rights | 6 |
| contacts | 4 |
| **Total** | **41** |

### Priority demo-path cards (all bilingual en/sw, verified)

| ID | Domain | Scenario |
|----|--------|----------|
| teargas-001 | first_aid | Tear gas |
| evasion-001 | evasion_safety | Being followed |
| doc-001 | documentation | Witnessed abduction / someone grabbed |
| comms-001 | blackout_comms | Network down |
| phone-001 | documentation | Prepare my phone |

### Full card list

| ID | Domain | Bilingual |
|----|--------|-----------|
| teargas-001 | first_aid | ✅ |
| teargas-002 | first_aid | ✅ |
| evasion-001 | evasion_safety | ✅ |
| evasion-002 | evasion_safety | ✅ |
| comms-001 | blackout_comms | ✅ |
| comms-002 | blackout_comms | ✅ |
| doc-001 | documentation | ✅ |
| doc-002 | documentation | ✅ |
| phone-001 | documentation | ✅ |
| rights-001 | rights | ✅ |
| rights-002 | rights | ✅ |
| firstaid-001 | first_aid | ✅ |
| firstaid-002 | first_aid | ✅ |
| contacts-001 | contacts | ✅ |
| rights-003 | rights | ✅ |
| comms-003 | blackout_comms | ✅ |
| evasion-004 | evasion_safety | ✅ |
| firstaid-003 | first_aid | ✅ |
| comms-004 | blackout_comms | ✅ |
| firstaid-004 | first_aid | ✅ |
| evasion-003 | evasion_safety | ✅ |
| choking-001 | first_aid | ✅ |
| heat-001 | first_aid | ✅ |
| unconscious-001 | first_aid | ✅ |
| pepperspray-001 | first_aid | ✅ |
| buddy-001 | evasion_safety | ✅ |
| exitroutes-001 | evasion_safety | ✅ |
| curfew-001 | evasion_safety | ✅ |
| radio-001 | blackout_comms | ✅ |
| vpn-001 | blackout_comms | ✅ |
| photo-001 | documentation | ✅ |
| metadata-001 | documentation | ✅ |
| evidence-001 | documentation | ✅ |
| press-001 | rights | ✅ |
| recordpolice-001 | rights | ✅ |
| minors-001 | rights | ✅ |
| contacts-lsk-001 | contacts | ✅ |
| contacts-imlu-001 | contacts | ✅ |
| contacts-missingvoices-001 | contacts | ✅ |
| eyeinjury-001 | first_aid | ✅ |
| dualsim-001 | blackout_comms | ✅ |
