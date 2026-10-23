# Supabase usage audit (2026-10-22)

Cycle 06/10–06/11/2026 (Free plan): egress 6.93 GB of 5 GB (grace period until 21/11), database 0.455 GB of 0.5 GB, 13 MAU, 252 Edge Function calls.

## Main cause of egress (found in the code, sized by measurement)
`worker/scripts/discover-local.mjs` (run by every `Sources discover` and `Jobicy discover` pass) took a before/after "snapshot" of **every stored row of
the source with its full text** (description, title, company…) to prove a pass changed nothing. It ran **three times per pass** (preflight step, before,
after), including passes that then stood down by the hourly lease, at **77 passes a day**.

* Measured through the public API (500 rows): with the snapshot's columns **2.05 MB (jobtech) / 2.87 MB (arbeitnow)**; with identity columns only
  **0.13 / 0.17 MB** — about 16× less.
* Estimate (not measured: the egress logs and the usage API were not reachable from this machine): sources of 1,000–4,000 rows × ~4–6 KB × 3 snapshots ×
  77 passes ≈ several GB a day uncompressed; responses are gzip-compressed on the wire, which brings it to the order of the ~0.4 GB/day the dashboard shows.
* Why 13 users make 7 GB: the traffic is machine traffic (the ingestion's own checks), not app use.

## Fixed (commits)
| Commit | Change | Expected effect |
|---|---|---|
| 5e6ed5f | the snapshot reads `original_url, apply_url, fingerprint, canonical_url` only (a pass only INSERTs with ON CONFLICT DO NOTHING; identity changes are still caught); regression test | ~16× less per snapshot |
| a188421 | `Sources discover` once a day per source (77 → 22 passes a day; Choisir le Service Public twice, it confirms at most 80 offers a pass); listings stay confirmed inside the app's 72 h window | ~3.5× fewer passes |

Combined: the dominant flow drops by roughly 50×. Projection, not yet confirmed: well under 1 GB a month for ingestion. Confirm on the dashboard
(Usage → Egress, daily bars) over the next 3–5 days: the bars from 23/10 on should be a small fraction of the previous ones.

## Checked and left as is
* Worker store (`src/store/supabase.ts`): lists read identifiers only, inserts return `external_id` only, counts use `limit=1` — already lean.
* Supabase Cron revalidation: runs inside the database; its outbound requests are small.
* App list (`supabase_job_catalog_repository.dart`): pages of 20 rows include `description`, which the recommender scores on; there is a local cache
  (`job_cache_codec.dart`). With 13 users this is minor next to the ingestion; dropping the description from lists would change recommendations.

## Not done (needs the owner)
* **Database size (455 MB)**: the CLI login on this machine has no `database_write` permission on the project (`supabase db query` now answers 403), so
  table/index sizes could not be read and no migration could be applied. Next step once access returns: `pg_total_relation_size` per table and index,
  compaction of closed rows' text (retention already exists), and dropping unused indexes — each with impact and rollback first.
* **Egress logs / Top Paths**: reading them needs the Management API token; not done from here. The dashboard's Logs → Edge logs filtered on `/rest/v1/jobs`
  will show the drop directly.
