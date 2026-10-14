# OrbiJob 12.0 — progress checkpoint (started 2026-10-14)

## Initial state (verified)
main = origin/main at `6421c35`, CI green; worktrees: `C:/Users/lucas/orbijob` (main) and `C:/Users/lucas/orbijob-wt7` (clean, can stay); 2 stashes + backup `C:\Users\lucas\orbijob-backups\otp-tree-2026-10-14` preserved; untracked `.idea/` and `_aplicar/` (owner SQL packs) deliberately not versioned. Supabase project `rpmlfxwebnlxnwadyvle` (linked). 13,586 visible listings at 04:30 UTC (ops-health).
Work in 12.0 is done directly in `C:\Users\lucas\orbijob` (now clean and the only writer).

## Source research (2026-10-14), by category — see docs/SOURCES_12_0.md for the evidence table
| Candidate | Class | Why |
|---|---|---|
| ATS public APIs (Greenhouse, Lever, Ashby, SmartRecruiters) | PENDING (not integrated) | public GET without authentication, **no stated licence or terms for third parties**; Lever's README only says published jobs "may be scraped by third parties"; SmartRecruiters' Public Posting API wants a key. They are per-employer; the employer content has no grant to store or republish |
| Himalayas (remote, 124,107 jobs) | PENDING | the API page asks for a visible link back and says the API is free with no auth, but the Terms of Service forbid scraping/mirroring/storing site content (clauses 2, 29, 30, 93, 46) and the API page is silent on storage; request drafted below |
| Working Nomads, We Work Remotely | PENDING | JSON/RSS answer 200, terms pages not retrievable (404/403): no evidence of permission |
| The Muse | BLOCKED here | 403 from this environment, key/terms unknown |
| Bundesagentur Jobsuche | BLOCKED here | 403 with the documented public key from this environment (as in 6.0) |
| "Vacatures Overheid" (data.overheid.nl, CC0, Dutch government WerkenvoorNederland) | PENDING | licence CC0, dataset modified 2026-09-22, but the API host `docs.api.cso20.net` / `api.cso20.net` answered **503** on 2026-10-14; retry later |
| France Travail "Offres d'emploi" (data.seinesaintdenis.fr, Licence Ouverte v2.0) | REJECTED | 150 records, a snapshot of 2026-08-27, not live |
| Région Île-de-France and Tours jobs (data.gouv.fr, LOv2, updated today) | PENDING, small | tens of listings each; worth a single "French local government" connector only if more portals are found |
| Edmonton (OGL-Edmonton) / Calgary | PENDING | ≈ 97 listings in total, see 8.0 |
| Portugal IEFP "Ofertas de emprego" (dados.gov.pt, CC BY) | REJECTED | a movement statistic ("movimento ao longo do tempo"), not listings |
| Poland dane.gov.pl, Spain datos.gob.es, Australia data.gov.au, Ireland data.gov.ie | REJECTED | only statistics or archives (CSO vacancy rates; JSA 2009–2015) |
| Canada Job Bank open data | REJECTED | monthly snapshot without employer or posting URL |

### What was built instead for the countries with no licensed source (LINK_ONLY)
`country_portals.dart` + the empty-search state: when the person filters by a country and the catalogue has nothing, the screen says so and offers a button to **that country's official public employment service** (23 countries incl. Brazil, Portugal, Spain, Mexico, Argentina, Chile, Colombia, Uruguay, Canada, Australia, Japan, Singapore, South Africa). Nothing from those portals is copied, stored or shown as a job. 3 languages; 2 unit tests + 1 widget test; each address was opened on 2026-10-14 (Emprega Brasil answers only to modern TLS clients: it did not open from this environment's curl/PowerShell, and the entry is the ministry's own address).

## Drafted permission requests (NOT sent; the owner decides)
* Himalayas — hi@himalayas.app: "OrbiJob (https://github.com/Lucasdiogof/orbijob) is a free job-search app. Your API page allows showing Himalayas jobs with a visible link back; your terms forbid copying site content. May we store title, company, country restrictions, salary, apply link and the sanitized description of the jobs returned by the public API (refreshed once a day) and show them with 'Jobs via Himalayas' and a link to each job on himalayas.app? We will stop on request."
* Get on Board — see `docs/GETONBOARD_PERMISSION.md` (unchanged, still no answer).

