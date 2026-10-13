# OrbiJob 6.0 — Global coverage expansion: progress

Started 2026-10-13 (night). Direct to `main`, small commits, CI checked after each push. No APK/AAB/IPA, no device validation in this phase.
Rule kept from earlier phases: a source is stored only with evidence of its terms; a country is stored only when the source states it.

## P0 — audit of the starting state (2026-10-13 22:10 UTC)

* Repository: `main` = `origin/main` = `e4d29c7`, clean (only untracked `.idea/` and `_aplicar/` operator folders). CI green on the last push.
* Scheduled runs of the last hours all succeeded (`Sources discover`, `Sources revalidate`, `Jobicy watchdog`).
* Supabase project confirmed as `rpmlfxwebnlxnwadyvle` (`supabase/.temp/project-ref`); `coverage.sql` run read-only.

Visible catalogue (open, published source, verified in the last 72 h): **6,994 jobs**

| Source | Visible | Country unknown |
|---|---:|---:|
| jobtech (SE) | 2,363 | 11 |
| arbeitnow (DE/EU) | 2,100 | 1,885 (1,819 with a bare city) |
| twjobs (TW) | 1,090 | 0 |
| jobicy (remote) | 988 | 277 (all remote, eligibility kept in `geo_restrictions`) |
| jobsconz (NZ) | 332 | 0 |
| remoteok | 103 | 96 (remote) |
| remotive | 18 | 17 (remote) |

Other measures: 609 short descriptions, 126 without any place, 4 cross-source duplicate fingerprints, 0 without company/date.
Countries: SE 2,353 · TW 1,090 · US 434 · NZ 335 · DE 94 · GB 85 · FR 70 · CA 31 · AU 30 · CH 37 · PH 20 · MX 13 · BR 11 · PT 11 · AR 7 · ES 9 · rest ≤ 10. **Unknown 2,286.**
Latin America in total: BR 11 + MX 13 + AR 7 + CR 3 (+ a handful) ≈ 35 jobs.

Evidence kept: `docs/evidence/coverage-2026-10-13-6-0-start.csv`.

## P0 — location recovery (evidence only)

Rule: a country is stored only when the source states it (never from language, currency, domain or company seat). A job restricted to places keeps that
restriction separately in `geo_restrictions`.

| Source | Before | After | How (all reversible; undo files in `_aplicar/`) |
|---|---:|---:|---|
| Arbeitnow (visible, no country) | 1,885 | **623** | the location **is** a country name ("Germany", "United Kingdom"), ends with one ("München, Bayern, Germany"), or its first part is one of ~150 large cities that no other country shares (Berlin, London, Paris, Zürich …); a name two countries share (Birmingham, Manchester, Cambridge, Dublin, Saint-Denis, Altendorf) stays unknown; the listing's regional site (.co.uk/.fr/.ch/.nl) must agree. 1,262 stored jobs backfilled (DE 746, GB 214, FR 123, CH 97, NL 82). Consistency check against the 1,000+ listings that state a country: London 39/39 GB, Paris 25/25 FR, Berlin 20/20 DE, Munich 15/15 DE, no contradiction |
| Arbeitnow, a list of countries | — | 2 jobs | "United States, Canada, Spain, Czech Republic" is kept as eligibility (`geo_restrictions`), never as one country |
| Platsbanken (jobtech) | 22 | **1** | the ad's own `workplace_address.country` (Swedish name) is mapped from a table (Malta, Norge, Spanien, Grekland, Cypern, Bulgarien, Danmark, Schweiz, Frankrike …); 21 stored jobs re-read from `/ad/{id}` and backfilled |
| Jobicy / Remote OK / Remotive | 277 / 96 / 17 | unchanged | all remote; the source gives eligibility lists, kept in `geo_restrictions` (a remote job with no stated country is not a failure) |
| New sources | — | by design | NYC (US), Teaching Vacancies (GB) always state it; Get on Board states it for on-site/hybrid, remote ones keep none |

