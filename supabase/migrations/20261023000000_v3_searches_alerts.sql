-- OrbiJob 3.0 (migration 16): saved searches with alerts, the in-app notification centre, hidden jobs and the application pipeline.
--
-- What it adds, and what it deliberately does not:
--   * jobs.first_seen_at           when OrbiJob first stored a job. Alerts compare against it, never against the source's publication date.
--   * saved_searches               name, alerts on/off, frequency, and the cursor the alert run advances. `query` stays an opaque JSON object
--                                  (v2 carries a compiled `match` block the database can evaluate, see ops.alert_matches).
--   * notifications                one row per (user, job): the in-app notification centre. Written ONLY by ops.alerts_run (the owner, from
--                                  pg_cron); a user can read their rows and mark them read or dismissed, nothing else.
--   * hidden_jobs                  jobs a user hid (identity = source:externalId, like favourites), with a small snapshot so the list stays readable.
--   * applications                 two more stages (interested, hired) and two dates (interview_at, follow_up_at). Existing rows are untouched.
--   * ops.alert_matches / ops.alerts_run / ops.alert_runs   the matching and the hourly run. No function is added to `public` that the API
--                                  roles can call and there is no SECURITY DEFINER anywhere: the run is scheduled by an owner script
--                                  (scripts/supabase/ops/enable_alerts_cron.sql) and nothing here schedules it.
-- Alerts only ever consider jobs that are open, verified in the last 72 h, from an authorised source, published in the last 60 days (or undated),
-- first seen after the search's cursor, not hidden by the user and not already notified (same job id or same fingerprint).
-- Rollback: supabase/rollback/20261023000000_v3_searches_alerts.down.sql

-- ───────── jobs.first_seen_at ─────────
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'jobs' and column_name = 'first_seen_at') then
    alter table public.jobs add column first_seen_at timestamptz not null default now();
    -- jobs that already exist were "seen" no later than their last check; this keeps the very first alert run from treating the whole catalogue as new
    update public.jobs set first_seen_at = least(now(), coalesce(published_at, last_checked_at));
  end if;
end $$;
create index if not exists jobs_first_seen_idx on public.jobs (first_seen_at desc) where status = 'open';

-- ───────── saved searches ─────────
alter table public.saved_searches
  add column if not exists name text,
  add column if not exists alerts_enabled boolean not null default false,
  add column if not exists frequency text not null default 'daily',
  add column if not exists alert_cursor timestamptz,
  add column if not exists last_alert_run_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();
alter table public.saved_searches
  drop constraint if exists saved_searches_name_len,
  drop constraint if exists saved_searches_frequency_check,
  drop constraint if exists saved_searches_query_size;
alter table public.saved_searches
  add constraint saved_searches_name_len check (name is null or char_length(btrim(name)) between 1 and 80),
  add constraint saved_searches_frequency_check check (frequency in ('instant', 'daily', 'weekly')),
  add constraint saved_searches_query_size check (octet_length(query::text) <= 12288);

drop trigger if exists saved_searches_touch on public.saved_searches;
create trigger saved_searches_touch before update on public.saved_searches
  for each row execute function public.set_updated_at();

-- The cursor belongs to the alert run: it restarts at "now" when alerts are switched on or the criteria change, so enabling a search never floods
-- the user with the existing catalogue. SECURITY INVOKER; the client also has no UPDATE privilege on the cursor columns (see the grants below).
create or replace function public.saved_search_alert_state() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.alert_cursor := case when new.alerts_enabled then pg_catalog.now() end;
    new.last_alert_run_at := null;
  elsif new.alerts_enabled and (not old.alerts_enabled or new.query is distinct from old.query) then
    new.alert_cursor := pg_catalog.now();
    new.last_alert_run_at := null;
  end if;
  return new;
