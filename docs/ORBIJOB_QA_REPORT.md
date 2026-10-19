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

---

# Round 2: release-candidate validation (19/10/2026, HEAD `af4e881`, CI green)

Web checked by real navigation on https://orbijob.lucksrei.com (production build, signed out; no account was created and no e-mail was requested). Desktop 800×600 and mobile 375×812.

| Area | Method | Result | Evidence | Pending |
|---|---|---|---|---|
| Web home (desktop, mobile) | Real navigation | PASSOU | real listings, side menu on desktop, bottom bar on mobile, recent search kept after reload | cold start showed the orbital splash for roughly 10 s on the emulated pane (not measured precisely) |
| Search without accents | Real navigation | PASSOU | "medico" returned physician/medical listings (USAJOBS) | |
| Job detail | Real navigation | PASSOU | title, place, salary, original-language notice, description, "prepare application", "open original" | |
| Profile menu signed out | Real navigation | PASSOU | sign-in / create account, all sections listed | |
| Sign-in screen, "Forgot password" → code screen | Real navigation | PASSOU | the code-based screen opens; an invalid e-mail is blocked locally with a readable error (no request sent) | sending a code and typing it: owner (inbox) |
| Settings: language, theme, translation policy | Real navigation | PASSOU | Spanish applied at once, light theme applied, "Solo en Wi-Fi / Siempre / Preguntar" present | |
| Applications gate signed out (es, light) | Real navigation | PASSOU | explanatory empty state with create account / sign in | |
| Favourites, saved searches, profile, résumés, applications, export/delete signed in | Automated | PASSOU (automated) | test suites; no real account was used (creating one in production is out of bounds) | end-to-end with a real signed-in session: NÃO VALIDADO |
| Password-recovery OTP, technical | Automated + production | PASSOU | cubit/widget tests; `/auth/v1/recover` 200; wrong-code and 5xx mapped (`66b6546`). A 200 does not prove delivery | e-mail arrival and code entry: owner |
| Offline, translation, policy | Automated | PASSOU (automated) | offline-first, cubit, translation and layout tests; settings screen shows the policy | real offline, model download: device |
| RLS, Storage, Edge Functions | Production (read-only, anonymous) | PASSOU | see round 1 | two-account IDOR: needs two real accounts |
| Ops health | CI log | PASSOU | no ALERT; warnings only (daily sources 15–24 h, Arbeitnow ceiling, one Get on Board 403) | |
| Secrets | Repo scan | PASSOU | only fake test fixtures | |
| Capacity and catalogue | Production (read-only SQL) | PASSOU with a watch item | database 331 MB of 500 MB (66 %); 31,877 listings, 31,139 open; 0 duplicate source keys; 0 open listings with an invalid link; 14 active cron jobs; 2,034 open listings (6.5 %) without a country; 562 (1.8 %) with a very short description; 0 accounts yet | keep an eye on the 500 MB limit as the catalogue grows |

## Classification
1. **Ready and validated:** Web browsing (home, search, detail, settings, themes, languages, signed-out gates, recovery screen), production RLS/Storage/Edge Function checks, backend tests, CI, catalogue integrity.
2. **Implemented, no device validation:** offline reading, automatic translation and model download, push notifications, résumé upload from a phone, the signed-in flows (covered by automated tests, not by a real session), real offline behaviour.
3. **Depends on the owner:** the recovery e-mail reaching a real inbox and the typed code (SMTP now answers 200); store/TestFlight distribution; the Get on Board licence and the other source authorisations; a two-account production isolation test.
4. **Real blockers:** none found.

## Answer
**Ready to end development and start the final validation on devices? SIM.** Not "100 %": the signed-in flows and offline/translation have not been exercised end to end on a real session or device, only by automated tests.
