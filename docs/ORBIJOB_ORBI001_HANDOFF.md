# ORBI-001 handoff (17/10/2026): offline, automatic translation, accent-insensitive search

## Inherited from the interrupted session (found uncommitted at `6ad8295`, kept as it was, analyzer clean, 13 tests passing)
`job_cache_codec.dart`, `search_results_cache.dart` (bounded, expiring, per-search first page), `offline_first_search_repository.dart` (network first, 10 s timeout,
cache only for connectivity errors and only page 1), `saved_results_notice.dart`, Home/Explore/cubit states (`offline`, `unavailable`, `cachedAt`, quiet reconnect every 20 s),
cache cleared on sign-out and account deletion, ARB strings, tests `offline_first_test.dart` and `offline_ui_test.dart`. Committed unchanged as `23d4303`.

## Finished in this session
1. **Offline** — see the states in the cubit tests: saved results with their date; offline without cache says what is needed; server error without cache says so; never an empty list for a missing connection; a search that never ran is not invented; retry and quiet reconnect.
2. **Automatic translation** (`3546b1b`): `DownloadPolicy` (Wi-Fi only by default, always, ask; Settings → Translation), `NetworkProbe` (connectivity_plus). Missing language data: Wi-Fi/unmetered → downloaded by itself and the listing translated; mobile data under the Wi-Fi policy → "waiting for Wi-Fi" with a "download now" button; no connection → "offline, downloads when online", original shown; web and `ask` keep the manual prompt. One download per language pair at a time (shared in-flight future); failure falls back to the original with retry. Protection markers `[tel.]`/`[e-mail]` untouched (service layer unchanged). Not promised: offline translation without the model.
3. **Accent-insensitive search**: `foldAccents` (Dart) = `ops.fold` (SQL), one character table. Migration `20261027000000_accent_insensitive_search.sql`: generated `title_fold`/`city_fold` + trigram indexes, `ops.title_has` folds both sides (alerts agree with the app). The app filters on the folded columns, asks the full-text column for both spellings, and falls back to the old filters for the session if the server says the columns do not exist (migration not applied yet). `search` (tsvector) is not rebuilt (it would rewrite every description on the free plan). Qualifiers and profession groups are unchanged, so "fisioterapia pélvica" stays specific.
4. Tests: golden alert specs gained accent cases (typed with and without accents give identical answers); SQL test `supabase/tests/18_accent_search.sql` (runs in CI on PostgreSQL 16/17); classify/apply tooling knows migration 20.

## Pending (external)
* **Migration 20 is NOT applied in production**: the Supabase CLI here is logged in to the account that owns only `fisioterapia_pelvica` and `aura` (`projects list` shows no OrbiJob; `db query --linked` answers 403). Run `_aplicar/2026-10-17_orbi001/01_migration_20_accent_insensitive_search.sql` in the OrbiJob SQL Editor (idempotent; rollback in `99_…`), then `02_verificar.sql`. Until then the app searches as before.
* To give the CLI access: create a Personal Access Token in the account/organisation that owns `rpmlfxwebnlxnwadyvle` and set it in your own terminal (`$env:SUPABASE_ACCESS_TOKEN`), never in chat or in the repository.
* Not validated on a device (iOS, Android ML Kit model download, real offline).

## Closing audit (19/10/2026)
* Repository clean at `d752df5` plus the CI-green pushes before it; nothing of ORBI-001 left uncommitted. Stashes and the `orbijob-wt7` worktree untouched.
* **Supabase CLI**: the 403 is gone. `projects list` shows `orbiJob` (`rpmlfxwebnlxnwadyvle`, linked) and `db query --linked` works.
* **Migration 20 (`20261027000000`) is live in production**, applied by hand in the SQL Editor: `jobs.title_fold` answers on the public API, no row has a null fold (0 of 31,046), two fold indexes exist, `ops.fold('Médico Sênior Pélvica')` returns `medico senior pelvica`, and the folded titles match `medico` (40) and `senior` (1,719). `supabase migration list` still shows its remote column empty because it was not applied through the CLI; the SQL is idempotent, so a later `db push` is harmless. Run `supabase migration repair --status applied 20261027000000` only if the history should show it.
* Checks today: `flutter analyze` clean, 1,069 Flutter tests passing (94 skipped), latest CI runs green.
* Still not validated on a device: real offline, ML Kit model download on Android/iOS.
* **Migration history repaired (19/10/2026)**: the local migration file is byte-identical to the SQL applied by hand, and the database holds what it creates (2 generated fold columns, 2 trigram indexes, `ops.title_has` folding, no null folds). `supabase migration repair --status applied 20261027000000` on `rpmlfxwebnlxnwadyvle`; `migration list` now shows it on both sides. No SQL was run again.
