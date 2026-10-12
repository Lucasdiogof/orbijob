-- Migration 13: (1) the retention gives 'unknown' jobs more time before compacting them; (2) the Platsbanken (jobtech) is revalidated INSIDE the database.
--
-- 1. Retention. Migration 12 treated 'unknown' (a job that nothing proves gone) exactly like 'closed': compacted after 14 days. A compacted job has an empty
--    description, so a job that comes back (a 200 from the source, or a new listing in a feed) would reappear without text. Now an 'unknown' job keeps its
--    text for 30 days (never less than the closed-job setting), is still deleted after 90 days when nobody references it, and a job referenced by a favourite,
--    a view, an application or a cluster is never deleted. 'closed' is unchanged (14 / 90). Open jobs are never touched.
-- 2. Why revalidate inside the database: GitHub Actions dropped most scheduled runs of this repository (docs/GITHUB_SCHEDULE_DIAGNOSTIC.md and the 12/10 audit:
--    Arbeitnow 08:23/14:23, Platsbanken 09:31/15:31 and 12:47 never started). Supabase Cron is part of the project, free, and does not drop runs. Same design as the
--    Jobicy one (migration 8): ops.jobtech_revalidate_start() takes the lease and queues one GET /ad/{id} per stored job (oldest verification first, 600 per run),
--    ops.jobtech_revalidate_collect() reads the answers a few minutes later:
--      * 404/410                                            -> closed   (the ad is not published any more)
--      * 200 with removed=true, or publication ended > 36 h ago -> closed
--      * 200 otherwise                                      -> open + last_checked_at = now(); an 'unknown' job that answers 200 comes BACK to 'open'
--      * 403, 429, 5xx, timeout, unreadable answer           -> nothing changes (never a closure, never a confirmation)
--    It imports nothing, deletes nothing, never touches job_sources or user tables. NOTHING IS SCHEDULED HERE (scripts/supabase/ops/enable_jobtech_revalidation_cron.sql).
-- Rollback: supabase/rollback/20261020000000_jobtech_revalidation.down.sql (restores migration 12's retention and drops the two functions).

create or replace function ops.jobicy_retention_plan(p_compact_after interval default interval '14 days', p_delete_after interval default interval '90 days')
returns table (layer text, jobs bigint) language sql stable set search_path = pg_catalog as $$
  with j as (
    select status, last_checked_at, (description <> '' or requirements <> '{}' or skills <> '{}') as has_body,
           not (exists (select 1 from public.saved_jobs s where s.job_id = jobs.id)
             or exists (select 1 from public.viewed_jobs v where v.job_id = jobs.id)
             or exists (select 1 from public.applications a where a.job_id = jobs.id)
             or exists (select 1 from public.job_clusters c where c.canonical_job_id = jobs.id)) as unreferenced
      from public.jobs)
  select 'open'::text,                         count(*) filter (where status = 'open') from j
  union all select 'closed_recent',            count(*) filter (where status in ('closed', 'unknown') and now() - last_checked_at <= (case when status = 'unknown' then greatest(p_compact_after, interval '30 days') else p_compact_after end)) from j
  union all select 'closed_to_compact',        count(*) filter (where status in ('closed', 'unknown') and now() - last_checked_at > (case when status = 'unknown' then greatest(p_compact_after, interval '30 days') else p_compact_after end) and has_body) from j
  union all select 'closed_compacted',         count(*) filter (where status in ('closed', 'unknown') and now() - last_checked_at > (case when status = 'unknown' then greatest(p_compact_after, interval '30 days') else p_compact_after end) and not has_body) from j
  union all select 'closed_to_delete',         count(*) filter (where status in ('closed', 'unknown') and now() - last_checked_at > p_delete_after and unreferenced) from j
  union all select 'closed_kept_referenced',   count(*) filter (where status in ('closed', 'unknown') and now() - last_checked_at > p_delete_after and not unreferenced) from j
$$;



create or replace function ops.jobicy_retention_apply(
  p_confirm text,
  p_compact_after interval default interval '14 days',
  p_delete_after interval default interval '90 days',
  p_batch int default 200,
  p_allow_large boolean default false
) returns text language plpgsql set search_path = pg_catalog as $$
declare
  v_compacted int := 0;
  v_deleted int := 0;
  v_closed bigint;
  v_candidates bigint;
  v_out text;
begin
  if p_confirm is distinct from 'EU-AUTORIZO-A-RETENCAO' then
    raise exception 'ops.jobicy_retention_apply: sem a frase de autorizacao do proprietario';
  end if;
  if p_compact_after < interval '7 days' then raise exception 'ops.jobicy_retention_apply: compact_after minimo e 7 dias'; end if;
  if p_delete_after < interval '30 days' or p_delete_after < p_compact_after + interval '14 days' then
    raise exception 'ops.jobicy_retention_apply: delete_after minimo e 30 dias e 14 dias depois de compact_after';
  end if;
  if p_batch < 1 or p_batch > 500 then raise exception 'ops.jobicy_retention_apply: batch entre 1 e 500'; end if;

  if not pg_try_advisory_xact_lock(hashtext('ops.jobicy_retention')) then
    insert into ops.retention_runs (outcome, compact_after, delete_after) values ('skipped:locked', p_compact_after, p_delete_after);
    return 'skipped:locked';
  end if;

  select count(*) filter (where status in ('closed', 'unknown')) into v_closed from public.jobs;
  select coalesce(sum(jobs), 0) into v_candidates from ops.jobicy_retention_plan(p_compact_after, p_delete_after) where layer in ('closed_to_compact', 'closed_to_delete');
  if not p_allow_large and v_candidates > greatest(50, v_closed / 5) then
    v_out := 'refused:too_many_candidates(' || v_candidates || ' of ' || v_closed || ' closed)';
    insert into ops.retention_runs (outcome, compact_after, delete_after) values (v_out, p_compact_after, p_delete_after);
    return v_out;
  end if;

  -- DELETE first (oldest closed, unreferenced), recording a tombstone for each; skip locked rows so a concurrent writer is never waited on.
  with d as (
    select j.id from public.jobs j
     where j.status in ('closed', 'unknown') and now() - j.last_checked_at > p_delete_after
       and not exists (select 1 from public.saved_jobs s where s.job_id = j.id)
       and not exists (select 1 from public.viewed_jobs v where v.job_id = j.id)
       and not exists (select 1 from public.applications a where a.job_id = j.id)
       and not exists (select 1 from public.job_clusters c where c.canonical_job_id = j.id)
     order by j.last_checked_at limit p_batch for update skip locked),
  del as (
    delete from public.jobs j using d
     where j.id = d.id and j.status in ('closed', 'unknown')
       -- re-checked at delete time: a reference committed after the candidate list was read must still stop the delete (and the cascade)
       and not exists (select 1 from public.saved_jobs s where s.job_id = j.id)
       and not exists (select 1 from public.viewed_jobs v where v.job_id = j.id)
       and not exists (select 1 from public.applications a where a.job_id = j.id)
       and not exists (select 1 from public.job_clusters c where c.canonical_job_id = j.id)
    returning j.source_id, j.external_id),
  tomb as (
    insert into ops.job_tombstones (source_id, external_id) select source_id, external_id from del on conflict do nothing returning 1)
  select count(*) into v_deleted from del;

  -- COMPACT: empty the heavy fields of closed jobs that still carry them (the generated search column follows).
  with c as (
    select j.id from public.jobs j
     where j.status in ('closed', 'unknown') and now() - j.last_checked_at > (case when j.status = 'unknown' then greatest(p_compact_after, interval '30 days') else p_compact_after end)
       and (j.description <> '' or j.requirements <> '{}' or j.skills <> '{}')
     order by j.last_checked_at limit p_batch for update skip locked),
  upd as (
    update public.jobs j set description = '', requirements = '{}', skills = '{}'
      from c where j.id = c.id and j.status in ('closed', 'unknown')
    returning 1)
  select count(*) into v_compacted from upd;

  v_out := 'ok:compacted=' || v_compacted || ',deleted=' || v_deleted;
  insert into ops.retention_runs (outcome, compacted, deleted, compact_after, delete_after) values (v_out, v_compacted, v_deleted, p_compact_after, p_delete_after);
  return v_out;
end $$;



create or replace function ops.jobicy_retention_export(
  p_compact_after interval default interval '14 days',
  p_delete_after interval default interval '90 days',
  p_limit int default 1000
) returns jsonb language sql stable set search_path = pg_catalog as $$
  select coalesce(jsonb_agg(to_jsonb(j) - 'search' order by j.last_checked_at), '[]'::jsonb)
    from (select * from public.jobs
           where status in ('closed', 'unknown') and now() - last_checked_at > (case when status = 'unknown' then greatest(p_compact_after, interval '30 days') else p_compact_after end)
             and (description <> '' or requirements <> '{}' or skills <> '{}'
                  or (now() - last_checked_at > p_delete_after
                      and not exists (select 1 from public.saved_jobs s where s.job_id = jobs.id)
                      and not exists (select 1 from public.viewed_jobs v where v.job_id = jobs.id)
                      and not exists (select 1 from public.applications a where a.job_id = jobs.id)
                      and not exists (select 1 from public.job_clusters c where c.canonical_job_id = jobs.id)))
           order by last_checked_at limit least(greatest(p_limit, 1), 5000)) j
$$;





create function ops.jobtech_revalidate_start() returns text language plpgsql as $$
declare
  c_source  constant text     := 'jobtech';
  c_ttl     constant interval := interval '20 minutes';   -- a 'running' row older than this is a crashed run (the Worker uses the same)
  c_min     constant interval := interval '60 minutes';   -- one automated pass per hour and source, shared with the Worker and GitHub Actions
  c_per_run constant int      := 600;                     -- 600 ads per run, oldest verification first
  v_now     timestamptz := now();
  v_id      uuid := ops.slot_run_id(c_source, v_now);
  v_ids     text[];
  v_req     bigint;
  v_n       int;
  i         int;
begin
  update public.sync_runs set status = 'failed', finished_at = v_now, error_class = 'stale_lock'
   where source_id = c_source and status = 'running' and v_now - started_at >= c_ttl;
  if exists (select 1 from public.sync_runs where source_id = c_source and status = 'running') then
    return 'skipped:running';
  end if;
  if exists (select 1 from public.sync_runs
              where source_id = c_source and status <> 'running'
                and coalesce(error_class, '') not in ('lost_lease', 'stale_lock')
                and started_at > v_now - c_min + interval '1 millisecond' and started_at <= v_now) then
    return 'skipped:too_soon';
  end if;
  insert into public.sync_runs (id, source_id, scope, started_at, status)
  values (v_id, c_source, 'revalidate', v_now, 'running')
  on conflict (id) do nothing;
  if not found then return 'skipped:lost_race'; end if;

  -- the stored jobs that are open OR unknown (an unknown one that is still published comes back), oldest verification first; only plain numeric ids reach a URL
  select coalesce(array_agg(external_id order by last_checked_at nulls first, external_id), '{}') into v_ids from (
    select external_id, last_checked_at from public.jobs
     where source_id = c_source and status in ('open', 'unknown') and external_id ~ '^[1-9][0-9]{0,15}$'
     order by last_checked_at nulls first, external_id
     limit c_per_run) t;
  v_n := coalesce(array_length(v_ids, 1), 0);
  if v_n = 0 then
    update public.sync_runs set status = 'ok', finished_at = now() where id = v_id;
    return 'ok:nothing_to_revalidate';
  end if;

  for i in 1 .. v_n loop
    v_req := net.http_get(
      url := 'https://jobsearch.api.jobtechdev.se/ad/' || v_ids[i],
      headers := jsonb_build_object('Accept', 'application/json', 'User-Agent', 'OrbiJob-revalidate/1 (+https://github.com/Lucasdiogof/orbijob)'),
      timeout_milliseconds := 20000);
    insert into ops.revalidation_batches (run_id, batch, request_id, external_ids) values (v_id, i - 1, v_req, array[v_ids[i]]);
  end loop;
  return 'started:' || v_n || ' jobs in ' || v_n || ' request(s)';
end $$;

create function ops.jobtech_revalidate_collect() returns text language plpgsql as $$
declare
  c_source  constant text     := 'jobtech';
  c_timeout constant interval := interval '30 minutes';   -- answers that never came are timeouts
  v_now     timestamptz := now();
  r         record;
  v_out     text := '';
  v_pending int;
  v_ok int; v_fail int; v_closed_total int; v_err text;
begin
  if not pg_try_advisory_xact_lock(hashtext('orbijob:jobtech-revalidate-collect')) then return 'skipped:locked'; end if;

  for r in
    select s.id, s.started_at from public.sync_runs s
     where s.source_id = c_source and s.scope = 'revalidate' and s.status = 'running'
       and exists (select 1 from ops.revalidation_batches bb where bb.run_id = s.id)
     order by s.started_at
  loop
    select count(*) into v_pending
      from ops.revalidation_batches bb
     where bb.run_id = r.id and bb.collected_at is null
       and not exists (select 1 from net._http_response x where x.id = bb.request_id);
    if v_pending > 0 and v_now - r.started_at < c_timeout then
      v_out := v_out || r.id || ':waiting(' || v_pending || ');';
      continue;
    end if;

    -- one set-based pass over the run: classify each answer, apply the decisions, record the outcome
    with ans as (
      select b.run_id, b.batch, b.external_ids[1] as ext, x.status_code as code,
             case when x.id is null or coalesce(x.timed_out, false) then 'timeout'
                  when x.status_code in (404, 410) then 'applied'
                  when x.status_code = 200 and v.verdict is not null then 'applied'
                  when x.status_code = 200 then 'bad_response'
                  else 'http_error' end as outcome,
             case when x.id is null or coalesce(x.timed_out, false) then null
                  when x.status_code in (404, 410) then 'closed'
                  when x.status_code = 200 then v.verdict end as verdict
        from ops.revalidation_batches b
        left join lateral (select * from net._http_response r2 where r2.id = b.request_id order by r2.created desc limit 1) x on true
        left join lateral (
          select case
                   when j is null or jsonb_typeof(j) <> 'object' or (j ->> 'id') is null then null
                   when (j -> 'removed') = 'true'::jsonb then 'closed'
                   when (j ->> 'last_publication_date') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'
                        and substring(j ->> 'last_publication_date' from 1 for 19)::timestamp < (v_now at time zone 'Europe/Stockholm') - interval '36 hours' then 'closed'
                   else 'open' end as verdict
            from (select case when x.status_code = 200 and pg_input_is_valid(x.content, 'jsonb') then x.content::jsonb end as j) p
        ) v on true
       where b.run_id = r.id and b.collected_at is null
    ), closed as (
      update public.jobs j set status = 'closed', last_checked_at = v_now
        from ans a where a.verdict = 'closed' and j.source_id = c_source and j.external_id = a.ext and j.status in ('open', 'unknown')
      returning 1
    ), conf as (
      update public.jobs j set status = 'open', last_checked_at = v_now
        from ans a where a.verdict = 'open' and j.source_id = c_source and j.external_id = a.ext and j.status in ('open', 'unknown')
      returning 1
    )
    update ops.revalidation_batches b
       set collected_at = v_now, http_status = a.code, outcome = a.outcome,
           closed = case when a.verdict = 'closed' then 1 else 0 end, confirmed = case when a.verdict = 'open' then 1 else 0 end,
           unknown = case when a.verdict in ('closed', 'open') then 0 else 1 end
      from ans a where b.run_id = a.run_id and b.batch = a.batch;

    select count(*) filter (where outcome = 'applied'), count(*) filter (where outcome <> 'applied'), coalesce(sum(closed), 0),
           (array_agg(case outcome when 'http_error' then 'http_' || coalesce(http_status::text, 'error')
                                   when 'timeout' then 'timeout'
                                   when 'bad_response' then 'network_or_parse' end
                       order by batch) filter (where outcome <> 'applied'))[1]
      into v_ok, v_fail, v_closed_total, v_err
      from ops.revalidation_batches where run_id = r.id;
    update public.sync_runs
       set status = case when v_fail = 0 then 'ok' when v_ok > 0 then 'partial' else 'failed' end,
           finished_at = v_now, fetched = 0, upserted = 0, duplicates = 0, closed = v_closed_total,
           http_errors = v_fail, error_class = v_err
     where id = r.id;
    v_out := v_out || r.id || ':' || (case when v_fail = 0 then 'ok' when v_ok > 0 then 'partial' else 'failed' end) || ';';
  end loop;

  delete from ops.revalidation_batches where requested_at < v_now - interval '30 days';
  return coalesce(nullif(v_out, ''), 'nothing_to_collect');
end $$;

revoke all on function ops.jobtech_revalidate_start() from public, anon, authenticated, service_role;
revoke all on function ops.jobtech_revalidate_collect() from public, anon, authenticated, service_role;
revoke all on function ops.jobicy_retention_plan(interval, interval) from public, anon, authenticated, service_role;
revoke all on function ops.jobicy_retention_export(interval, interval, int) from public, anon, authenticated, service_role;
revoke all on function ops.jobicy_retention_apply(text, interval, interval, int, boolean) from public, anon, authenticated, service_role;