Unknown country across the visible catalogue: **2,286 of 6,994 (33 %) → 1,013 of 7,561 (13 %)** measured at 23:00 UTC (the 1,013 are 623 Arbeitnow in places two countries share or without a place, 276 + 96 + 17 remote jobs whose eligibility is kept in `geo_restrictions`, 1 Platsbanken). Visible total grew to 7,561 on its own (Platsbanken 2,363 → 2,963 by the scheduled passes).

## P0/P1 — new sources (all stored, none shown in the app until the owner publishes)

| Source | Region | Class | Stored | Evidence |
|---|---|---|---:|---|
| Teaching Vacancies | England | PERSIST (OGL v3.0 declared in the API terms) | 700 → up to 2,000 | `docs/SOURCES_6_0.md` §1.1 |
| NYC Jobs | New York City | PERSIST (NYC Open Data Law; External postings only) | 800 → up to 1,339 | §1.2 |
| Get on Board | Latin America (tech) | PERSIST conditional (public API; no explicit storage licence: owner's decision) | 600 → up to 956 | §1.3 |
| Karriere.NRW | Germany (NRW public sector, incl. apprenticeships) | PERSIST (dl-by-de/2.0) | 931 | §1.4 |
| Groupe BPCE | France and abroad (banking/insurance) | PERSIST (Licence Ouverte 2.0, producer invites republication) | 1,000 → up to 1,750 | §1.5 |
| Le Forem | Belgium (Wallonia service, mostly agencies) | PERSIST conditional (CC BY-SA 4.0 ShareAlike: owner's decision; facts only, no description in the dataset) | 1,000 → up to 2,000 | §1.6 |

Rejected with evidence: Landing.jobs (robots.txt), Trampos.co (terms §2.5), MyCareersFuture (terms: no reproduction), Torre (commercial API, robots), Bundesagentur (403),
Open Jobs CC0 (head still 2026-10-05); candidates for later: Latvia NVA (CC0, no employer name), Calgary (61 rows). Full table: `docs/SOURCES_6_0.md` §2.

## P1/P2 — quality and monitoring

* Short descriptions: the measure was unfair to Chinese (200 characters ≈ a paragraph): CJK is now judged at 60. **609 → 30**; the real short ones are 11 Platsbanken, 7 Arbeitnow, 3 Teaching Vacancies.
* Listings older than 60 days (518): all still listed by their source (a deadline such as Taiwan's `STOP_DATE`, a status endpoint, or the feed); they keep their real date and are not closed for age alone.
* `coverage.sql` now reports stored vs published by source, the last pass of each source, visible jobs without a country by source and old listings by source.
* `scripts/search-benchmark-stored.mjs` counts the 36 benchmark queries over everything stored (published and pending) and writes `docs/evidence/search-coverage-2026-10-13-6-0.md`.
* App: display names for the new sources (Jobs.co.nz had none).
* Database: 143 MB of 500 MB after the imports; schedules and leases unchanged.

## Commits (all on `main`)

`9e0f6e6` Get on Board · `ad8661c` Teaching Vacancies · `79e40c7` ceiling 2,000 · `9ae6a44` Arbeitnow places · `56ab5a9` NYC Jobs · `33998a6` source contracts + coverage diagnostic ·
`2436460` display names + coverage projection · `c746d0b` Platsbanken countries abroad · `383e232` Arbeitnow eligibility lists.

## Owner-side (see the end of the final report)

1. Run `_aplicar/2026-10-13_6_0_fontes/` in order (01 Teaching Vacancies, 02 NYC Jobs, 03 Get on Board — read its note, 04 expiry for the new sources).
2. Optional: ask Get on Board for written confirmation (draft in `docs/SOURCES_6_0.md`).
3. Unchanged from earlier phases: NAV registration e-mail, USAJOBS/Jooble keys, a real push seen on a phone.

## Later in the night (13/10, after 23:00 UTC)

* **Three more sources imported (stored, unpublished; Le Forem added at 23:20 UTC):** Karriere.NRW (Germany, `dl-by-de/2.0`, 931 stored) and Groupe BPCE (France and abroad, Licence Ouverte 2.0 with the producer's explicit invitation to republish, 1,000 stored). Evidence in `docs/SOURCES_6_0.md` §1.4–1.5.
* **Discovery trail** (all in `docs/SOURCES_6_0.md` §2): open-data portals searched for job-posting datasets (data.gouv.fr, Opendatasoft federation, GovData, CKAN of UK/AU/CA/HK/UY/CL, Socrata catalogue). Found and kept as candidates: Le Forem (Belgium, CC BY-SA, no descriptions), Infrabel (no link), emploi.nc (no employer name), ECYL (garbled columns), France Travail slices (per-publisher schemas). Rejected with evidence: Landing.jobs, Trampos.co, MyCareersFuture, Torre.
* **App fix found while reading real data:** hourly salaries with cents (£13.45/h, $29.21–42.79/h) were rounded to whole numbers (£13); they now keep two decimals, whole amounts stay whole (`job_format.dart`, test in `data_quality_test.dart`).
* **Performance of the larger catalogue** (≈ 12,000 stored rows): an app-style search over all stored rows plans in 4 ms and executes in 36 ms (title/city `ilike`, join to the source gate, ordered by date); the full-text count executes in 0.4 ms. No index change was needed (the trigram, GIN and source indexes carry it). Database size 143 MB → see `coverage.sql` for the current figure.
* **Operational health** (read from the database and GitHub at 23:15 UTC): 13 pg_cron jobs, every run of the last 24 h succeeded (`jobsconz-revalidate-*` 8/8 and 24/24, `jobtech-revalidate-*` 4/4 and 16/16 — the carried-over "first scheduled runs" item is confirmed); scheduled GitHub runs: `sources-discover` 52 ok / 4 failed (the 4 failures are Arbeitnow `catalogue_full` of 12–13/10 before the ceiling was raised, plus 2 manual tests), `sources-revalidate` 6/6, `jobicy-revalidate` 11/11, `jobicy-discover` failures are all old `push`-triggered lint runs; CI 53 ok.
* Tests: Worker **794 passing** (745 at the start of 6.0; new: Get on Board 9, Teaching Vacancies 8, NYC Jobs 10, Karriere.NRW 9, BPCE 10, Arbeitnow places/eligibility, Platsbanken countries; 38 opt-in live tests skipped), Flutter **901 passing** (unchanged count, one test extended), `flutter analyze` clean, SQL/publish-guard tests unchanged.

## Search precision found with the new German data (13/10, 23:35 UTC)

Real Karriere.NRW titles exposed a flaw of the 5.0 hand group for nurses: the bare stem `pflege` matched *Rechtspfleger* (court clerk), *Tierpfleger* (zookeeper),
*Denkmalpflege*, *Grünpflege* — "nurse" showed 70 Karriere.NRW results of which 4 were nurses. The group now uses nursing-specific stems (`krankenpfleg`, `krankenschwester`,
`pflegefach`, `pflegekraft`, `altenpfleg`, `pflegehelf`, `pflegeassist`); the "health" area pattern no longer counts `pflege` alone either. Result over the stored catalogue:
"nurse" Karriere.NRW 70 → 4, nothing else changed (`docs/evidence/search-coverage-2026-10-13-6-0.md`). Saved searches keep the alternatives they were saved with
(they travel inside the stored query, so SQL parity is untouched); the PostgREST golden file was regenerated and the `catalog-postgrest` CI job re-validates it.
Known and left as it was (5.0 design, documented there): "chef" is a manager in French and Swedish and a cook in English; the query term itself matches in the title.
