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

## Phase 8.0 (not started)
Brazil/LatAm and other regions: new sources (classify PERSIST/FEDERATED/LINK_ONLY/PENDING/BLOCKED); Get on Board licence (prepare the request, do not send; recommend a reversible
unpublish if no permission); data quality (1,393 without country, 326 short descriptions, remote geo restriction); profession coverage (Flutter, pelvic physio, nursing, teachers,
electricians, welders…); monitoring metrics. Pattern for adding a source is in `docs/SOURCES_6_0.md` / memory note orbijob-6-0-estado.

## Phase 9.0 / 10.0 (not started)
Resume extraction audit, profile structure, explainable recommendations, UX pass; Flutter/backend performance measurements, monitoring views, full automated quality run.

## Environment notes
- Flutter: `export PATH="/c/Users/lucas/AppData/Local/Temp/fl3477/bin:$PATH"` (3.47.7) inside `orbijob/app`; repo files are CRLF (use scripts that preserve it).
- Supabase CLI is linked to the right project (`supabase/.temp/project-ref`); SQL via `npx.cmd supabase db query --linked -f file.sql`; deploy with
  `npx.cmd supabase functions deploy <name> --project-ref rpmlfxwebnlxnwadyvle --use-api`. The service role has no SELECT on private tables (least privilege).
- Commit messages in English, no AI mentions; `git pull --rebase origin main` before pushing (another session pushes iOS changes).