## Done in 12.0 so far
(see the git log; the list is kept at the end of this file)

## Done in 12.0 (as of 2026-10-14 ~05:40 UTC)
* `b2c60f7` LINK_ONLY: official public employment service of the filtered country in the empty search state (23 countries, 3 languages, tests).
* **`cf89d26` new source `mpsvcz` = Úřad práce ČR / MPSV (Czech Labour Office open data "Volná pracovní místa")**: first source with blue-collar coverage (construction, kitchen, waiters, cleaners, warehouse, drivers). Evidence: publisher's own terms statement (no copyright, no database right, no sui generis right, no personal data; https://data.mpsv.cz/web/data/podminky-uziti), file refreshed daily (~190 MB, 39,774 vacancies, 36,888 + 2,874 published), code lists in the same open-data folder, deep link `https://up.gov.cz/volna-mista-v-cr#/volna-mista-detail/{portalId}` (verified in the browser). Connector streams the file (`worker/src/json-stream.ts`, 6 tests), keeps the 3,000 most recently inserted of those changed in the last 14 days, never reads employer contact people/e-mails/phones (phones in free text masked), CZK salary only when plausible for its period. `canonicalUrl` now keeps `#/` SPA routes (otherwise all listings collapse into one URL). Live check: 3,000 jobs, 0 rejected, 8-10 s. 12 unit tests + live test (`MPSVCZ_LIVE=1`), 842 Worker tests pass.
* Production: row `mpsvcz` inserted (CONDITIONAL, **can_redistribute=false = NOT shown in the app yet**); preview and one real discover pass run in Actions (1,000 imported, 931 with town, 992 with salary, all links valid, no duplicates); the per-hour lease allows one pass per hour, schedules `43 13 * * *` and `8 19 * * *` fill the rest of the 3,000 over the next day.

## NEXT STEPS (for the next account)
1. **Publish `mpsvcz`** when the stored set looks right: owner runs `scripts/supabase/ops/publish_source.sql` with the usual guard phrase (I do not compose or run it). Before that, re-check coverage with `scripts/supabase/diagnostics/coverage.sql` and sample titles.
2. **Czech search**: Czech titles are not matched by profession names (ESCO table has 7 languages). `scripts/esco-fetch.mjs` now lists `cs` in LANGS but **the ESCO API changed: `offset` is now a PAGE index (offset=1 is the second page of 100), so the script's `off += 100` loop only listed 100 occupations. Fix the loop (`off += 1`), run `node scripts/esco-fetch.mjs <dir>` (~3,000 requests, ~10 min), add `'cs'` to LANGS in `scripts/build-occupations.mjs`, regenerate `occupation_labels.g.dart`, re-run `flutter test` + `scripts/search-benchmark.mjs`.
3. Optionally store the ISCO group of each Czech vacancy (`profeseCzIsco` `CzIsco/71140` -> ISCO-08 `7114`); NormalizedJob has no isco field today.
4. Other candidates still PENDING (see SOURCES_12_0.md): Dutch "Vacatures Overheid" CC0 (API host answered 503 today, retry), Himalayas (draft request in this file), Greenhouse/Lever/Ashby (no licence), Edmonton/Calgary (~97), Île-de-France/Tours (tens).
5. Update `docs/ORBIJOB_MASTER_CHECKLIST.md` (row 5: sources, row 6 coverage numbers) and `docs/SOURCES_6_0.md` with the new source after it is published; README source lists (EN/PT/ES).
6. Re-run full `flutter test`, `flutter analyze`, Worker tests and check CI of `cf89d26` and later commits.

## Environment notes for the next session
Work happens in `C:\Users\lucas\orbijob` (clean main; worktree `orbijob-wt7` is idle and can be removed with `git worktree remove ../orbijob-wt7`). The bash tool strips single backslashes from heredocs/inline Python: build regexes with `chr(92)` or the Write tool. Do not run `taskkill /IM node.exe` (it kills every node process of the machine; I did it once by mistake at ~05:40 UTC and it may have stopped other sessions' node processes).
