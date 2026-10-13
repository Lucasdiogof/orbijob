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
