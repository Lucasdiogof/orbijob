-- OrbiJob RLS hardening (PROPOSAL - NOT EXECUTED against any Supabase project).
-- Follows the audit of 20261008000000_init.sql: closes cross-user linking on every child table, narrows client
-- privileges to what the app needs (defence in depth behind RLS) and indexes the foreign keys used by policies.

-- ───────── child rows must point to a parent owned by the same user ─────────
create policy education_parent on public.education as restrictive for all to authenticated
  using (exists (select 1 from public.professional_profiles p where p.id = profile_id and p.user_id = (select auth.uid())))
  with check (exists (select 1 from public.professional_profiles p where p.id = profile_id and p.user_id = (select auth.uid())));
create policy credentials_parent on public.credentials as restrictive for all to authenticated
  using (exists (select 1 from public.professional_profiles p where p.id = profile_id and p.user_id = (select auth.uid())))
  with check (exists (select 1 from public.professional_profiles p where p.id = profile_id and p.user_id = (select auth.uid())));
create policy resumes_parent on public.resumes as restrictive for all to authenticated
  using (exists (select 1 from public.professional_profiles p where p.id = profile_id and p.user_id = (select auth.uid())))
  with check (exists (select 1 from public.professional_profiles p where p.id = profile_id and p.user_id = (select auth.uid())));
-- profile_id is optional on applications; when present it must be the user's own.
create policy applications_parent on public.applications as restrictive for all to authenticated
  using (profile_id is null or exists (select 1 from public.professional_profiles p where p.id = profile_id and p.user_id = (select auth.uid())))
  with check (profile_id is null or exists (select 1 from public.professional_profiles p where p.id = profile_id and p.user_id = (select auth.uid())));
create policy reminders_parent on public.reminders as restrictive for all to authenticated
  using (application_id is null or exists (select 1 from public.applications a where a.id = application_id and a.user_id = (select auth.uid())))
  with check (application_id is null or exists (select 1 from public.applications a where a.id = application_id and a.user_id = (select auth.uid())));

-- A resume row may only reference an object inside its owner's storage folder ('<user_id>/<file>').
alter table public.resumes
  add constraint resumes_storage_path_owner check (storage_path like user_id::text || '/%' and storage_path not like '%..%');

-- Only jobs a client could read may be saved/viewed (no probing for ids of non-redistributable jobs).
create policy saved_jobs_visible_job on public.saved_jobs as restrictive for all to authenticated
  using (true)
  with check (exists (select 1 from public.jobs j where j.id = job_id));
create policy viewed_jobs_visible_job on public.viewed_jobs as restrictive for all to authenticated
  using (true)
  with check (exists (select 1 from public.jobs j where j.id = job_id));

-- Clusters reveal nothing on their own, but only expose those whose canonical job the client may read.
drop policy clusters_read on public.job_clusters;
create policy clusters_read on public.job_clusters for select to anon, authenticated
  using (exists (select 1 from public.jobs j where j.id = canonical_job_id));

-- ───────── privileges: least privilege behind RLS ─────────
revoke all on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;
-- public catalogue: read-only for clients (writes only through the Worker with the service role)
grant select on public.job_sources, public.jobs, public.job_clusters to anon, authenticated;
-- private data: signed-in users only; anon gets nothing. sync_runs: no client privilege at all.
grant select, insert, update, delete on
  public.professional_profiles, public.experiences, public.education, public.credentials, public.resumes,
  public.saved_jobs, public.saved_searches, public.viewed_jobs, public.applications, public.application_events,
  public.reminders
  to authenticated;

-- ───────── indexes on foreign keys (policy subqueries, cascades, joins) ─────────
create index jobs_source_idx            on public.jobs (source_id);
create index jobs_cluster_idx           on public.jobs (cluster_id);
create index job_clusters_canonical_idx on public.job_clusters (canonical_job_id);
create index sync_runs_source_idx       on public.sync_runs (source_id, started_at desc);
create index experiences_profile_idx    on public.experiences (profile_id);
create index education_profile_idx      on public.education (profile_id);
create index credentials_profile_idx    on public.credentials (profile_id);
create index resumes_profile_idx        on public.resumes (profile_id);
create index saved_jobs_job_idx         on public.saved_jobs (job_id);
create index viewed_jobs_job_idx        on public.viewed_jobs (job_id);
create index applications_job_idx       on public.applications (job_id);
create index applications_profile_idx   on public.applications (profile_id);
create index application_events_app_idx on public.application_events (application_id);
create index reminders_application_idx  on public.reminders (application_id);
create index reminders_due_idx          on public.reminders (user_id, due_at) where not done;

-- ───────── private storage (resumes) ─────────
-- Run in the Supabase SQL editor / CLI after reviewing (the storage schema is provided by the platform):
-- insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
--   values ('resumes','resumes', false, 5242880, array['application/pdf'])
--   on conflict (id) do nothing;
-- create policy resumes_objects_owner on storage.objects for all to authenticated
--   using (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid())::text)
--   with check (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid())::text);
