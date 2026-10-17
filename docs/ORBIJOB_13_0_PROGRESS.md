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
| B | Choisir le Service Public (FR, Licence Ouverte 2.0): finished, preview, import (43), `csp-revalidate` run once for real (43 confirmed) | done, **published by the owner 16/10** | 756f071 |
| C | Research: public employment services as open data (data.europa.eu / CKAN / Socrata catalogues swept, ATS terms read, 25+ candidates) | done, [SOURCES_13_0.md](SOURCES_13_0.md) | docs |
| D | SEF Murcia (ES), Feina Activa / SOC (ES-CT), ECYL (ES-CL), Lanbide (ES-PV): connectors, fixtures from real feeds, tests, schedules, preview + import | done, **published by the owner 16/10** | 1770811 (SEF Murcia), b10ab84 (Feina Activa), 14a8fed (ECYL), da7a772 (Lanbide) |
| E | Reusable shell built from the four concrete cases: `snapshot.ts` (one GET, normalize, refusal reasons, presence-confirms-open) + `spain.ts` (phones, towns, dates); the four connectors rewritten on it with their tests unchanged | done | 2a730cc |
| F | Publish guard: an offer without an employer name is accepted only for a source whose attribution says so; rehearsed for the five sources inside a rolled-back transaction (all pass); owner pack `_aplicar/2026-10-16_13_0_fontes/` (not versioned) | done | c6107d7 |
| G | Search: Spanish and Catalan professions (teacher, nurse, waiting staff, cook), office work and cleaning groups; benchmark extended from 36 to 73 queries (8 languages) and run over the stored catalogue | done | 20bad6a |
| H | Quality and personal data: sole traders' names not republished, phones/e-mails masked, SEF registration section dropped, links sampled (all 200), Latin-1 decoding, host fix for ECYL links | done | in the connectors |
| I | Operations: coverage, cron, workflows, ceilings (below) | measured, no change needed | — |
| J | Docs: checklist, finalization progress, sources, permission drafts | done | docs |
| K | Closing round: the five sources validated in production through the public key, capacity state, Czech feed fix, ECYL fixes, licence page, public benchmark | done | ab65c1c … ab1fe2a (below) |

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
* `Sources discover` showed red runs every cycle for six sources (arbeitnow, jobtech, teachingvacancies, mpsvcz, forem, getonboard): the designed catalogue-ceiling alert (exit 7), not a failure of a pass. 21 red runs in 24 h hid real failures. **Resolved in the closing round (below): AT_CAPACITY state.**
* Production `open_not_verified_72h` = 944 (arbeitnow 775, twjobs 163, remoteok 4, remotive 2): jobs the source no longer lists; the app hides them and `sources-expire-unseen` turns them `unknown` after 7 days.

## Operations (measured 2026-10-16)
13 pg_cron jobs active and succeeding; `Ops health` green daily; database 263 MB (+7 MB for 2,736 rows); `coverage.sql` saved as `docs/evidence/coverage-2026-10-16.csv`; GitHub schedules for the five new sources fit the minute constraints (≥ 13 min from any other run, forbidden minutes avoided).

## Closing round (2026-10-16, after the owner published the five sources)
The owner ran the five publication files (not run again here). Everything below was measured through the **publishable key** (what the app reads) unless it says "stored".

**Public catalogue.** 25,336–25,362 visible listings (the forecast was 25,261; sources keep moving): csp 43, sefmurcia 243, feinaactiva 1,000, ecyl 850, lanbide 600 — every one
readable anonymously, with its detail, paging without overlap, `original_url` = `apply_url` on the source's own host (1,000 visible rows checked: 0 bad links), the attribution with
links shown. By country: SE 3,995 · GB 3,873 · CZ 3,502 · ES 2,682 · BE 1,999 · FR 1,863 · DE 1,819 · US 1,622 · TW 1,179 · NZ 323 · NL 314 · CL 278 · CH 138 · others < 60; 1,450 without a
country (Arbeitnow places two countries share, remote listings, ECYL offers that name none). Quality of all visible: 1,782 older than 60 days (still listed by their source; Feina Activa
822 of them: the feed keeps offers open for months), 1,578 without a publication date (BPCE by design), 470 descriptions under 80 characters, **0 duplicated URLs**.

**Fixed in this round.**
* ECYL: 3 EURES offers carried foreign telephone numbers (+45, +43) the Spanish mask did not cover; the four Spanish connectors now mask any number written with a country code
  (`maskPhones`, amounts and references untouched, tested), and the 3 stored rows were corrected (undo file kept with the owner pack). 15 EURES offers now carry the one country their
  title states ("Embryologist en Dinamarca" → DK); 21 that state none stay without a country. Role addresses (`info@…`, `job@…`) are kept on purpose, personal ones are masked.