end $$;
revoke all on function public.saved_search_alert_state() from public, anon, authenticated;
drop trigger if exists saved_searches_alert_state on public.saved_searches;
create trigger saved_searches_alert_state before insert or update on public.saved_searches
  for each row execute function public.saved_search_alert_state();

-- a person edits the search; the alert machinery's own columns are not theirs to write
revoke insert, update on public.saved_searches from authenticated;
grant insert (user_id, name, query, alerts_enabled, frequency) on public.saved_searches to authenticated;
grant update (name, query, alerts_enabled, frequency) on public.saved_searches to authenticated;

-- ───────── notifications ─────────
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null default 'new_job' check (kind in ('new_job')),
  job_id uuid references public.jobs(id) on delete set null,
  search_ids uuid[] not null default '{}' check (cardinality(search_ids) <= 20),
  title text not null check (char_length(title) between 1 and 300),
  company text check (company is null or char_length(company) <= 200),
  original_url text check (original_url is null or char_length(original_url) <= 2048),
  source_id text,
  country char(2),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  dismissed_at timestamptz,
  unique (user_id, job_id)
);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);
create index if not exists notifications_job_idx on public.notifications (job_id);
alter table public.notifications enable row level security;
drop policy if exists notifications_owner on public.notifications;
create policy notifications_owner on public.notifications for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- reading, and marking as read / dismissed. No INSERT (only the alert run writes) and no DELETE (a dismissed row is kept for a while so the same job
-- is not announced again).
revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
grant update (read_at, dismissed_at) on public.notifications to authenticated;

-- ───────── hidden jobs ─────────
create table if not exists public.hidden_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  job_key text not null check (char_length(job_key) between 3 and 400),
  source_id text not null check (char_length(source_id) between 1 and 80),
  external_id text not null check (char_length(external_id) between 1 and 300),
  title text not null check (char_length(title) <= 300),
  company text check (company is null or char_length(company) <= 200),
  original_url text check (original_url is null or char_length(original_url) <= 2048),
  hidden_at timestamptz not null default now(),
  unique (user_id, job_key)
);
create index if not exists hidden_jobs_user_idx on public.hidden_jobs (user_id, hidden_at desc);
alter table public.hidden_jobs enable row level security;
drop policy if exists hidden_jobs_owner on public.hidden_jobs;
create policy hidden_jobs_owner on public.hidden_jobs for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke all on public.hidden_jobs from anon, authenticated;
grant select, insert, delete on public.hidden_jobs to authenticated;
drop trigger if exists hidden_jobs_quota on public.hidden_jobs;
create trigger hidden_jobs_quota before insert on public.hidden_jobs
  for each row execute function public.enforce_row_quota(2000, 'job_key');

-- ───────── applications: pipeline stages and dates ─────────
alter table public.applications drop constraint if exists applications_stage_check;
alter table public.applications add constraint applications_stage_check
  check (stage in ('interested', 'applied', 'screening', 'interview', 'offer', 'hired', 'rejected', 'withdrawn', 'closed'));
alter table public.applications
  add column if not exists interview_at timestamptz,
  add column if not exists follow_up_at timestamptz;

