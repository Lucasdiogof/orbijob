# OrbiJob 7.0–10.0 — finalization progress (checkpoint)

Started 2026-10-13/14 in a new session. Source of truth: this file + the repository + project `rpmlfxwebnlxnwadyvle` (never touch another Supabase project).
Do NOT re-run the six 6.0 publish SQLs. No store/build/device work (out of scope).

## State at the pause
- Last published commit: `bfbeefc` (account-delete / account-export Edge Functions + tests + e2e script), on top of `33bf007` (iOS, other work).
- CI of `bfbeefc`: not checked yet.
- Uncommitted in the working tree (Flutter side of 7.1/7.2, NOT committed because one widget test still fails):
  `app/lib/features/privacy/**` (new), `app/lib/features/auth/**` (deleteAccount), `app/lib/core/di/injector.dart`,
  `app/lib/features/profile/profile_page.dart` (YourDataSection in the privacy screen), `app/lib/l10n/*` (29 `pd*` keys in en/pt/es, regenerated),
  `app/test/features/account_data_test.dart` (new), `app/test/supabase/auth_test.dart`, `app/test/helpers/fakes.dart`.

## Phase 7.0
### Done and verified
- Edge Function `account-delete` (deployed, JWT verified): identifies the user only by the verified token, requires the current password (re-auth) and
  `confirm:true`, removes the `resumes/<uid>/` files, then the Auth user (all private tables cascade from `auth.users`). Idempotent; ignores any id in the body.
- Edge Function `account-export` (deployed, JWT verified, NO privileged key: reads as the caller so RLS decides): JSON with account + 15 tables, resume signed links
  (1 h), never push tokens/credentials.
- Worker tests `worker/test/account-data.test.ts` (13). Whole Worker suite: 816 pass; `tsc` clean.
- Production e2e `worker/scripts/account-e2e.mjs` on throw-away accounts (`e2e-xxxx@orbijob-test.invalid`): all 24 checks passed (export isolation, wrong password,
  B's password with A's token, id in body ignored, files and rows gone, B untouched, old token dead, repeat call = 401). `auth.users` count stayed 1 (the owner).
  Run: `SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... SUPABASE_SECRET_KEY=$(npx supabase projects api-keys ...) node worker/scripts/account-e2e.mjs`.
- Flutter: `AuthRepository.deleteAccount`, `AuthCubit.deleteAccount` (+ `afterAccountDeleted` clears recent searches and translation cache), `SupabaseAccountDataRepository`
  (ZIP = `orbijob-data.json` + resume PDFs, signed links removed), `DataExportCubit`, "Your data" section (export, delete dialog with password + acknowledgement, links).
  Analyze clean; unit tests (zip, cubit, auth mapping) pass.

### In progress / failing
- `account_data_test.dart`, widget test "delete: ... a wrong password deletes nothing": after the successful delete the "Your account and data were deleted." snack bar is not
  found; in the test the tree shows no `Text` at all after sign-out (probably the test harness/launch overlay or my `UserScope` rebuild; investigate, maybe assert through
  `FakeAuth` state only or check how existing sign-out tests settle). The snack bar is shown from `_DeleteCard._confirm` using the messenger captured before the dialog.
- Export widget test: fixed to `textContaining(pdExportDone)`; re-run.
- Then: run the full Flutter suite (`export PATH=/c/Users/lucas/AppData/Local/Temp/fl3477/bin:$PATH`, `flutter analyze`, `flutter test`), regenerate goldens if the privacy screen has any, commit, push, check CI.

### Not started
- 7.3 Privacy policy + terms (pt/en/es), technical drafts, no invented guarantees; real data flows: Supabase Auth/DB/Storage, FCM push, on-device translation, WebView, no ads/trackers.
- 7.4 Public pages on lucksrei.com (`/orbijob/privacy`, `/terms`, `/delete-account`, `/export`): the app already links to `https://lucksrei.com/orbijob/{privacy,terms,delete-account}`
  (constants in `your_data_section.dart`); the site repo is `C:\Users\lucas\lucksrei` (do not touch other apps' pages). Until published those links 404.
- 7.5 Security audit (RLS, grants, storage, SECURITY DEFINER, WebView/URL policy, PDF upload, logs, secrets), fix only demonstrated issues; update `docs/SECURITY.md`
  (still says deletion/export "to be implemented").
- Update `docs/ORBIJOB_MASTER_CHECKLIST.md` rows 8, 20, 26-27 (deletion/export now exist; policy pending) keeping its 5 columns honest (device = no).

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
