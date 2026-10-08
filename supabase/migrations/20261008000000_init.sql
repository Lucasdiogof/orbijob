-- JobRadar initial schema (PROPOSAL - NOT EXECUTED against any Supabase project).
-- Public job data is separated from private user data. All private tables are
-- owner-only through RLS; public job tables are read-only for clients and
-- written exclusively by the Worker with the service role.

create extension if not exists pg_trgm;

-- ───────── public catalog ─────────
create table public.job_sources (
  id            text primary key,               -- 'lever', 'usajobs', ...
  status        text not null check (status in ('READY','CONDITIONAL','EXTERNAL_ONLY','BLOCKED','RESEARCH')),
  attribution   text,                           -- text/link that MUST be shown with jobs of this source
  can_redistribute boolean not null default false,
  created_at    timestamptz not null default now()
);

create table public.jobs (
  id             uuid primary key default gen_random_uuid(),
  source_id      text not null references public.job_sources(id),
  external_id    text not null,
  cluster_id     uuid,                          -- dedupe cluster (see job_clusters)
  company        text not null,
  title          text not null,
  description    text not null default '',
  country        char(2),
  city           text,
  language       text,
  work_mode      text not null default 'unspecified' check (work_mode in ('remote','hybrid','onsite','unspecified')),
  contract_type  text,
  salary_min     numeric,
  salary_max     numeric,
  salary_currency char(3),
  salary_period  text check (salary_period in ('hour','day','week','month','year')),
  published_at   timestamptz,
  last_checked_at timestamptz not null,
  requirements   text[] not null default '{}',
  skills         text[] not null default '{}',
  original_url   text not null,
  apply_url      text,
  status         text not null default 'open' check (status in ('open','closed','unknown')),
  geo_restrictions text[] not null default '{}',
  isco08         char(4),                       -- resolved occupation (nullable)
  fingerprint    text not null,
  canonical_url  text not null,
  search         tsvector generated always as (
                   to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(company,'') || ' ' || coalesce(description,''))
                 ) stored,
  unique (source_id, external_id)
);
create index jobs_search_idx      on public.jobs using gin (search);
create index jobs_title_trgm_idx  on public.jobs using gin (title gin_trgm_ops);
create index jobs_country_idx     on public.jobs (country, published_at desc);
create index jobs_isco_idx        on public.jobs (isco08, country);
create index jobs_fingerprint_idx on public.jobs (fingerprint);
create index jobs_canonical_idx   on public.jobs (canonical_url);

create table public.job_clusters (
  id uuid primary key default gen_random_uuid(),
  canonical_job_id uuid references public.jobs(id),
  created_at timestamptz not null default now()
);

-- Sync audit: counts and status only, never payloads or personal data.
create table public.sync_runs (
  id uuid primary key default gen_random_uuid(),
  source_id text not null references public.job_sources(id),
  scope text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null check (status in ('running','ok','partial','failed')),
  fetched int not null default 0,
  upserted int not null default 0,
  duplicates int not null default 0,
  closed int not null default 0,
  http_errors int not null default 0,
  error_class text
);

alter table public.job_sources enable row level security;
alter table public.jobs        enable row level security;
alter table public.job_clusters enable row level security;
alter table public.sync_runs   enable row level security;

create policy job_sources_read on public.job_sources for select to anon, authenticated using (true);
-- Only jobs of sources licensed for redistribution are readable by clients.
create policy jobs_read on public.jobs for select to anon, authenticated
  using (exists (select 1 from public.job_sources s where s.id = jobs.source_id and s.can_redistribute and s.status in ('READY','CONDITIONAL')));
create policy clusters_read on public.job_clusters for select to anon, authenticated using (true);
-- sync_runs: no client policy => no client access. Writes use the service role (bypasses RLS).

-- ───────── private user data ─────────
create table public.professional_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,                      -- profile label ("Nurse", "Dev")
  country_of_residence char(2),
  languages jsonb not null default '[]',   -- [{code:'pt',level:'native'}]
  occupations text[] not null default '{}',-- ISCO-08 codes
  skills text[] not null default '{}',
  preferences jsonb not null default '{}', -- salary, mode, countries
  work_authorizations jsonb not null default '[]', -- ONLY if user-provided
  personal jsonb not null default '{}',    -- autofill data: name, phone, links
  created_at timestamptz not null default now()
);
create table public.experiences (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.professional_profiles(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  company text not null, title text not null, start_date date, end_date date, description text
);
create table public.education (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.professional_profiles(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  institution text not null, degree text, field text, start_date date, end_date date
);
create table public.credentials (        -- certifications + professional licences
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.professional_profiles(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('certification','license')),
  name text not null, issuer text, country char(2), number text, expires_on date
);
create table public.resumes (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.professional_profiles(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,              -- bucket 'resumes', path '<user_id>/<uuid>.pdf'
  created_at timestamptz not null default now()
);
create table public.saved_jobs (
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  note text, created_at timestamptz not null default now(),
  primary key (user_id, job_id)
);
create table public.saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  query jsonb not null, created_at timestamptz not null default now()
);
create table public.viewed_jobs (
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (user_id, job_id)
);
create table public.applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid references public.jobs(id) on delete set null,
  profile_id uuid references public.professional_profiles(id) on delete set null,
  job_snapshot jsonb not null,             -- title/company/url at time of applying
  channel text, applied_at timestamptz,
  stage text not null default 'applied' check (stage in ('applied','screening','interview','offer','rejected','withdrawn','closed')),
  note text
);
create table public.application_events (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  stage text not null, occurred_at timestamptz not null default now(), note text
);
create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  application_id uuid references public.applications(id) on delete cascade,
  due_at timestamptz not null, text text not null, done boolean not null default false
);

do $$
declare t text;
begin
  foreach t in array array['professional_profiles','experiences','education','credentials','resumes',
                           'saved_jobs','saved_searches','viewed_jobs','applications','application_events','reminders']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t||'_owner', t);
    execute format('create index %I on public.%I (user_id)', t||'_user_idx', t);
  end loop;
end $$;

-- Child rows must also point to a parent owned by the same user (blocks cross-user linking).
create policy experiences_parent on public.experiences as restrictive for all to authenticated
  using (exists (select 1 from public.professional_profiles p where p.id = profile_id and p.user_id = (select auth.uid())))
  with check (exists (select 1 from public.professional_profiles p where p.id = profile_id and p.user_id = (select auth.uid())));
create policy application_events_parent on public.application_events as restrictive for all to authenticated
  using (exists (select 1 from public.applications a where a.id = application_id and a.user_id = (select auth.uid())))
  with check (exists (select 1 from public.applications a where a.id = application_id and a.user_id = (select auth.uid())));

-- ───────── private storage (resumes) ─────────
-- Executed on Supabase only (storage schema is provided by the platform):
-- insert into storage.buckets (id, name, public) values ('resumes','resumes',false);
-- create policy resumes_owner on storage.objects for all to authenticated
--   using (bucket_id='resumes' and (storage.foldername(name))[1] = (select auth.uid())::text)
--   with check (bucket_id='resumes' and (storage.foldername(name))[1] = (select auth.uid())::text);
