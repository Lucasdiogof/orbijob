-- The in-database Jobicy revalidation (migration 20261015000000) on a REAL PostgreSQL (CI: 16 and 17).
-- pg_net/pg_cron are not available on a plain server: `net` is a stand-in that records the requests; the answers of "Jobicy" are rows
-- written into net._http_response. Everything it creates is removed at the end (the chain is re-applied and audited afterwards).
\set ON_ERROR_STOP on
create schema net;
create unlogged table net._http_response (id bigint, status_code int, content_type text, headers jsonb, content text, timed_out boolean, error_msg text, created timestamptz not null default now());
create table net._requests (id bigserial primary key, url text, headers jsonb, timeout int);
create function net.http_get(url text, params jsonb default '{}', headers jsonb default '{}', timeout_milliseconds int default 2000) returns bigint
  language sql as $$ insert into net._requests (url, headers, timeout) values (url, headers, timeout_milliseconds) returning id $$;

insert into public.job_sources (id, status, attribution, can_redistribute) values ('jobicy', 'CONDITIONAL', 'Remote jobs via Jobicy (https://jobicy.com)', true);
insert into public.jobs (source_id, external_id, company, title, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status)
select 'jobicy', (7000 + g)::text, 'c', 't', 'remote', timestamptz '2026-10-01 00:00+00' + g * interval '1 minute', 'https://jobicy.com/jobs/' || g, 'https://jobicy.com/jobs/' || g, 'cron-fp-' || g, 'open'
  from generate_series(1, 150) g;

do $$
declare r text; before_jobs text; after_jobs text; rid bigint;
begin
  select md5(string_agg(external_id || status || coalesce(description, '') || coalesce(canonical_url, ''), ',' order by external_id)) into before_jobs from public.jobs;

  -- phase 1: lease + two requests (150 jobs), nothing changed yet
  r := ops.jobicy_revalidate_start();
  if r <> 'started:150 jobs in 2 request(s)' then raise exception 'start returned %', r; end if;
  perform tests.count($q$select 1 from net._requests where url like 'https://jobicy.com/api/v2/remote-jobs/status?ids=%'$q$, 2);
  perform tests.count($q$select 1 from ops.revalidation_batches$q$, 2);
  perform tests.count($q$select 1 from public.sync_runs where scope = 'revalidate' and status = 'running'$q$, 1);
  if ops.jobicy_revalidate_start() <> 'skipped:running' then raise exception 'second start must stand down'; end if;
  select md5(string_agg(external_id || status || coalesce(description, '') || coalesce(canonical_url, ''), ',' order by external_id)) into after_jobs from public.jobs;
  if after_jobs <> before_jobs then raise exception 'asking changed a job'; end if;

  -- only one of two answers: it waits
  select id into rid from net._requests order by id limit 1;
  insert into net._http_response (id, status_code, content, timed_out) values (rid, 200, '{"success":true,"statusCode":200,"jobs":[{"id":7001,"status":"closed"},{"id":7002,"status":"active"},{"id":7003,"status":"unknown"}]}', false);
  r := ops.jobicy_revalidate_collect();
  if r not like '%waiting(1)%' then raise exception 'collect should wait, got %', r; end if;
  perform tests.count($q$select 1 from public.jobs where source_id = 'jobicy' and status = 'closed'$q$, 0);

  -- the second answer is an HTTP 500: partial, and only the first batch is applied
  select id into rid from net._requests order by id desc limit 1;
  insert into net._http_response (id, status_code, content, timed_out) values (rid, 500, '{}', false);
  r := ops.jobicy_revalidate_collect();
  if r not like '%:partial;' then raise exception 'collect should end partial, got %', r; end if;
  perform tests.count($q$select 1 from public.sync_runs where scope = 'revalidate' and status = 'partial' and closed = 1 and http_errors = 1 and error_class = 'http_500' and finished_at is not null$q$, 1);
  perform tests.count($q$select 1 from public.jobs where source_id = 'jobicy' and external_id = '7001' and status = 'closed'$q$, 1);
  perform tests.count($q$select 1 from public.jobs where source_id = 'jobicy' and external_id = '7002' and status = 'open' and last_checked_at > now() - interval '1 minute'$q$, 1);
  perform tests.count($q$select 1 from public.jobs where source_id = 'jobicy' and external_id = '7003' and status = 'open' and last_checked_at = timestamptz '2026-10-01 00:03+00'$q$, 1);
  perform tests.count($q$select 1 from public.jobs where source_id = 'jobicy' and status = 'open' and last_checked_at < timestamptz '2026-10-02'$q$, 148);
  if ops.jobicy_revalidate_collect() <> 'nothing_to_collect' then raise exception 'collect must be idempotent'; end if;
  if ops.jobicy_revalidate_start() <> 'skipped:too_soon' then raise exception 'one pass per hour'; end if;
  -- The previous SQL suites leave two non-Jobicy fixture jobs in the same database.
  perform tests.count($q$select 1 from public.jobs$q$, 152);
  perform tests.count($q$select 1 from public.job_sources where id = 'jobicy' and can_redistribute$q$, 1);
end $$;

-- the API roles cannot run it, read its log or even see the schema
set role service_role;
do $$ begin
  perform tests.fails($q$select ops.jobicy_revalidate_start()$q$, 'permission denied');
  perform tests.fails($q$select ops.jobicy_revalidate_collect()$q$, 'permission denied');
  perform tests.fails($q$select * from ops.revalidation_batches$q$, 'permission denied');
end $$;
reset role;
set role anon;
do $$ begin perform tests.fails($q$select ops.jobicy_revalidate_start()$q$, 'permission denied'); end $$;
reset role;

-- clean up (owner): the run record, the batch log, the test jobs and source, the stand-in
delete from ops.revalidation_batches;
delete from public.sync_runs where scope = 'revalidate';
delete from public.jobs where source_id = 'jobicy';
delete from public.job_sources where id = 'jobicy';
drop schema net cascade;
\echo 'revalidation cron: ok'
