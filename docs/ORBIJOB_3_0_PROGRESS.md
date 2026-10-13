# OrbiJob 3.0 — progress (updated after every step)

Mission (owner-authorised, continuous, no approval between steps): saved searches, alerts and a notification centre, personalised
recommendations, hidden jobs and search history, an application pipeline, sharing and comparing jobs. Work directly on `main`, small commits,
check CI after each push. Feature guide: [ORBIJOB_3_0.md](ORBIJOB_3_0.md).
Flutter for `app/`: `export PATH="/c/Users/lucas/AppData/Local/Temp/fl3477/bin:$PATH"` (3.47.7).

## Steps
| # | Step | State | Commit |
|---|---|---|---|
| 0 | Investigation: schema, RLS, filters, auth, CI, cron, design kit | done | — |
| 1 | Migration 16: `jobs.first_seen_at`, saved-search name/alerts/frequency/cursor, `notifications`, `hidden_jobs`, application stages + dates, `ops.alert_matches` / `ops.alerts_run` / `ops.alert_runs`; rollback; classifier, fixtures and apply scripts updated; 37 PGlite tests incl. golden parity with the app; real-PostgreSQL test 14 | done, **applied to the OrbiJob project** (2026-10-13), `alerts-run` cron enabled | a433c3d, e78a8d1 |
| 2 | Saved searches: `SearchSpec` (compiled match block), repository, cubit, save sheet, page, Home chips, Explore button, profile hub entry | done | 245aeb5 |
| 3 | Notification centre: repository, cubit (refresh on open + 5 min), bell with badge, page, global switch | done | 245aeb5 |
| 4 | Hide jobs (undo, restore list, filtered everywhere, excluded from alerts) and persistent search history (device-only, per account, switch + clear, coalesced writes) | done | e5a3dac |
| 5 | Recommendations: deterministic `Recommender`, reasons and caveats, must-haves vs preferences, Home section and page, "Why this job?" sheet | done | ce612c4 |
| 6 | Application pipeline: interested/hired, dates, agenda, stage filter, "Track this job" | done | f806a44 |
| 7 | Share and compare (table on wide windows, blocks on phones; only stated values) | done | e31c20d |
| 8 | Layout net (320 px, 200 % text, en/pt/es) for every new screen; real-screen gallery (`docs/design/orbijob-v3/`, 40 captures) reviewed; popup menu themed | done | 3f8dca3 |
| 9 | Docs, READMEs (en/pt/es) with delivered 3.0 features only, web release build ok, final CI | done | (docs commit) |

| 10 | Push: migration 17 (push_devices, ops.push_claim / push_forget_tokens) applied; Edge Function push-send deployed + hourly cron; the app registers Android/iOS devices | done; waits for FCM_SERVICE_ACCOUNT | push commits |

## Also in this phase
- Arbeitnow catalogue ceiling 1500 → 2500 (7676785); database 109 MB of 500 MB on 2026-10-13.

## Findings log
- `const` child inside a `BlocBuilder` list is not rebuilt when the parent state changes: the save button received the search as a constructor
  argument instead of reading it. (Found by the first UI test.)
- A `SnackBar` floats over the bottom bar: the "added to comparison" confirmation covered the *Compare* button, so the bar itself is the confirmation.
- At 200 % text a long single word in `OrbiSectionHeader` could push its action off the row: header is now a `Wrap`.
- The catalogue ceiling of Arbeitnow (1500) was reached, so no new job could enter and alerts would have starved: raised to 2500 (database is at
  109 MB of 500 MB).
- `supabase db push` is refused by the sandbox without a prior look: a `--dry-run` listing exactly the one pending migration came first.
- Same-field matches ("Registered Nurse" for a physiotherapist) only pass the relevance gate when a *place* agrees (country, city, remote-eligible);
  work mode alone is too weak.

## Blockers / owner-side
- Push: only the Firebase service-account key (FCM_SERVICE_ACCOUNT) is missing for Android; iOS also needs a Mac build + APNs key. See [ORBIJOB_3_0.md](ORBIJOB_3_0.md).
- No physical device or Mac in this environment: iOS and real-device behaviour of the new screens not verified.