-- The retention restore re-inserts deleted jobs with an explicit column list: carry first_seen_at too (an export taken before this migration has no
-- such key, then the last check is used), otherwise a restored job would look "new" to the alert run.
create or replace function ops.jobicy_retention_restore(p_confirm text, p_data jsonb) returns text
language plpgsql set search_path = pg_catalog as $$
declare v_ins int; v_upd int;
begin
  if p_confirm is distinct from 'EU-AUTORIZO-A-RESTAURACAO' then
    raise exception 'ops.jobicy_retention_restore: sem a frase de autorizacao do proprietario';
  end if;
  if p_data is null or jsonb_typeof(p_data) <> 'array' then raise exception 'ops.jobicy_retention_restore: esperava um array JSON (a saida de ops.jobicy_retention_export)'; end if;

  with src as (select * from jsonb_populate_recordset(null::public.jobs, p_data)),
  ins as (
    insert into public.jobs (id, source_id, external_id, cluster_id, company, title, description, country, city, language, work_mode, contract_type,
                             salary_min, salary_max, salary_currency, salary_period, published_at, last_checked_at, requirements, skills,
                             original_url, apply_url, status, geo_restrictions, isco08, fingerprint, canonical_url, first_seen_at)
    select id, source_id, external_id, null, company, title, description, country, city, language, work_mode, contract_type,
           salary_min, salary_max, salary_currency, salary_period, published_at, last_checked_at, requirements, skills,
           original_url, apply_url, status, geo_restrictions, isco08, fingerprint, canonical_url, coalesce(first_seen_at, last_checked_at) from src
    on conflict do nothing returning 1)
  select count(*) into v_ins from ins;

  with src as (select * from jsonb_populate_recordset(null::public.jobs, p_data)),
  upd as (
    update public.jobs j set description = s.description, requirements = s.requirements, skills = s.skills
      from src s where j.id = s.id and j.description = '' and s.description <> '' returning 1)
  select count(*) into v_upd from upd;

  delete from ops.job_tombstones t
   using (select source_id, external_id from jsonb_populate_recordset(null::public.jobs, p_data)) s
   where t.source_id = s.source_id and t.external_id = s.external_id
     and exists (select 1 from public.jobs j where j.source_id = s.source_id and j.external_id = s.external_id);
  return 'ok:reinserted=' || v_ins || ',restored=' || v_upd;
end $$;
revoke all on function ops.jobicy_retention_restore(text, jsonb) from public, anon, authenticated, service_role;

-- ───────── ops: matching and the alert run ─────────
create table if not exists ops.alert_runs (
  id bigint generated always as identity primary key,
  ran_at timestamptz not null default now(),
  due_searches int not null default 0,
  notified int not null default 0,
  capped int not null default 0,
  outcome text not null
);
alter table ops.alert_runs enable row level security;  -- no policy: nobody but the owner reads it
revoke all on ops.alert_runs from public, anon, authenticated, service_role;

-- "title contains" without letting % and _ in the needle act as wildcards
create or replace function ops.title_has(p_title text, p_needle text) returns boolean
language sql immutable set search_path = pg_catalog as $$
  select coalesce(p_title, '') ilike '%' || replace(replace(replace(p_needle, E'\\', E'\\\\'), '%', E'\\%'), '_', E'\\_') || '%'
$$;

-- The same rules the app applies to the catalogue (SupabaseJobCatalogRepository.search), evaluated for one job against the compiled `match`
-- block of a saved search. Everything is optional; an empty block matches every job.
--   match = { term, alts[], title_groups[[kw..],[kw..]], country, cc[], regions[], modes[], days, salary }
-- term: websearch over title+company+description, OR the term inside the title or city, OR any other name of the profession inside the title.
-- title_groups: every group must match (a title contains ANY keyword of the group); two groups = a refinement (specialty inside its parent).
-- country: the job is in it, lists it as eligible, or is remote and marked Anywhere. cc/regions: the same for a continent (ignored when country is set).
create or replace function ops.alert_matches(j public.jobs, q jsonb) returns boolean
language plpgsql stable set search_path = pg_catalog as $$
declare
  m jsonb := coalesce(q -> 'match', '{}'::jsonb);
  v_term text := nullif(btrim(coalesce(m ->> 'term', '')), '');
  v_country text := nullif(upper(btrim(coalesce(m ->> 'country', ''))), '');
  v_cc text[];
  v_modes text[];
  v_days int;
  g jsonb;
  k text;
  hit boolean;
