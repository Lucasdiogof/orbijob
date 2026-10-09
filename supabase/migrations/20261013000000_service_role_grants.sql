-- service_role: the minimum table privileges the backend (Cloudflare Worker) needs.
--
-- Why: on the hosted project, tables created by `postgres` give service_role only TRUNCATE, REFERENCES, TRIGGER and
-- MAINTAIN by default (acl {service_role=Dxtm/postgres}, observed on 2026-10-09 after migrations 1-5). BYPASSRLS skips
-- row-level security but is NOT a table privilege, so without these grants the Worker's PostgREST calls with the
-- service key fail with "permission denied". No earlier migration mentions service_role. The local platform stub used to
-- grant ALL by default, which is why the tests never saw the gap.
--
-- What the backend does and what it needs:
--   ingestion / source sync   job_sources (read, create, update), jobs (read, create, update), sync_runs (log a run)
--   catalogue maintenance     jobs and job_clusters (also delete: dedupe clusters, purge closed or stale jobs)
--   orphan-file sweep         read public.resumes to compare with the Storage listing (files are removed through the
--                             Storage API, never through SQL)
--   account deletion          needs NO table privilege: auth.admin.deleteUser cascades through the foreign keys, and
--                             the user's files are removed through the Storage API
-- Everything else stays closed to service_role: user data (profiles, favourites, applications, ...) is not readable or
-- writable by the Worker, TRUNCATE/REFERENCES/TRIGGER are dropped, and future tables start with nothing.
-- Not granted on purpose: ALL, any write on user tables, delete on job_sources and sync_runs, EXECUTE on functions.
-- Idempotent (revoke then grant). The Flutter app never uses this role.

revoke all on all tables in schema public from service_role;
alter default privileges in schema public revoke all on tables from service_role;

grant select, insert, update on public.job_sources to service_role;
grant select, insert, update, delete on public.jobs, public.job_clusters to service_role;
grant select, insert, update on public.sync_runs to service_role;
grant select on public.resumes to service_role;
