-- OrbiJob 3.0 (migration 20261023000000) on a REAL PostgreSQL (CI: 16 and 17): saved searches with alerts, notifications, hidden jobs.
-- What matters most here is the privilege model: the client edits a search but not the alert cursor, reads and marks notifications but cannot create
-- or delete them, and nobody but the owner can run the alert function. The finer matching rules are covered by worker/test/v3-alerts.test.ts.
\set ON_ERROR_STOP on

insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000c1'), ('00000000-0000-4000-8000-0000000000c2') on conflict do nothing;
insert into public.job_sources (id, status, attribution, can_redistribute) values ('v3src', 'CONDITIONAL', 'v3', true) on conflict do nothing;
insert into public.jobs (source_id, external_id, company, title, work_mode, country, last_checked_at, first_seen_at, original_url, canonical_url, fingerprint, status)
values ('v3src', 'j-new', 'Acme', 'Registered Nurse', 'onsite', 'DE', now(), now() - interval '5 minutes', 'https://v3.test/new', 'https://v3.test/new', 'fp-v3-new', 'open'),
       ('v3src', 'j-hid', 'Acme', 'Nurse Practitioner', 'onsite', 'DE', now(), now() - interval '5 minutes', 'https://v3.test/hid', 'https://v3.test/hid', 'fp-v3-hid', 'open'),
       ('v3src', 'j-old', 'Acme', 'Old Nurse', 'onsite', 'DE', now(), now() - interval '9 hours', 'https://v3.test/old', 'https://v3.test/old', 'fp-v3-old', 'open'),
       ('v3src', 'j-closed', 'Acme', 'Closed Nurse', 'onsite', 'DE', now(), now() - interval '5 minutes', 'https://v3.test/closed', 'https://v3.test/closed', 'fp-v3-closed', 'closed');
insert into public.hidden_jobs (user_id, job_key, source_id, external_id, title) values ('00000000-0000-4000-8000-0000000000c1', 'v3src:j-hid', 'v3src', 'j-hid', 'Nurse Practitioner');

-- ===== user C1 =====
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000c1', false);
do $$
declare
  C1 constant text := '00000000-0000-4000-8000-0000000000c1';
  C2 constant text := '00000000-0000-4000-8000-0000000000c2';
  sid uuid;
begin
  insert into public.saved_searches (user_id, name, query, alerts_enabled, frequency)
  values (C1::uuid, 'Nurses', '{"v":2,"term":"nurse","match":{"term":"nurse"}}', true, 'instant') returning id into sid;
  -- the search is the client's, the alert machinery is not
  perform tests.fails(format($q$update public.saved_searches set alert_cursor = now() - interval '9 years' where id = %L$q$, sid), 'permission denied');
  perform tests.fails(format($q$update public.saved_searches set last_alert_run_at = null where id = %L$q$, sid), 'permission denied');
  perform tests.affected(format($q$update public.saved_searches set name = 'Night nurses', frequency = 'weekly' where id = %L$q$, sid), 1);
  perform tests.fails(format($q$update public.saved_searches set frequency = 'minutely' where id = %L$q$, sid), 'check constraint');
  perform tests.fails(format($q$insert into public.saved_searches (user_id, query) values (%L, jsonb_build_object('x', repeat('a', 13000)))$q$, C1), 'check constraint');
  -- notifications: read and mark, nothing else
  perform tests.fails($q$insert into public.notifications (user_id, title) values ('00000000-0000-4000-8000-0000000000c1', 'forged')$q$, 'permission denied');
  perform tests.fails($q$delete from public.notifications$q$, 'permission denied');
  perform tests.fails($q$update public.notifications set title = 'x'$q$, 'permission denied');
  -- the alert function is not reachable
  perform tests.fails($q$select ops.alerts_run()$q$, 'permission denied');
  perform tests.fails($q$select * from ops.alert_runs$q$, 'permission denied');
  -- hidden jobs: own rows only
  perform tests.count('select 1 from public.hidden_jobs', 1);
  perform tests.fails(format($q$insert into public.hidden_jobs (user_id, job_key, source_id, external_id, title) values (%L,'a:b','a','b','t')$q$, C2), 'row-level security');
end $$;
reset role;

-- the owner runs the pass (what pg_cron does): the new, visible, not-hidden job is announced once; the hidden, old and closed ones are not
update public.saved_searches set alert_cursor = now() - interval '2 hours', last_alert_run_at = null where name = 'Night nurses';
do $$
begin
  perform tests.count($q$select 1 from public.notifications$q$, 0);
  if ops.alerts_run() not like 'ok due=%' then raise exception 'alerts_run did not finish'; end if;
  perform tests.count($q$select 1 from public.notifications where user_id = '00000000-0000-4000-8000-0000000000c1' and title = 'Registered Nurse'$q$, 1);
  perform tests.count($q$select 1 from public.notifications$q$, 1);
  update public.saved_searches set last_alert_run_at = null where name = 'Night nurses';
  perform ops.alerts_run();
  perform tests.count($q$select 1 from public.notifications$q$, 1);  -- the overlap window did not announce it again
end $$;

-- the owner of the notification marks it read; nobody else sees it
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000c1', false);
do $$
begin
  perform tests.affected($q$update public.notifications set read_at = now()$q$, 1);
  perform tests.affected($q$update public.notifications set dismissed_at = now()$q$, 1);
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000c2', false);
do $$
begin
  perform tests.count('select 1 from public.notifications', 0);
  perform tests.count('select 1 from public.saved_searches', 0);
  perform tests.count('select 1 from public.hidden_jobs', 0);
end $$;
reset role;
set role anon;
do $$
begin
  perform tests.fails($q$select * from public.notifications$q$, 'permission denied');
  perform tests.fails($q$select * from public.hidden_jobs$q$, 'permission denied');
end $$;
reset role;

-- cleanup
delete from public.notifications;
delete from public.hidden_jobs;
delete from public.saved_searches where user_id in ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000c2');
delete from public.jobs where source_id = 'v3src';
delete from public.job_sources where id = 'v3src';
delete from ops.alert_runs;
delete from auth.users where id in ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000c2');