* **Czech source (mpsvcz) broken since 2026-10-16 17:41**: the publisher removed the uncompressed `volna-mista.json` (404; only `volna-mista.json.gz` is listed). The connector reads the
  `.gz` (served with `Content-Encoding: gzip`; a body still compressed is decompressed while streaming). Live run: 3,000 vacancies in 9 s. The file's own `Last-Modified` is 14/10 23:02:
  the publisher has not refreshed it for two days — to watch.
* Visibility check: Feina Activa's attribution starts with "(SOC)", so the check reported 54 rows "without a link"; it now looks for a link anywhere (0).
* Licence page: the Czech source and the five 13.0 sources added with their real licences (Licence Ouverte 2.0; Llicència oberta d'ús d'informació – Catalunya; CC BY 4.0 for ECYL and
  Lanbide; Murcia's legal notice), each guarded by a test that also refuses "CC BY" for the two that are not.

**Planned ceiling vs real failure (AT_CAPACITY).** One classifier (`worker/scripts/run-state.mjs`) turns a discovery pass into SUCCESS, AT_CAPACITY, PARTIAL or FAILED. AT_CAPACITY only
when the pass read rows from the feed, had no HTTP error, no other error class and its before/after verification passed; the run is then green with a `CAPACITY` notice. A "full"
pass that read nothing is FAILED, one with HTTP errors PARTIAL, so a broken feed never hides behind a full catalogue. The ceiling itself is unchanged (nothing beyond it is stored),
revalidation and expiry run in their own jobs, and once listings expire the next pass imports again (tested: healthy at the ceiling, real failure at the ceiling, recovery after expiry).
`ops-health` reports the ceiling as an informational AT_CAPACITY row that never raises the overall status; a full source that stops refreshing still turns WARN/ALERT. Of the 17 red runs
listed before the change, 14 were exit 7 (ceiling), 2 the Czech 404 (real, fixed) and 1 an old Lanbide preview before its first import — exactly what the new states separate.

**Search through the public key** (`scripts/search-benchmark.mjs`, 74 queries, `cuiner` added): 20,591 results, all with the profession in the title or city; e.g. profesor/teacher/
Lehrer/enseignant 1,386 each, nurse/infermer/infirmier 507, limpiador 287, auxiliar administrativo 189 · administrative assistant 271, cambrer 115, cuiner/cook 253, electrician 107,
physiotherapist 276, Flutter Developer 1 (one Flutter title is visible). Sampled titles show no profession confusion; borderline, documented: the nurse group's stem also finds "auxiliar
de enfermería" (nursing assistant). Every query answered in < 1.2 s; the sample mode of the old 4.0 comparison times out (statement timeout) and is not used.

**Operations.** pg_cron: 14 jobs, all runs in 24 h succeeded. `csp`: one discovery (3,051 read, 80 asked, 43 confirmed), one real revalidation (43 confirmed); its schedules
(discover 02/08/14/20:34, revalidate 05/11/17/23:07 UTC) start with the next cycle. Database **265 MB of 500 MB** (jobs 240 MB for 26,786 rows, ≈ 9 KB a row with indexes); the
19 ceilings add up to 37,800 listings, ≈ 375 MB if every source were full — about 125 MB left for users, notifications and indexes. No ceiling was raised.

**Tests.** Worker 905 (+ 39 skipped live), Flutter 995 (+ 94 skipped), `flutter analyze` clean, `tsc` clean, CI green.

## Pending outside this environment
Owner: ~~publish the five sources~~ (done 16/10, verified through the public key); request the USAJOBS key (`docs/USAJOBS_API_REQUEST.md`); decide on employer permission requests (`docs/EMPLOYER_FEED_PERMISSION.md`);
unchanged: Get on Board permission, NAV Norway registration e-mail, Jooble/Korea Work24 keys, real push on a phone, device validation, store work (out of scope here).

## Personal-data guard (2026-10-16, after the 13.0 closing round)
* One guard at the storage point for every source (`src/description.ts` `protectPersonalData`, `src/phones.ts`): telephone numbers of a person (mobiles, named contacts, international, national and North-American formats) become `[tel.]`, personal e-mails `[e-mail]`; institutional lines, role addresses, dates, hours and amounts are kept. Titles, company names (22 legitimate trade names contain `@` and are untouched) and apply links are never rewritten. The app shows the markers as plain text; the original listing stays one tap away on the official page.
* Backfill over stored descriptions: `worker/scripts/backfill-personal-data.ts` (dry-run by default, idempotent, no copy of the originals kept). It was applied once (≈ 300 texts); the follow-up dry-run found 0 more. **Do not run it again without a new rule.** One phone masked earlier out of excess caution cannot be recovered from the database; the official page still shows it.
* Read-only audit through the publishable key: `worker/scripts/public-privacy-audit.ts` (counts only, never a number). Result on 2026-10-16: **26,405 visible listings in 19 sources, 0 would still be masked**. Limit: the rules cover phone and e-mail formats, not every conceivable personal datum.
* Commits: bcdceb9 (guard), 1fe92bb (backfill script), b7dde7e (audit script); CI green on b7dde7e and 1fe92bb. Worker 954 tests (+39 skipped live), `tsc` clean.
