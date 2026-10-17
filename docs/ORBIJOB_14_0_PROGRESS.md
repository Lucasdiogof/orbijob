# OrbiJob 14.0 — progress checkpoint (started 2026-10-17)

Quality, international coverage and stability. Source evidence: [SOURCES_14_0.md](SOURCES_14_0.md). Whole-product status: [ORBIJOB_MASTER_CHECKLIST.md](ORBIJOB_MASTER_CHECKLIST.md). Previous phase: [ORBIJOB_13_0_PROGRESS.md](ORBIJOB_13_0_PROGRESS.md).

## Initial state (verified)
* `main` = `origin/main` at `452a382`, working tree clean (untracked `.idea/` and `_aplicar/` are local on purpose); worktrees `orbijob` and `orbijob-wt7` (idle) and the two `otp-session-*` stashes untouched.
* CI green on `452a382`, `1fe92bb`, `b7dde7e`; Worker 954 tests (+39 skipped live), `tsc` clean.
* Production (publishable key): 26,405 visible listings in 19 sources; `public-privacy-audit.ts`: 0 would still be masked. Supabase project `rpmlfxwebnlxnwadyvle` (linked, confirmed before every write).

## P0 — Flutter consolidation (first, as asked)
`flutter analyze`: no issues. `flutter test`: **995 passed, 94 skipped** before any 14.0 change (1,004 after the search tests below). The skipped ones are the golden/device-dependent and live-network tests (unchanged). `[tel.]` and `[e-mail]` are plain text in descriptions and need no
translation logic (checked in the previous round); navigation, filters and result tests are part of the suite.

## Steps
| # | Step | State | Commit |
|---|---|---|---|
| A | Recovery: git, CI, production counts, Flutter suite | done | — |
| B | Source research on new hypotheses (Socrata both regions, data.gouv.fr, data.europa.eu, national CKANs, Colombia, Portugal, licences read) | done, [SOURCES_14_0.md](SOURCES_14_0.md) | docs |
| C | City of Calgary connector (OGL City of Calgary v2.1): fixture from the real dataset, tests, schedule (daily 09:40 UTC), source row, preview (56 read, 55 would import), real import (55 stored, unpublished) | done, **awaiting the owner's publication** | 0c88c62 |
| D | Search: heavy goods drivers, mechanics, gardeners, plumbers, cashiers, midwives, early-years educators, cleaning; accent-less typing; second benchmark of 70 queries | done | 7d9ecda |
| E | Catalogue, RLS and capacity audit (read-only SQL saved in `docs/evidence`) | done, below | docs |
| F | Docs | done | docs |

## Sources
One new source with a clear licence (Calgary, 55 listings, the first Canadian listings in the catalogue) and a documented list of what was read and why it was NOT integrated (Edmonton's downstream-binding and indemnity conditions, Victoria's closed API, listings without a
link such as Île-de-France, Infrabel, Andalucía, tiny feeds such as Tours 33 and Vantaa 9). The long tail of open data is municipal and small; nothing was forced. Publication file for the owner: `_aplicar/2026-10-17_14_0_fontes/01_publicar_calgary.sql` (guard rehearsed
in a rolled-back transaction, passes; `can_redistribute` still false). After publication the catalogue grows from 26,410 to 26,465 visible.

## Search (measured on the public catalogue before and after)
A second benchmark, `scripts/search-benchmark.queries.14.json` (70 queries in 8 languages, alternatives in `search-benchmark.alternatives.14.json`), found real gaps:
* **Truck driver**: "truck driver" returned 3, "lkw-fahrer" 1, "lastbilschaufför" 521 (every Swedish "chaufför", buses included), "camionero" 1 and "camionneur" 0. A group of whole names (truck driver, Lkw-Fahrer, camionero, camionneur, lastbilschaufför, motorista de caminhão, conducteur routier…)
  now makes all of them return the same 19 truck-driver listings; the general driver group is unchanged ("driver" still finds every driver) and is subsumed only when the person typed the longer name.
* **Mechanic, gardener, plumber, cashier, midwife, early-years educator, cleaning**: no equivalents between languages (e.g. "mecánico" 100, "mechanic" 37, "mécanicien" 142, none finding the others; "klempner" 0; "matrona" 0; "kindergarten teacher" 0 while "erzieher" found 38). Groups added; "mecánico/mécanicien/Mechaniker/mekaniker" now
  return 322 mechanics in all languages. The English stem "mechanic" is deliberately never offered as another name: it sits inside "mechanical" (15 of 325 matches were Mechanical Engineers), so the English side is "auto/car/diesel mechanic" and the Czech plural "mechanici"; typing "mechanic" still opens the group.
