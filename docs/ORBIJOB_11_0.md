# OrbiJob 11.0 — consolidation, professional relevance, stability (2026-10-14)

## P0 — consolidating the two parallel sessions
* `orbijob-wt7` (phases 7.0–10.0) and the shared tree (`orbijob-otp`, password recovery by code) had **mixed uncommitted edits in the same files** (AuthCubit, AuthRepository, ARBs, fakes, tests). Backup made first (`C:\Users\lucas\orbijob-backups\otp-tree-2026-10-14`: full patch + the untracked files). The recovery-code work was separated with a 3-way merge (base `0e5edd0`, ours = main, theirs = the shared tree) so that **only that session's own changes** were committed: `7a9aaa7` ("password recovery with a 6-digit code…", CI green). Every conflict was "my older copy of the same edit", resolved by keeping main.
* The shared tree was cleaned with two `git stash` entries (not discarded; backup + stash list kept) and fast-forwarded to main. No reset, clean or force push.
* **Owner action still required for recovery by code:** the Supabase e-mail template "Reset Password" must contain `{{ .Token }}` (see `docs/auth/RECOVERY_CODE.md`). It cannot be read or changed from here (no dashboard/API token); until it is done, the e-mail still carries the old link and the typed-code screen has nothing to type.

## P0 — professional relevance of recommendations
Problem: a physiotherapist was offered doctors' jobs labelled "same professional field" (only the word "health" in common).
Solution (`app/lib/features/recommendations/domain/profession_groups.dart`, `recommender.dart`): the ESCO table already shipped for the search (31,000+ names in 7 languages, each tied to an ISCO-08 unit group) plus a short curated list for the generic words ESCO drops ("nurse", "doctor", "teacher", "driver", "teaching assistant", "software engineer", "flutter developer"). Five levels:
| Level | Meaning | Reason shown | Points |
|---|---|---|---|
| same profession | the title contains the profession (or its close form / its name in another language) | "The title mentions your profession" / "Close to…" / "Same profession, another language" | 50 / 42 / 38 |
| same occupation group | the title names another occupation of the same ISCO unit group ("Financial Controller" for "Accountant", "Mobile Engineer" for "Flutter Developer") | "Same occupation group as your profession" | 34 |
| related profession | a small cluster of neighbours (software, web and application developers) | "Related profession, not the same" | 24 |
| general area only | only "health"/"engineering"/… in common | "Same general area only", shown as an extra, **never alone** | 6, and the listing is dropped unless something real also agrees |
| incompatible | the title names a different occupation in which the words are only a modifier ("Engenheiro Eletricista" for an electrician, "Auxiliar de enfermagem"/"Nursing assistant"/"Pflegehelfer" for a nurse, "Teaching assistant" for a teacher) | none: the listing is not recommended | — |
Guards: a title is read as *mentions* (longest names first, a word belongs to one mention), so "Physiotherapist / Occupational Therapist" still counts as naming the physiotherapist; a single word that appears in names of 12 or more occupation groups ("assistant", "manager", "charge", "agent") is a role word, not a profession, and is never read alone (an early version offered "Engineer-In-Charge" to a teacher: found on real data and fixed); qualifiers such as "pelvic" are not ignored (a general physiotherapist listing for a pelvic specialist is "same occupation group", not "same profession").
Tests: `app/test/recommendations/relevance_test.dart` (physiotherapist vs doctors, nurse vs caregiver/assistants, civil vs software engineer, Flutter vs software engineer, electrician vs electrical engineer, teacher vs teaching assistant, general area alone, the group table) + the adapted `recommender_test.dart`. Real-data check on 1,593 live titles: physio 1 (no doctors), nurse 163 (no assistants), electrician 41 (French "électricien" now recognised as the same group), teacher 212 (no assistants), Flutter 121 (3 close + 91 related + 20 same group + skills).
Known limits: ISCO groups of titles ESCO and the curated list do not know are unknown (never a conflict, never a match); "related" is deliberately limited to the software cluster; nothing says a registration, visa or certificate counts in another country.

## P1 — search quality
No change to the search itself this phase. Dart/SQL parity, saved-search/alert parity and the ESCO synonyms stay covered by the existing 940+ tests; benchmark re-run on the live catalogue: `docs/evidence/search-benchmark-2026-10-14-11-0.txt` (only natural data churn versus the earlier run the same morning: physiotherapist 220→216, chef 745→743, vendedor 438→442; nothing tuned).

## P1 — operational health
* `scripts/supabase/diagnostics/ops-health.sql` (database login): 33 rows OK on 2026-10-14 (all pg_cron jobs, freshness, push backlog, 178 MB of 500 MB, 13,586 visible listings).
* **New, no new secret:** `.github/workflows/ops-health.yml` + `worker/scripts/ops-health-remote.mjs` run daily at 06:33 UTC with the Worker's *existing* read-only key (`ORBIJOB_SYNC_WORKER_KEY`, the same one the revalidation workflow uses): freshness per published source, failed passes, passes that hit the ceiling, visible listings. An ALERT makes the run fail, so GitHub e-mails the owner (the free plan has no pager). First run in Actions: success. 6 unit tests incl. "the workflow is read-only".
* Arbeitnow 3,200 / Jobtech 4,200 (6.x→10.0 raise): see the section at the end.
* Duplicates: 4 cross-source fingerprints (unchanged); old listings: see `coverage.sql`.

## P1 — UX and accessibility
The accessibility nets (contrast, tap targets ≥ 44 px, labels) and the 200 %-text layout nets (320×640, EN/PT/ES) now also cover **the recovery e-mail screen, the recovery code screen and the delete-account dialog**. Found while writing them (all in the tests, not in the app): at 200 % text on a small phone the recovery form sits below the fold of a lazy list. No app defect was demonstrated. Account deletion confirmation lives in the dialog (see `ORBIJOB_FINALIZATION_PROGRESS.md`).

## P2 — site test
`lucksrei/tests/i18n.test.js` still failed ("34 apps vs 35"): the count is now read from the dataset (`725c20b`); all 7 site tests pass.
