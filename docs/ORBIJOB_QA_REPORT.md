# OrbiJob final QA and stabilisation report (19/10/2026)

Scope: audit only, no new features or sources. Baseline `a571218` (CI green); one fix pushed (`66b6546`). Project checked: `rpmlfxwebnlxnwadyvle` (CLI link and every query used that ref).

Legend: PASSOU = checked and fine; CORRIGIDO = defect found and fixed with a regression test; PENDENTE = needs the owner or an external step; NÃO VALIDADO = only automated tests exist, nothing observed on a device or by hand.

## Checks run
| Check | Result |
|---|---|
| `flutter analyze` | clean |
| Flutter tests | 1,069 passed, 94 skipped (before the fix); the fix's tests pass; CI of `66b6546` green |
| Worker `tsc --noEmit` | clean |
| Worker tests (vitest) | 994 passed, 39 skipped. One run under heavy parallel load failed on a timeout; the rerun was clean (load-sensitive PGlite tests, no code defect found) |
| SQL tests (`supabase/tests`, PostgreSQL 16/17) | run by CI only (green); not run locally |
| Secret scan of tracked files | only fixtures with fake `sb_secret_…` strings in tests; no real key |
| ARB parity | en/pt/es have the same 767 keys; no long string left identical to English in pt |
| Ops health (CI, 19/10 13:49) | no ALERT. WARN: daily sources show 15–24 h since last verification (normal for daily schedules), Arbeitnow 2,790/3,500 open rows unverified for 72 h (known ceiling, hidden in the app), Get on Board one `http_403` pass in 24 h (known, transient) |

## Production security (read-only queries and anonymous requests)
* Every public table has RLS on; no `anon` write grants; no SECURITY DEFINER function without a fixed `search_path`; the only public SECURITY DEFINER function is `rls_auto_enable`, an event-trigger function (cannot be called directly).
* Private tables (`applications`, `resumes`, `professional_profiles`, `notifications`, `push_devices`, `saved_searches`, `credentials`, `user_preferences`, `sync_runs`) answer `42501` to the anonymous key. `job_sources` and the catalogue are readable, as designed.
* `resumes` bucket is private; its four policies scope every action to the owner's folder (`foldername[1] = auth.uid()`); anonymous listing returns nothing.
* `saved_jobs` / `viewed_jobs` have owner policies (permissive) plus a RESTRICTIVE "job must be visible" policy: not an open `true` policy.
* Edge Functions: `account-delete`, `account-export` and `push-send` answer 401 without a token; with only the publishable key they answer 400/401 and never act (the user lookup precedes any deletion or export). `account-delete` checks the body shape before looking the user up: harmless, left as is.
* Anonymous users cannot call functions in `ops`.
* Not done: cross-user IDOR attempts with two real sessions (needs two real accounts; the automated tests cover isolation with fakes and `account-delete` was verified on throw-away accounts in `bfbeefc`).

## Flows
| Flow | Status | Evidence |
|---|---|---|
| Sign in / sign up | PASSOU (automated) | auth cubit, repository and widget tests |
| Password recovery by 6-digit code | CORRIGIDO | Found: a 5xx from the server (SMTP failure) was shown as "no connection". Fixed in `66b6546` (auth and data layers, tests added). Production: `/auth/v1/recover` now answers 200 after the owner fixed the SMTP sender; the e-mail arrival and the typed-code step are NÃO VALIDADO on a device |
| Home, Explore, filters, job detail | PASSOU (automated) | widget, golden and layout tests |
| Offline with/without cache, reconnect, restart, page 2 offline | PASSOU (automated) | `offline_first_test`, `offline_ui_test`, cubit tests; real airplane mode NÃO VALIDADO |
| Automatic translation and Wi-Fi/mobile-data policy | PASSOU (automated) | translation tests; ML Kit model download NÃO VALIDADO on device |
| Accent-insensitive search and alert parity | PASSOU | migration live; 0 null folds in 31,046 rows; `medico` 40, `senior` 1,719; golden alert specs and `18_accent_search.sql` in CI |
| Favourites, saved searches, alerts, recommendations, applications, hidden jobs | PASSOU (automated) | cubit/widget tests; offline copies for favourites and applications |
| PDF résumé, profile | PASSOU (automated) | profile and résumé tests; scanned PDFs have no OCR (documented) |
| Notifications / push | NÃO VALIDADO | no physical device; FCM delivery never observed |
| Export and delete account | PASSOU | Edge Functions tested and checked on throw-away accounts (`bfbeefc`); app screens covered by tests |
| Accessibility, 200 % text, 320 px, dark/light, en/pt/es | PASSOU (automated) | layout and semantics nets for the main screens, recovery screens and delete dialog |
| Backend: Worker, connectors, ops-health, cron | PASSOU | tests, CI schedules green, ops-health without ALERT |

## Bugs found
1. **Fixed** (`66b6546`): auth/data errors with HTTP 5xx were reported as "no connection" (found because the recovery e-mail failed with 500 while the phone was online).
2. Not code: the Supabase SMTP sender (domain not verified / key) caused that 500; the owner configured it and the endpoint now answers 200.

## Conclusion
**Is OrbiJob technically ready as a release candidate? SIM.** No technical blocker was found: analysis and test suites are green, CI is green, production RLS/Storage/Edge Function checks hold, migration history is consistent.

Left on purpose (not blockers for the candidate): physical-device validation (offline, ML Kit download, push, recovery e-mail in the real inbox), store/TestFlight distribution, the Get on Board redistribution licence, pending authorisation requests for Brazilian sources (Gupy, Remotar, Coodesh…), two-account IDOR test in production.