* **Typing without accents**: "medico" returned 7 and "médico" 120; the groups are now compared without accents (the alternatives keep theirs, since titles do): "medico" 121. "ingénieur" now behaves like "ingenieur" (any engineer, 1,666), consistent with the existing "ingeniero".
* Of the 74 queries of the older set only 5 changed (truck driver, medico, ingénieur, limpiador 317→333, mecánico 100→322); the rest are byte-identical. Dart and SQL alert parity untouched: the golden tests pass.
* Not changed on purpose: "pelvic health physiotherapist" has no listing (0 specific results, the honest answer), "Flutter Developer" finds 1.
Tests: `test/search/trades_alternatives_test.dart` (9 cases), whole suite 1,004 passed, `flutter analyze` clean.

## Catalogue quality (visible, 72 h, `docs/evidence/audit_14_0.sql`)
Per source: 0 bad links in the 1,000-row sample and 0 duplicated URLs; no listing without title; without country: arbeitnow 659, getonboard 296, jobicy 358, remoteok 103 (remote listings that state none — not guessed); without date: bpce 1,568 (by design); older than 60 days: feinaactiva 854
(the portal keeps offers open for months; the 90-day cap applies), karrierenrw 275, getonboard 244, twjobs 226, jobtech 19; short descriptions (< 80 characters): mpsvcz 277, twjobs 170; no employer name: ecyl 850, lanbide 600, sefmurcia 243 (the sources do not name it, said in their attribution), feinaactiva 7;
salary without a unit: 0. Nothing was filled in.

## Security and infrastructure
* RLS audit (`docs/evidence/rls_audit_14_0.sql`): every table of `public` and `ops` has RLS on; the anonymous role can `select` only `jobs`, `job_sources`, `job_clusters` (one policy each) and has no insert/update/delete anywhere; applications, credentials, profiles, notifications, saved searches, push devices,
  resumes and the rest are not readable anonymously.
* Public visibility check (`worker/scripts/app-visibility-check.mjs`, extended with `calgary`): 26,410 visible, pagination without overlap, 0 bad links, attribution with link on all sampled rows, `calgary` correctly invisible until published.
* pg_cron: 14 jobs active. Database **284 MB of 500 MB** (27,965 rows; was 265 MB at the end of 13.0 — feinaactiva and mpsvcz filled up). The 20 ceilings add up to 38,100 listings; at ≈ 9 KB a row that is ≈ 345 MB if every source filled up, still inside the free limit but the margin is now ≈ 150 MB, so the next
  ceiling raise should be decided with this number. No ceiling was raised.
* CI green on every commit of the phase.

## Tests
Worker 961 passed (+39 skipped live), `tsc` clean; Flutter 1,004 passed (+94 skipped), `flutter analyze` clean.

## Pending outside this environment
Owner: publish Calgary (`_aplicar/2026-10-17_14_0_fontes/`); request the USAJOBS key (`docs/USAJOBS_API_REQUEST.md`); decide on employer permission requests (`docs/EMPLOYER_FEED_PERMISSION.md`) and on asking Edmonton (opendata@edmonton.ca) whether showing listings is "distribution" under its terms;
unchanged: Get on Board permission, NAV Norway registration e-mail, Jooble/Korea Work24 keys, real push on a phone, device validation, store work (out of scope here).

## Next concrete step
A bundle connector for small municipal feeds of the same shape (OpenDataSoft with `jobaffinity` fields: Tours 33; UK councils under OGL) only when at least three feeds of one shape exist; otherwise search quality from the benchmark (health and trades in Portuguese) and the 60-day-old listings of feinaactiva.

## Round 2 — Brazilian Portuguese trades (2026-10-17, commit 2c8bc52)
A third benchmark, `scripts/search-benchmark.queries.pt.json` (38 queries), measured on the public catalogue: 13 of them found nothing or almost nothing in 5.0 (açougueiro 0, balconista 0, auxiliar de cozinha 0, entregador 0, costureira 0, cuidador de idosos 0, operador de máquinas 0,
auxiliar de produção 0, gerente de projetos 0, técnico de enfermagem 2, técnico de manutenção 1). Groups of whole names added for nursing assistants (nursing assistant, Pflegehelfer, undersköterska, aide-soignant…, so "auxiliar de enfermagem" is no longer "any nurse"), butchers, kitchen assistants, delivery
drivers and couriers, seamstresses, elderly care, machine and production operators, shop assistants, project managers and maintenance technicians. Found by the same measure: a plural of a word of the name ("projetos") was treated as a required qualifier and returned 0; fixed. After: açougueiro 34, balconista 185,
auxiliar de cozinha 45, entregador 50, costureira 8, cuidador de idosos 92, operador de máquinas 14, auxiliar de produção 25, técnico de enfermagem 104, técnico de manutenção 100. Of the earlier 74 + 70 queries only "dependiente" (35→185), "project manager", "projektleiter" and "jefe de proyecto" changed.
Not changed on purpose: "atendente" and "segurança" (ambiguous words with no safe cross-language name). Flutter 1,008 tests passed, analyze clean.
