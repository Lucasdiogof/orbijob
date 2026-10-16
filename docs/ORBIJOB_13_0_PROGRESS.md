# OrbiJob 13.0 — progress checkpoint (started 2026-10-16)

Direct employer feeds and global coverage. Evidence of every source: [SOURCES_13_0.md](SOURCES_13_0.md). Whole-product status: [ORBIJOB_MASTER_CHECKLIST.md](ORBIJOB_MASTER_CHECKLIST.md).

## Initial state (verified)
* `main` = `origin/main` at `1d3183c` (12.0), CI green; worktrees `C:/Users/lucas/orbijob` and `C:/Users/lucas/orbijob-wt7` (idle); 2 stashes (`otp-session-*`, superseded) and the backups in `C:\Users\lucas\orbijob-backups` preserved, not touched.
* The working tree was NOT clean: an earlier session (14/10, after the 12.0 docs) had left an **unfinished, uncommitted connector for Choisir le Service Public** (`csp`: connector, CSV streaming, fixture, tests, `csp-revalidate.yml`, wiring) and a half-written test (`workflows.test.ts` with newlines inside two regex literals, so the whole Worker suite did not compile). It was reviewed, repaired, tested and finished (below), not discarded.
* Production: 14 published sources, 22,525 visible listings (was 17,320 on 14/10), database 256 MB of 500 MB, 13 pg_cron jobs all succeeding, Supabase project `rpmlfxwebnlxnwadyvle` linked.

## Steps
| # | Step | State | Commit |
|---|---|---|---|
| A | Recovery: state, WIP found, production counts | done | — |
| B | Choisir le Service Public (FR, Licence Ouverte 2.0): finished, preview, import (43), `csp-revalidate` run once for real (43 confirmed) | done, **awaiting the owner's publication** | 756f071 |
| C | Research: public employment services as open data (data.europa.eu / CKAN / Socrata catalogues swept, ATS terms read, 25+ candidates) | done, [SOURCES_13_0.md](SOURCES_13_0.md) | docs |
| D | SEF Murcia (ES), Feina Activa / SOC (ES-CT), ECYL (ES-CL), Lanbide (ES-PV): connectors, fixtures from real feeds, tests, schedules, preview + import | done, **awaiting publication** | 1770811 (SEF Murcia), b10ab84 (Feina Activa), 14a8fed (ECYL), da7a772 (Lanbide) |
| E | Reusable shell built from the four concrete cases: `snapshot.ts` (one GET, normalize, refusal reasons, presence-confirms-open) + `spain.ts` (phones, towns, dates); the four connectors rewritten on it with their tests unchanged | done | 2a730cc |
| F | Publish guard: an offer without an employer name is accepted only for a source whose attribution says so; rehearsed for the five sources inside a rolled-back transaction (all pass); owner pack `_aplicar/2026-10-16_13_0_fontes/` (not versioned) | done | c6107d7 |
| G | Search: Spanish and Catalan professions (teacher, nurse, waiting staff, cook), office work and cleaning groups; benchmark extended from 36 to 73 queries (8 languages) and run over the stored catalogue | done | 20bad6a |
| H | Quality and personal data: sole traders' names not republished, phones/e-mails masked, SEF registration section dropped, links sampled (all 200), Latin-1 decoding, host fix for ECYL links | done | in the connectors |
| I | Operations: coverage, cron, workflows, ceilings (below) | measured, no change needed | — |
| J | Docs: checklist, finalization progress, sources, permission drafts | done | docs |

## What changed in numbers (stored, 2026-10-16)
| | before | after publication of the five |
|---|---|---|
| Visible listings | 22,525 | 25,261 (+2,736 stored: csp 43, sefmurcia 243, feinaactiva 1,000, ecyl 850, lanbide 600) |
| Spain | 22 | 2,679 |
| France | 1,793 | 1,836 (the schedule keeps adding csp, ≈ 170 a day up to ≈ 2,000) |
| Professions that were close to empty in Spanish | `profesor` 0, `cambrer` 0, `limpiador` 0, `auxiliar administrativo` 0, `mecánico` 2 | 101, 49, 74, 55 (+ `administrative assistant` finds them: 152), 86 |

Search benchmark (73 queries, stored catalogue, by source): `docs/evidence/search-coverage-2026-10-16.md`. Findings that changed the code: Spanish `profesor` found no `teacher`/`Lehrer` (the group only had `professor`), Catalan `infermer`/`cambrer`/`cuiner`
were not in any group, "administrative assistant" and "auxiliar administrativo" were not equivalent, "limpiador" had no English side. Not changed: a qualifier that needs translating is still not translated (limit documented in 5.0).

## Findings
* **Spain's regional employment services were dismissed in 12.0 as "only statistics"** because the search stopped at the national portal. The regional portals publish live offers under CC BY 4.0 or a legal notice that permits reuse; they are the productive vein of this phase.
* **The offers do not name the employer** in three of the four Spanish feeds. The catalogue handled it already (empty company, the app hides the line, the fingerprint falls back to the id); only the publish guard assumed a company. It now accepts an empty company for a source whose stored attribution says the employer is not named.
* ECYL links point to `gestorcontenidos.jcyl.es`, a host the public cannot reach, for 82 % of the offers; the same path on `empleo.jcyl.es` opens the offer (checked on a real page). Only that exact shape is accepted.
* Lanbide's response claims UTF-8 and is ISO-8859-1; decoded as UTF-8 when valid, else ISO-8859-1. One preview failed with a network error and passed on the next try (the host is slow at times).
* The Feina Activa XML says nothing about the unit of its salary range; the range is therefore not mapped (part-time amounts are not comparable). The unit is the only thing missing for a real salary field there.
* `Sources discover` shows red runs every cycle for six sources (arbeitnow, jobtech, teachingvacancies, mpsvcz, forem, getonboard): that is the designed **catalogue-ceiling alert (exit 7)**, not a failure of a pass (e.g. teachingvacancies: 6,742 read, 3,013 confirmed, 3,022 refused for the ceiling). 21 red runs in 24 h: a real failure would be hard to see. Left as is because the publish guard and the ops-health use the same `partial/catalogue_full` status; an option for the owner is a deliberate ceiling increase (database 263 MB of 500 MB) or an "at ceiling by design" flag that turns the run green with a notice.
* Production `open_not_verified_72h` = 944 (arbeitnow 775, twjobs 163, remoteok 4, remotive 2): jobs the source no longer lists; the app hides them and `sources-expire-unseen` turns them `unknown` after 7 days.

## Operations (measured 2026-10-16)
13 pg_cron jobs active and succeeding; `Ops health` green daily; database 263 MB (+7 MB for 2,736 rows); `coverage.sql` saved as `docs/evidence/coverage-2026-10-16.csv`; GitHub schedules for the five new sources fit the minute constraints (≥ 13 min from any other run, forbidden minutes avoided).

## Pending outside this environment
Owner: publish the five sources (pack + `LEIA-ME.md`); request the USAJOBS key (`docs/USAJOBS_API_REQUEST.md`); decide on employer permission requests (`docs/EMPLOYER_FEED_PERMISSION.md`);
unchanged: Get on Board permission, NAV Norway registration e-mail, Jooble/Korea Work24 keys, real push on a phone, device validation, store work (out of scope here).
