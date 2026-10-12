-- Migration 15: the same in-database revalidation as the Platsbanken (migration 13), for Jobs.co.nz (New Zealand).
--
-- ops.jobsconz_revalidate_start() takes the lease and queues one GET https://jobs.co.nz/api/v1/jobs/{id} per stored job (100 per run, oldest verification first; the key-less limit is 120 requests a minute, so a run never exceeds it);
-- ops.jobsconz_revalidate_collect() reads the answers: 404/410 -> closed ("No live listing with that id"); 200 -> open + last_checked_at = now(), unless the
-- listing's own expires_at has passed (then closed); an 'unknown' job that answers 200 comes back to 'open'; 403, 429, 5xx, timeout or an unreadable answer change nothing.
-- Nothing is scheduled here (scripts/supabase/ops/enable_jobsconz_revalidation_cron.sql). Rollback: supabase/rollback/20261022000000_jobsconz_revalidation.down.sql.

create function ops.jobsconz_revalidate_start() returns text language plpgsql as $$
declare
  c_source  constant text     := 'jobsconz';
  c_ttl     constant interval := interval '20 minutes';   -- a 'running' row older than this is a crashed run (the Worker uses the same)
  c_min     constant interval := interval '60 minutes';   -- one automated pass per hour and source, shared with the Worker and GitHub Actions
  c_per_run constant int      := 100;                     -- 100 listings per run: pg_net sends them at once and the limit without a key is 120 requests a minute per IP
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
      url := 'https://jobs.co.nz/api/v1/jobs/' || v_ids[i],
      headers := jsonb_build_object('Accept', 'application/json', 'User-Agent', 'OrbiJob-revalidate/1 (+https://github.com/Lucasdiogof/orbijob)'),
      timeout_milliseconds := 20000);
    insert into ops.revalidation_batches (run_id, batch, request_id, external_ids) values (v_id, i - 1, v_req, array[v_ids[i]]);
  end loop;
  return 'started:' || v_n || ' jobs in ' || v_n || ' request(s)';
end $$;

create function ops.jobsconz_revalidate_collect() returns text language plpgsql as $$
declare
  c_source  constant text     := 'jobsconz';
  c_timeout constant interval := interval '30 minutes';   -- answers that never came are timeouts
  v_now     timestamptz := now();
  r         record;
  v_out     text := '';
  v_pending int;
  v_ok int; v_fail int; v_closed_total int; v_err text;
begin
  if not pg_try_advisory_xact_lock(hashtext('orbijob:jobsconz-revalidate-collect')) then return 'skipped:locked'; end if;

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
                   when j is null or jsonb_typeof(j -> 'data') <> 'object' or (j #>> '{data,id}') is null then null
                   when (j #>> '{data,expires_at}') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}'
                        and substring(j #>> '{data,expires_at}' from 1 for 19)::timestamp < (v_now at time zone 'UTC') then 'closed'
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

revoke all on function ops.jobsconz_revalidate_start() from public, anon, authenticated, service_role;
revoke all on function ops.jobsconz_revalidate_collect() from public, anon, authenticated, service_role;
