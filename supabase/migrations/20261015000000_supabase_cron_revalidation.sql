-- Revalidation of the stored Jobicy jobs INSIDE the database (pg_cron + pg_net), with no key, no secret and no Edge Function.
--
-- Why this exists: the GitHub Actions schedule never fired for this repository (docs/GITHUB_SCHEDULE_DIAGNOSTIC.md), and the Cloudflare
-- cron triggers of the free account are taken. Supabase Cron is part of the project, free, and the job lives next to the data.
--
-- Why no Edge Function: the function would need the project's service key as a secret, and the key injected by the platform is the
-- legacy service_role JWT that was exposed on 2026-10-10. This design needs no credential at all: the Jobicy status endpoint is public
-- and the writes are done by the database owner role that pg_cron runs as.
--
-- What it does (same decisions as worker/src/sync.ts `closeStale` in `revalidate` mode, covered by the same cases in the tests):
--   * asks the official status endpoint about the jobs ALREADY stored and open (oldest verification first, 100 ids per request);
--   * a job answered "closed" is closed; a job answered "active" gets last_checked_at = now(); "unknown", an id that is not answered,
--     an HTTP error, a timeout or an unreadable answer change NOTHING (never a closure);
--   * imports nothing, deletes nothing, never touches job_sources/can_redistribute or any user table;
--   * one run at a time and one per hour: the SAME deterministic lease as the Worker (sync_runs.id derived from source and hour), so
--     a manual or GitHub Actions run in the same hour makes this one stand down, and vice versa.
--
-- Two phases, because pg_net sends a request only when the transaction commits and answers asynchronously:
--   ops.jobicy_revalidate_start()    takes the lease, queues the status requests;
--   ops.jobicy_revalidate_collect()  reads the answers, applies the decisions, closes the run record. Run a few minutes later.
-- NOTHING IS SCHEDULED HERE. Scheduling is a separate, guarded step: scripts/supabase/ops/enable_revalidation_cron.sql
-- (undo: scripts/supabase/ops/disable_revalidation_cron.sql). Rollback of this migration: supabase/rollback/20261015000000_*.down.sql.

-- Extensions: installed where the platform offers them (hosted Supabase). A plain PostgreSQL (the CI databases) does not, and the
-- functions below are late-bound, so the migration still applies; the tests provide a stand-in for the `net` schema.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
  end if;
end $$;

create schema if not exists ops;
revoke all on schema ops from public;
revoke all on schema ops from anon, authenticated, service_role;

-- One row per queued status request: what was asked, what came back, what was decided. Counts only, no job content.
create table ops.revalidation_batches (
  run_id        uuid        not null references public.sync_runs(id) on delete cascade,
  batch         int         not null,
  request_id    bigint      not null,
  external_ids  text[]      not null,
  requested_at  timestamptz not null default now(),
  collected_at  timestamptz,
  http_status   int,
  outcome       text check (outcome in ('applied', 'http_error', 'timeout', 'bad_response')),
  closed        int         not null default 0,
  confirmed     int         not null default 0,
  unknown       int         not null default 0,
  primary key (run_id, batch)
);
alter table ops.revalidation_batches enable row level security;  -- no policy: nobody but the owner reads it
revoke all on ops.revalidation_batches from public, anon, authenticated, service_role;

-- Same id the Worker computes (worker/src/lease.ts slotRunId): uuid-v5 layout over sha256('orbijob:sync-slot:<source>:<slotMs>:<slot>').
create function ops.slot_run_id(p_source text, p_now timestamptz, p_slot_ms bigint default 3600000)
returns uuid language plpgsql immutable as $$
declare
  v_slot bigint := floor(floor(extract(epoch from p_now) * 1000) / p_slot_ms);
  h bytea;
begin
  h := substring(sha256(convert_to('orbijob:sync-slot:' || p_source || ':' || p_slot_ms || ':' || v_slot, 'UTF8')) from 1 for 16);  -- core sha256(bytea), no extension
  h := set_byte(h, 6, (get_byte(h, 6) & 15) | 80);    -- version 5
  h := set_byte(h, 8, (get_byte(h, 8) & 63) | 128);   -- RFC 4122 variant
  return encode(h, 'hex')::uuid;
end $$;

create function ops.jobicy_revalidate_start() returns text language plpgsql as $$
declare
  c_source  constant text     := 'jobicy';
  c_ttl     constant interval := interval '20 minutes';   -- a 'running' row older than this is a crashed run (the Worker uses the same)
  c_min     constant interval := interval '60 minutes';   -- Jobicy: at most one automated pass per hour
  c_per_req constant int      := 100;                     -- the endpoint takes 1-100 ids
  c_max_req constant int      := 10;                      -- 1000 jobs per pass, oldest verification first
  v_now     timestamptz := now();
  v_id      uuid := ops.slot_run_id(c_source, v_now);
  v_ids     text[];
  v_chunk   text[];
  v_req     bigint;
  v_n       int;
  i         int;