begin
  if v_term is not null then
    hit := j.search @@ websearch_to_tsquery('simple', v_term)
        or ops.title_has(j.title, v_term)
        or ops.title_has(j.city, v_term);
    if not hit then
      for k in select jsonb_array_elements_text(coalesce(m -> 'alts', '[]'::jsonb)) loop
        if ops.title_has(j.title, k) then hit := true; exit; end if;
      end loop;
    end if;
    if not coalesce(hit, false) then return false; end if;
  end if;

  if v_country is not null then
    if not coalesce(j.country::text = v_country
                    or coalesce(j.geo_restrictions, '{}') @> array[v_country]
                    or (j.work_mode = 'remote' and coalesce(j.geo_restrictions, '{}') @> array['Anywhere']), false) then
      return false;
    end if;
  elsif jsonb_typeof(m -> 'cc') = 'array' and jsonb_array_length(m -> 'cc') > 0 then
    select array_agg(upper(x)) into v_cc from jsonb_array_elements_text(m -> 'cc') x;
    if not coalesce(j.country::text = any (v_cc)
                    or coalesce(j.geo_restrictions, '{}') && (v_cc || coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(m -> 'regions', '[]'::jsonb)) x), '{}')), false) then
      return false;
    end if;
  end if;

  if jsonb_typeof(m -> 'modes') = 'array' and jsonb_array_length(m -> 'modes') > 0 then
    select array_agg(x) into v_modes from jsonb_array_elements_text(m -> 'modes') x;
    if not coalesce(j.work_mode = any (v_modes), false) then return false; end if;
  end if;

  if jsonb_typeof(m -> 'title_groups') = 'array' then
    for g in select jsonb_array_elements(m -> 'title_groups') loop
      hit := false;
      for k in select jsonb_array_elements_text(g) loop
        if ops.title_has(j.title, k) then hit := true; exit; end if;
      end loop;
      if not hit then return false; end if;
    end loop;
  end if;

  if jsonb_typeof(m -> 'days') = 'number' then
    v_days := (m ->> 'days')::int;
    if v_days > 0 and not coalesce(j.published_at >= now() - make_interval(days => v_days), false) then return false; end if;
  end if;

  if m ->> 'salary' = 'true' then
    if not ((j.salary_min is not null or j.salary_max is not null) and j.salary_currency is not null and j.salary_period is not null) then
      return false;
    end if;
  end if;
  return true;
end $$;

-- One pass over every due saved search. Idempotent per job (unique (user_id, job_id) + same-fingerprint guard), so running it twice, or
-- overlapping the window of the previous run, never announces a job twice. A user who switched notifications off still has the cursor moved,
-- so switching them back on does not deliver a backlog.
create or replace function ops.alerts_run(p_max_per_search int default 25) returns text
language plpgsql set search_path = pg_catalog as $$
declare
  v_now timestamptz := clock_timestamp();
  s record;
  r record;
  v_enabled boolean;
  v_cursor timestamptz;
  v_seen int;
  v_rows int;
  v_last timestamptz;
  v_capped boolean;
  v_due int := 0;
  v_notified int := 0;
  v_capped_n int := 0;
  v_out text;
