# OrbiJob 7.0–10.0 — finalization progress (checkpoint)

Started 2026-10-13/14 in a new session. Source of truth: this file + the repository + project `rpmlfxwebnlxnwadyvle` (never touch another Supabase project).
Do NOT re-run the six 6.0 publish SQLs. No store/build/device work (out of scope).

## State (updated 2026-10-14, 7.0 complete)
- Commits on main: `bfbeefc` (backend), `e8da903` (Flutter export/delete, CI green), `c1a895a` (links), `76fca47` (docs + e2e isolation checks). Site repo `lucksrei`: `7c7a052`.
- Another session (`orbijob-otp`, password recovery by code) has UNCOMMITTED edits in the shared tree `C:\Users\lucas\orbijob` (auth_cubit, auth_page, ARBs, fakes, auth_test, recovery_code_page...).
  My work was committed from a separate git worktree `C:\Users\lucas\orbijob-wt7` (branch `wt7`, push with `git push origin HEAD:main`) so their changes were not touched or committed.
  Their tree still carries my (now committed) hunks: they should `git pull --rebase --autostash`. Use the worktree for further app work; `supabase` CLI commands must run from `C:\Users\lucas\orbijob` (linked there).

## Phase 7.0 - DONE
- 7.1/7.2 Delete account + export: Edge Functions `account-delete`/`account-export` (deployed, JWT verified), Flutter "Your data" section on Profile > Privacy. Root cause of the failing deletion test: after the user changes,
  `UserScope` rebuilds the whole navigator and a snack bar queued afterwards is never shown (verified with a probe). Fix: the dialog itself turns into the confirmation ("Your account was deleted" + OK) while still signed in;
  OK calls `AuthCubit.finishAccountDeletion()` (local sign-out). `AuthRepository.deleteAccount` is server-only. 914 Flutter tests pass, analyze clean (CI of `e8da903` success).
- 7.3/7.4 Privacy policy, terms of use, data deletion: trilingual (EN/PT/ES blocks switched by `html[lang]`), drafts without legal review, live and verified (200) at
  `https://lucksrei.com/projects/orbijob/privacy/`, `/terms/`, `/data-deletion/` (the site pattern is `projects/<app>/...`, not `/orbijob/...`; app links corrected). The older PT-only privacy page (said only Jobicy, deletion by e-mail) was replaced.
  The site's `tests/i18n.test.js` fails on "34 apps vs 35": pre-existing from the portfolio commit, not ours.
- 7.5 Security audit: `01_audit.paste.sql` on the real project = `audit: ok`; production e2e (`worker/scripts/account-e2e.mjs`, 35 checks incl. cross-account IDOR on rows/storage/signed links, anon, push-send secret) all pass.
  `docs/SECURITY.md` and master checklist rows 8/20 updated.
- Edge Functions published: push-send (v5), account-delete (v1), account-export (v1). No migrations applied in 7.0.

## Phase 8.0 - DONE as far as viable (docs/ORBIJOB_8_0.md)
Measured 13,491 visible listings (1,390 without a country, mostly remote with no stated country). Evaluated Canada Job Bank (no per-listing URL: unusable), Edmonton/Calgary (about 97 listings, optional), Brazil/Mexico/Colombia/Chile/Argentina/Uruguay (nothing licensed or exposed), Latvia (unchanged). Get on Board: growth frozen at 600, request drafted, reversible unpublish documented (`docs/GETONBOARD_PERMISSION.md`).
Search benchmark saved (`docs/evidence/search-benchmark-2026-10-14.txt`). Pelvic-health physiotherapy stays at 0 (no source lists it).

## Phase 9.0 / 10.0 - DONE as far as viable (docs/ORBIJOB_9_10.md)
Resume parser fixed for 6 real defects found with non-technology CVs (+German); recommender reviewed (limitation noted: health area is one bucket); backend latency measured (no change justified);
`scripts/supabase/diagnostics/ops-health.sql` added; Arbeitnow/Jobtech ceilings raised (scheduled run was red with exit 7).

## Phase 11.0 - DONE (docs/ORBIJOB_11_0.md)
Git: main carries `7a9aaa7` (password recovery by code, separated from the shared tree by a 3-way merge), `ad98ead` (relevance levels), `a034bda` (ops-health workflow), `47d8c45` (a11y/layout nets), `0e5c00c` (docs). Site: `725c20b`. The shared tree `C:\Users\lucas\orbijob` is clean at main; its old uncommitted state is in two `git stash` entries and in `C:\Users\lucas\orbijob-backups\otp-tree-2026-10-14`. The worktree `orbijob-wt7` is still the working copy for app changes.
Done: recovery by code integrated; recommendations classify same profession / same occupation group / related / general area only / incompatible with ESCO-ISCO (+curated generic words); ops-health daily workflow with the Worker's existing key; benchmarks re-run; accessibility and layout nets for recovery and delete-account screens; the site i18n test fixed.
**Owner action:** Supabase "Reset Password" e-mail template must contain `{{ .Token }}` (docs/auth/RECOVERY_CODE.md), otherwise recovery by code has no code to type.

## Open items / next steps
1. CI of the latest commits (`e2188d1`, `06d7403`): check `gh run list`.
2. Owner: legal review of privacy/terms; Get on Board answer (or run the unpublish SQL); NAV/USAJOBS/Jooble keys; a scheduled GitHub workflow for ops-health needs a database access secret.
3. Optional: Edmonton+Calgary connector (about 97 listings); finer health taxonomy for recommendations (physiotherapist vs doctors); native-speaker review of the new `pd*` strings and legal pages; device validation of export (share sheet) and deletion.
4. The `orbijob-otp` session still has uncommitted work in `C:\Users\lucas\orbijob` (see top of this file); the worktree `C:\Users\lucas\orbijob-wt7` (branch `wt7`) can be removed with `git worktree remove` once that session is done.
5. `lucksrei` site: `tests/i18n.test.js` fails on "34 apps vs 35" (pre-existing, from the portfolio commit), not part of this work.

## Environment notes
- Flutter: `export PATH="/c/Users/lucas/AppData/Local/Temp/fl3477/bin:$PATH"` (3.47.7) inside `orbijob/app`; repo files are CRLF (use scripts that preserve it).
- Supabase CLI is linked to the right project (`supabase/.temp/project-ref`); SQL via `npx.cmd supabase db query --linked -f file.sql`; deploy with
  `npx.cmd supabase functions deploy <name> --project-ref rpmlfxwebnlxnwadyvle --use-api`. The service role has no SELECT on private tables (least privilege).
- Commit messages in English, no AI mentions; `git pull --rebase origin main` before pushing (another session pushes iOS changes).
