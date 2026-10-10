-- service_role, second step of least privilege: remove what NO backend job uses.
--
-- Migration 6 gave service_role what the first design foresaw (catalogue maintenance, orphan-file sweep). The Worker and the GitHub
-- Actions revalidation turned out to need less, and the key of a scheduled job lives outside the database, so every privilege it
-- does not need is a way for a leaked key to do harm:
--
--   DELETE on jobs, job_clusters   a leaked key could erase the catalogue and, through `saved_jobs.job_id ... on delete cascade`, every
--                                  user's favourites. Nothing deletes a job: closing is an UPDATE of status.
--   SELECT on resumes              exposes the metadata (owner, storage path) of every user's resume. The orphan-file sweep that would
--                                  have used it was never built.
--   INSERT, UPDATE on job_sources  lets a key publish or hide the whole catalogue (can_redistribute) and rewrite the attribution text.
--                                  Sources are created and published by the owner (scripts/supabase/ops/publish_jobicy.sql, SQL
--                                  Editor / CLI as postgres), never by the sync.
--
-- What stays, and why (the revalidation AND the full pass both work with exactly this):
--   job_sources   SELECT                  read the source row
--   jobs          SELECT, INSERT, UPDATE  upsert listings (full pass), close/confirm them (revalidation)
--   job_clusters  SELECT, INSERT, UPDATE  reserved for deduplication (unused today); no DELETE
--   sync_runs     SELECT, INSERT, UPDATE  the lease and the run ledger
-- INSERT on jobs stays because the same role runs the full pass; the revalidate-only mode is held to "no new jobs" by the code and the
-- tests, not by the database.
--
-- Idempotent (a REVOKE of a privilege that is not held changes nothing). Rollback: supabase/rollback/20261014000000_service_role_least_privilege.down.sql.
revoke delete on public.jobs, public.job_clusters from service_role;
revoke select on public.resumes from service_role;
revoke insert, update on public.job_sources from service_role;
