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
