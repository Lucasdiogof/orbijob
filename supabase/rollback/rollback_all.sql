-- OrbiJob TEARDOWN (destructive). Removes everything the five migrations created so the project can be
-- re-provisioned from scratch. There are no "down" migrations in supabase/migrations: this file is run BY HAND,
-- only on a project that holds no data worth keeping.
--
-- Storage first, through the Storage API or the dashboard (NOT SQL): empty the `resumes` bucket and delete it.
-- Supabase blocks direct DELETEs on storage.buckets / storage.objects (and SQL deletes would leave the files behind),
-- so this script refuses to run while the bucket still exists.
--
--   PGOPTIONS="-c orbijob.confirm_rollback=yes" psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/rollback/rollback_all.sql
--
-- Without the confirmation setting it aborts before touching anything. Tested in supabase/tests/run.sh
-- (apply chain -> remove bucket "through the API" -> rollback -> verify clean -> re-apply chain).
begin;
do $$
begin
  if coalesce(current_setting('orbijob.confirm_rollback', true), '') <> 'yes' then
    raise exception 'refusing to run: set orbijob.confirm_rollback=yes to confirm this destructive teardown';
  end if;
  if exists (select 1 from storage.buckets where id = 'resumes') then
    raise exception 'bucket "resumes" still exists: empty and delete it through the Storage API or dashboard first';
  end if;
end $$;

drop policy if exists resumes_objects_select on storage.objects;
drop policy if exists resumes_objects_insert on storage.objects;
drop policy if exists resumes_objects_update on storage.objects;
drop policy if exists resumes_objects_delete on storage.objects;

drop table if exists
  public.reminders, public.application_events, public.applications, public.viewed_jobs, public.saved_searches,
  public.saved_jobs, public.resumes, public.credentials, public.education, public.experiences,
  public.professional_profiles, public.user_preferences, public.sync_runs, public.job_clusters, public.jobs,
  public.job_sources
  cascade;
drop function if exists public.set_updated_at();
drop function if exists public.log_application_stage();
drop function if exists public.enforce_row_quota();
drop extension if exists pg_trgm cascade;

-- restore the platform's own defaults for objects created by postgres (observed: TRUNCATE, REFERENCES, TRIGGER and, from PostgreSQL 17, MAINTAIN)
alter default privileges in schema public grant truncate, references, trigger on tables to anon, authenticated, service_role;
do $$ begin
  if current_setting('server_version_num')::int >= 170000 then
    execute 'alter default privileges in schema public grant maintain on tables to anon, authenticated, service_role';
  end if;
end $$;

-- forget the migrations so `supabase db push` can apply them again
do $$
begin
  if to_regclass('supabase_migrations.schema_migrations') is not null then
    delete from supabase_migrations.schema_migrations
    where version in ('20261008000000', '20261009000000', '20261010000000', '20261011000000', '20261012000000');
  end if;
end $$;
commit;
