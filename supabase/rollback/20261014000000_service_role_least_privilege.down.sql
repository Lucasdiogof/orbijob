-- Undo of 20261014000000_service_role_least_privilege.sql: gives service_role back the privileges migration 6 had granted.
-- Not run by anything automatically. Run it only on purpose (SQL Editor / CLI as postgres), then remove the version from the
-- migration history yourself if the migration had been recorded:
--   delete from supabase_migrations.schema_migrations where version = '20261014000000';
grant delete on public.jobs, public.job_clusters to service_role;
grant select on public.resumes to service_role;
grant insert, update on public.job_sources to service_role;
