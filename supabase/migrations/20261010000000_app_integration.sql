-- OrbiJob app integration (PROPOSAL - NOT EXECUTED against any Supabase project).
-- Third migration, applied after 20261008000000_init.sql and 20261009000000_rls_hardening.sql.
-- Adds what the Flutter app needs on top of the reviewed schema: preferences, favourites that can carry a
-- snapshot of a job that is not in the catalogue, automatic stage history, size guards, the private resume
-- bucket and its object policies. No SECURITY DEFINER function and no trigger on auth.users is created.
-- Destructive operations: none (saved_jobs is reshaped, but only ever holds rows if a client wrote to it).

-- pg_trgm out of the exposed `public` schema (Supabase advisor 0014); existing indexes follow the extension.
create schema if not exists extensions;
alter extension pg_trgm set schema extensions;

-- ───────── updated_at maintenance ─────────
create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;
revoke all on function public.set_updated_at() from public, anon, authenticated;

alter table public.professional_profiles add column updated_at timestamptz not null default now();
alter table public.applications          add column updated_at timestamptz not null default now();
create trigger professional_profiles_touch before update on public.professional_profiles
  for each row execute function public.set_updated_at();
create trigger applications_touch before update on public.applications
  for each row execute function public.set_updated_at();

-- ───────── user preferences (one row per user) ─────────
create table public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  theme text not null default 'system' check (theme in ('system','light','dark')),
  locale text check (locale is null or locale in ('pt','en','es')),
  countries_of_interest char(2)[] not null default '{}' check (cardinality(countries_of_interest) <= 30),
  settings jsonb not null default '{}' check (octet_length(settings::text) <= 4096),
  updated_at timestamptz not null default now()
);
alter table public.user_preferences enable row level security;
create policy user_preferences_owner on public.user_preferences for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create trigger user_preferences_touch before update on public.user_preferences
  for each row execute function public.set_updated_at();

-- ───────── favourites: catalogue job OR a snapshot of an external job ─────────
alter table public.saved_jobs drop constraint saved_jobs_pkey;
alter table public.saved_jobs
  add column id uuid not null default gen_random_uuid(),
  add column job_key text,
  add column snapshot jsonb not null default '{}';
update public.saved_jobs set job_key = job_id::text where job_key is null;
alter table public.saved_jobs
  alter column job_key set not null,
  alter column job_id drop not null,
  add primary key (id),
  add constraint saved_jobs_owner_key unique (user_id, job_key),
  add constraint saved_jobs_has_subject check (job_id is not null or snapshot <> '{}'::jsonb),
  add constraint saved_jobs_snapshot_size check (octet_length(snapshot::text) <= 16384),
  add constraint saved_jobs_note_len check (note is null or char_length(note) <= 5000);
drop policy saved_jobs_visible_job on public.saved_jobs;
create policy saved_jobs_visible_job on public.saved_jobs as restrictive for all to authenticated
  using (true)
  with check (job_id is null or exists (select 1 from public.jobs j where j.id = job_id));

-- ───────── size guards on free-form JSON/text written by clients ─────────
alter table public.applications
  add constraint applications_snapshot_size check (octet_length(job_snapshot::text) <= 16384),
  add constraint applications_note_len check (note is null or char_length(note) <= 5000);
alter table public.saved_searches
  add constraint saved_searches_query_size check (octet_length(query::text) <= 4096);
alter table public.professional_profiles
  add constraint profiles_json_size check (
    octet_length(languages::text) + octet_length(preferences::text)
    + octet_length(work_authorizations::text) + octet_length(personal::text) <= 32768),
  add constraint profiles_array_size check (cardinality(occupations) <= 50 and cardinality(skills) <= 200);

-- ───────── application stage history, written automatically ─────────
-- SECURITY INVOKER on purpose: the insert goes through the caller's RLS like any other write.
create function public.log_application_stage() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' or new.stage is distinct from old.stage then
    insert into public.application_events (application_id, user_id, stage)
    values (new.id, new.user_id, new.stage);
  end if;
  return new;
end $$;
revoke all on function public.log_application_stage() from public, anon, authenticated;
create trigger applications_log_stage after insert or update of stage on public.applications
  for each row execute function public.log_application_stage();

-- ───────── privileges for the new table (default privileges were revoked in the hardening migration) ─────────
grant select, insert, update, delete on public.user_preferences to authenticated;

-- ───────── private storage: resumes ─────────
-- Objects live at '<user_id>/<file>'. PDF only, 5 MiB. The bucket is never public; clients read through
-- short-lived signed URLs. Idempotent, so it can be re-run safely after a manual correction.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('resumes', 'resumes', false, 5242880, array['application/pdf'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists resumes_objects_select on storage.objects;
drop policy if exists resumes_objects_insert on storage.objects;
drop policy if exists resumes_objects_update on storage.objects;
drop policy if exists resumes_objects_delete on storage.objects;
create policy resumes_objects_select on storage.objects for select to authenticated
  using (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy resumes_objects_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy resumes_objects_update on storage.objects for update to authenticated
  using (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy resumes_objects_delete on storage.objects for delete to authenticated
  using (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid())::text);