begin
  -- 1. the lease (same rules as acquireLease in worker/src/lease.ts)
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

  -- 2. the stored open jobs, oldest verification first; only well-formed Jobicy ids ever reach a URL
  select coalesce(array_agg(external_id order by last_checked_at nulls first, external_id), '{}') into v_ids from (
    select external_id, last_checked_at from public.jobs
     where source_id = c_source and status = 'open' and external_id ~ '^[1-9][0-9]{0,15}$'
     order by last_checked_at nulls first, external_id
     limit c_per_req * c_max_req) t;
  v_n := coalesce(array_length(v_ids, 1), 0);
  if v_n = 0 then
    update public.sync_runs set status = 'ok', finished_at = now() where id = v_id;
    return 'ok:nothing_to_revalidate';
  end if;

  -- 3. queue the requests (sent when this transaction commits)
  for i in 0 .. ((v_n - 1) / c_per_req) loop
    v_chunk := v_ids[i * c_per_req + 1 : least((i + 1) * c_per_req, v_n)];
    v_req := net.http_get(
      url := 'https://jobicy.com/api/v2/remote-jobs/status?ids=' || array_to_string(v_chunk, ','),
      headers := jsonb_build_object('Accept', 'application/json', 'User-Agent', 'OrbiJob-revalidate/1 (+https://github.com/Lucasdiogof/orbijob)'),
      timeout_milliseconds := 20000);
    insert into ops.revalidation_batches (run_id, batch, request_id, external_ids) values (v_id, i, v_req, v_chunk);
  end loop;
  return 'started:' || v_n || ' jobs in ' || ((v_n - 1) / c_per_req + 1) || ' request(s)';
end $$;

create function ops.jobicy_revalidate_collect() returns text language plpgsql as $$
declare
  c_source  constant text     := 'jobicy';
  c_timeout constant interval := interval '30 minutes';   -- answers that never came are timeouts
  v_now     timestamptz := now();
  r         record;
  b         record;
  v_out     text := '';
  v_resp    record;
  v_json    jsonb;
  v_outcome text;
  v_status  int;
  v_closed  int;
  v_conf    int;
  v_unknown int;
  v_ok int; v_fail int; v_closed_total int; v_err text; v_pending int;
begin
  if not pg_try_advisory_xact_lock(hashtext('orbijob:jobicy-revalidate-collect')) then return 'skipped:locked'; end if;

  -- only runs THIS mechanism started (the Worker / GitHub Actions also write 'revalidate' rows and are none of our business)
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

    for b in select * from ops.revalidation_batches where run_id = r.id and collected_at is null order by batch loop
      select * into v_resp from net._http_response x where x.id = b.request_id order by x.created desc limit 1;
      v_outcome := null; v_status := v_resp.status_code; v_closed := 0; v_conf := 0; v_unknown := 0;

      if not found then
        v_outcome := 'timeout';                                  -- no answer within the allowed time
      elsif coalesce(v_resp.timed_out, false) then
        v_outcome := 'timeout';
      elsif v_resp.status_code is distinct from 200 then
        v_outcome := 'http_error';
      else
        begin
          v_json := v_resp.content::jsonb;
        exception when others then
          v_json := null;
        end;
        if v_json is null or jsonb_typeof(v_json) <> 'object' or (v_json -> 'success') is distinct from 'true'::jsonb
           or jsonb_typeof(v_json -> 'jobs') is distinct from 'array' then
          v_outcome := 'bad_response';
        end if;
      end if;

      if v_outcome is null then
        -- apply the decisions, only for ids that were asked about and only on jobs that are still open
        with ans as (
          select (e ->> 'id') as ext, (e ->> 'status') as st
            from jsonb_array_elements(v_json -> 'jobs') e
           where (e ->> 'id') = any (b.external_ids)
        ), closed as (
          update public.jobs j set status = 'closed', last_checked_at = v_now
            from ans where j.source_id = c_source and j.external_id = ans.ext and ans.st = 'closed' and j.status = 'open'
          returning 1
        ), conf as (
          update public.jobs j set last_checked_at = v_now
            from ans where j.source_id = c_source and j.external_id = ans.ext and ans.st = 'active' and j.status = 'open'
          returning 1
        )
        select (select count(*) from closed), (select count(*) from conf) into v_closed, v_conf;
        v_unknown := array_length(b.external_ids, 1) - v_closed - v_conf;
        v_outcome := 'applied';
      end if;

      update ops.revalidation_batches
         set collected_at = v_now, http_status = v_status, outcome = v_outcome, closed = v_closed, confirmed = v_conf, unknown = v_unknown
       where run_id = b.run_id and batch = b.batch;
    end loop;

    -- close the run record (same columns the Worker fills)
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

revoke all on function ops.slot_run_id(text, timestamptz, bigint) from public, anon, authenticated, service_role;
revoke all on function ops.jobicy_revalidate_start() from public, anon, authenticated, service_role;
revoke all on function ops.jobicy_revalidate_collect() from public, anon, authenticated, service_role;

comment on function ops.jobicy_revalidate_start() is 'Phase 1 of the in-database Jobicy revalidation: lease + queue the status requests. See migration 20261015000000.';
comment on function ops.jobicy_revalidate_collect() is 'Phase 2: read the answers, close only what Jobicy confirms closed, stamp what it confirms active, close the run record.';
