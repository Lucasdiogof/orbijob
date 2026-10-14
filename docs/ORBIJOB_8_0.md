# OrbiJob 8.0 — catalogue coverage and quality (2026-10-14)

## Measurement (production, same read as the app; database 176 MB of 500 MB)
13 published sources, **13,491 open and visible listings** (6.0 measured 12,970). By source (visible / without country / description under 200 characters):
jobtech 3,471 / 1 / 15 · arbeitnow 2,400 / 695 / 7 · twjobs 1,168 / 0 / 633 (CJK: short by language, measured in characters) · bpce 1,000 / 12 / 1 · forem 1,000 / 0 / 289 (facts only, by the owner's decision) ·
jobicy 976 / 273 / 1 · karrierenrw 931 / 0 / 0 · nycjobs 800 / 0 / 0 · teachingvacancies 700 / 0 / 3 · getonboard 600 / 296 / 0 · jobsconz 324 / 0 / 0 · remoteok 103 / 96 / 1 · remotive 18 / 17 / 0.
Without a country: **1,390**; nearly all are remote listings whose source states no country (jobicy 273, getonboard 296, remoteok 96) or Arbeitnow places that two countries share. They are left empty on purpose (a country is stored only when the source states it).
Reviewed and kept: Arbeitnow's refusal of "Remote Switzerland" / lists of places is a deliberate 6.0 decision (a mode with a country is eligibility, not a place); the few extra listings a looser rule would rescue (~10) do not justify contradicting it.
Search benchmark on the live catalogue: `docs/evidence/search-benchmark-2026-10-14.txt` (34 professions in PT/EN/DE/SV, 5.0 rules). Highlights: physiotherapist 220, nurse 175, teacher 409, civil engineer 42, electrician 27, welder 39, cook 14, truck driver 2 (motorista 91), Flutter 1–4. **Pelvic-health physiotherapy: 0** (no source lists it; nothing is added artificially).

## Sources evaluated in 8.0
| Candidate | Region | Class | Evidence |
|---|---|---|---|
| Canada Job Bank "Job postings" (open.canada.ca, Open Government Licence – Canada) | Canada | BLOCKED for our purpose | monthly CSV of the PREVIOUS month; no employer name, no description, **no URL of the posting** (columns checked 2026-10-14) — nothing to link to |
| City of Edmonton "Public Job Opportunities" (Socrata `7kmt-35ac`, "Open Government Licence – Edmonton") | Canada | PERSIST-ready, not built | 36 listings, title/category/closing date and a direct link; licence stated by the portal; too small to justify a connector + schedule alone |
| City of Calgary Careers (Socrata `5fsi-n9xm`) | Canada | PENDING | 61 listings, title + link only; licence page ("Open Data Terms") is not retrievable from this environment — verify before using |
| Latvia NVA "Vakances" (CC0) | Latvia | PENDING | unchanged from 6.0: no employer name |
| Brazil: Emprega Brasil/SINE, Catho, BNE, dados.gov.br | Brazil | none usable | no public API or open dataset with a reuse licence found (searches 2026-10-14); Trampos/Landing.jobs/Torre BLOCKED in 6.0 |
| Mexico: SNE vacancies | Mexico | none usable | portal only (empleo.gob.mx); a 2018 state dataset is stale |
| Colombia, Chile, Argentina, Uruguay open-data portals | LatAm | none usable | no vacancy dataset found (datos.gov.co only has an unrelated referral table) |
| Singapore MOM, Australia JSA | Asia/Oceania | not listings | aggregate statistics / 2009–2015 archive |
Combined Canadian municipal feed (Edmonton + Calgary ≈ 97 listings) is the only buildable item left; recorded as an optional low-value next step.

## Get on Board
Re-read, unchanged: no explicit grant; terms restrict copying/automatic download in the *customer agreement*. Growth frozen at the stored 600; request drafted (not sent) and the reversible unpublish documented in `docs/GETONBOARD_PERMISSION.md`.

## Not done (needs the owner or does not exist)
A Brazilian/Latin-American source with a licence; the Get on Board answer; NAV/USAJOBS/Jooble keys.