begin
  if p_max_per_search < 1 or p_max_per_search > 100 then raise exception 'ops.alerts_run: p_max_per_search between 1 and 100'; end if;
  if not pg_try_advisory_xact_lock(hashtext('ops.alerts_run')) then
    insert into ops.alert_runs (outcome) values ('skipped:locked');
    return 'skipped:locked';
  end if;

  for s in
    select ss.id, ss.user_id, ss.query, ss.frequency, ss.alert_cursor
      from public.saved_searches ss
     where ss.alerts_enabled
       and (ss.last_alert_run_at is null
            or v_now - ss.last_alert_run_at >= case ss.frequency
                 when 'instant' then interval '0'
                 when 'daily' then interval '23 hours'
                 else interval '6 days 23 hours' end)
     order by ss.user_id, ss.id
  loop
    v_due := v_due + 1;
    v_cursor := coalesce(s.alert_cursor, v_now);
    v_enabled := coalesce((select (up.settings -> 'notifications' ->> 'enabled')::boolean from public.user_preferences up where up.user_id = s.user_id), true);
    v_seen := 0;
    v_last := null;
    v_capped := false;

    if v_enabled then
      for r in
        select j.id, j.title, j.company, j.original_url, j.country, j.source_id, j.first_seen_at, j.fingerprint
          from public.jobs j
          join public.job_sources src on src.id = j.source_id
         where j.first_seen_at > v_cursor
           and j.status = 'open'
           and j.last_checked_at >= v_now - interval '72 hours'
           and (j.published_at is null or j.published_at >= v_now - interval '60 days')
           and src.can_redistribute and src.status in ('READY', 'CONDITIONAL')
           and not exists (select 1 from public.hidden_jobs h where h.user_id = s.user_id and h.job_key = j.source_id || ':' || j.external_id)
           and ops.alert_matches(j, s.query)
         order by j.first_seen_at asc, j.id
         limit p_max_per_search + 1
      loop
        v_seen := v_seen + 1;
        if v_seen > p_max_per_search then v_capped := true; exit; end if;
        v_last := r.first_seen_at;
        -- the same posting under another source (same fingerprint) was already announced, in an earlier pass or a moment ago in this one
        if exists (select 1 from public.notifications n join public.jobs j2 on j2.id = n.job_id
                    where n.user_id = s.user_id and j2.fingerprint = r.fingerprint and n.job_id <> r.id) then
          continue;
        end if;
        insert into public.notifications as n (user_id, job_id, search_ids, title, company, original_url, source_id, country)
        values (s.user_id, r.id, array[s.id], left(r.title, 300), left(nullif(r.company, ''), 200), left(r.original_url, 2048), r.source_id, r.country)
        on conflict (user_id, job_id) do update
          set search_ids = (select array_agg(distinct x) from unnest(n.search_ids || excluded.search_ids) x)
        where not (s.id = any (n.search_ids));
        get diagnostics v_rows = row_count;
        v_notified := v_notified + v_rows;
      end loop;
    end if;

    if v_capped then
      v_capped_n := v_capped_n + 1;
      -- come back for the rest on the next pass, starting after the last job handled
      update public.saved_searches set alert_cursor = v_last where id = s.id;
    elsif v_enabled then
      -- a 15-minute overlap covers jobs whose insert committed after the cursor's clock; the unique key makes the re-read harmless
      update public.saved_searches set alert_cursor = v_now - interval '15 minutes', last_alert_run_at = v_now where id = s.id;
    else
      -- notifications are off: skip what arrived meanwhile, so switching them on later delivers no backlog
      update public.saved_searches set alert_cursor = v_now, last_alert_run_at = v_now where id = s.id;
    end if;
  end loop;

  -- housekeeping: dismissed or old notifications go after 60 days (long after the 15-minute overlap that could re-announce a job); at most 300 per user
  delete from public.notifications where created_at < v_now - interval '60 days';
  delete from public.notifications where id in (
    select id from (select id, row_number() over (partition by user_id order by created_at desc) as rn from public.notifications) x where x.rn > 300);
  delete from ops.alert_runs where ran_at < v_now - interval '30 days';

  v_out := format('ok due=%s notified=%s capped=%s', v_due, v_notified, v_capped_n);
  insert into ops.alert_runs (due_searches, notified, capped, outcome) values (v_due, v_notified, v_capped_n, 'ok');
  return v_out;
end $$;

revoke all on function ops.title_has(text, text) from public, anon, authenticated, service_role;
revoke all on function ops.alert_matches(public.jobs, jsonb) from public, anon, authenticated, service_role;
revoke all on function ops.alerts_run(int) from public, anon, authenticated, service_role;
comment on function ops.alerts_run(int) is 'Hourly pass that turns new matching jobs into in-app notifications. Scheduled by scripts/supabase/ops/enable_alerts_cron.sql. Migration 20261023000000.';
