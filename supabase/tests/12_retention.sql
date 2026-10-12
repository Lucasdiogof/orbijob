-- The retention of closed Jobicy jobs (migration 20261016000000) on a REAL PostgreSQL (CI: 16 and 17).
-- Open jobs are never touched; closed > 14 days are compacted; closed > 90 days and unreferenced are deleted with a tombstone;
-- a referenced job is only compacted; the API roles cannot reach any of it. Everything created is removed at the end.
\set ON_ERROR_STOP on

create temp table plan0 as select layer, jobs from ops.jobicy_retention_plan();

insert into public.job_sources (id, status, attribution, can_redistribute) values ('jobicy', 'CONDITIONAL', 'Remote jobs via Jobicy (https://jobicy.com)', true);
insert into public.jobs (source_id, external_id, company, title, description, requirements, skills, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status)
select 'jobicy', v.id, 'Acme', 'Role ' || v.id, 'a long description', '{x}', '{y}', 'remote', now() - v.age, 'https://jobicy.com/jobs/' || v.id, 'https://jobicy.com/jobs/' || v.id, 'fp-ret-' || v.id, v.st
  from (values ('r1', interval '400 days', 'open'), ('r2', interval '3 days', 'closed'), ('r3', interval '30 days', 'closed'),
               ('r4', interval '120 days', 'closed'), ('r5', interval '200 days', 'closed')) as v(id, age, st);
-- a user row that references r5 (a favourite): r5 must survive, compacted
insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000aa');
insert into public.saved_jobs (user_id, job_id, job_key, snapshot) select '00000000-0000-4000-8000-0000000000aa', id, 'jobicy:r5', '{"k":1}' from public.jobs where external_id = 'r5';

do $$
declare r text;
begin
  -- since migration 10 the plan counts every source, and earlier suites leave other jobs here: assert the DELTA against the baseline
  perform tests.count($q$select 1 from ops.jobicy_retention_plan() p join plan0 b using (layer) where (layer = 'open' and p.jobs - b.jobs = 1) or (layer = 'closed_recent' and p.jobs - b.jobs = 1) or (layer = 'closed_to_compact' and p.jobs - b.jobs = 3) or (layer = 'closed_to_delete' and p.jobs - b.jobs = 1) or (layer = 'closed_kept_referenced' and p.jobs - b.jobs = 1)$q$, 5);
  perform tests.fails($q$select ops.jobicy_retention_apply('no')$q$, 'frase de autorizacao');
  r := ops.jobicy_retention_apply('EU-AUTORIZO-A-RETENCAO', interval '14 days', interval '90 days', 200, true);
  if r not like 'ok:compacted=%,deleted=%' then raise exception 'unexpected result: %', r; end if;
  -- r1 open and old: untouched; r2 recent: untouched; r3 compacted; r4 deleted with tombstone; r5 referenced: compacted, kept
  perform tests.count($q$select 1 from public.jobs where external_id = 'r1' and description = 'a long description' and status = 'open'$q$, 1);
  perform tests.count($q$select 1 from public.jobs where external_id = 'r2' and description = 'a long description'$q$, 1);
  perform tests.count($q$select 1 from public.jobs where external_id = 'r3' and description = '' and requirements = '{}' and skills = '{}' and title = 'Role r3' and original_url = 'https://jobicy.com/jobs/r3'$q$, 1);
  perform tests.count($q$select 1 from public.jobs where external_id = 'r4'$q$, 0);
  perform tests.count($q$select 1 from ops.job_tombstones where source_id = 'jobicy' and external_id = 'r4'$q$, 1);
  perform tests.count($q$select 1 from public.jobs where external_id = 'r5' and description = ''$q$, 1);
  perform tests.count($q$select 1 from public.saved_jobs where job_key = 'jobicy:r5'$q$, 1);
  if ops.jobicy_retention_apply('EU-AUTORIZO-A-RETENCAO') <> 'ok:compacted=0,deleted=0' then raise exception 'not idempotent'; end if;
  perform tests.count($q$select 1 from ops.retention_runs$q$, 2);
  perform tests.count($q$select 1 from public.sync_runs where source_id = 'jobicy'$q$, 0);
end $$;

-- recovery: the export lists what the next run changes; restore brings it back
insert into public.jobs (source_id, external_id, company, title, description, requirements, skills, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status)
values ('jobicy', 'r6', 'Acme', 'Role r6', 'to be restored', '{x}', '{y}', 'remote', now() - interval '30 days', 'https://jobicy.com/jobs/r6', 'https://jobicy.com/jobs/r6', 'fp-ret-r6', 'closed'),
       ('jobicy', 'r7', 'Acme', 'Role r7', 'deleted then restored', '{x}', '{y}', 'remote', now() - interval '150 days', 'https://jobicy.com/jobs/r7', 'https://jobicy.com/jobs/r7', 'fp-ret-r7', 'closed');
create temp table ret_export as select ops.jobicy_retention_export() as e;
do $$
begin
  if jsonb_array_length((select e from ret_export)) <> 2 then raise exception 'export should list r6 and r7'; end if;
  if ops.jobicy_retention_apply('EU-AUTORIZO-A-RETENCAO') <> 'ok:compacted=1,deleted=1' then raise exception 'unexpected apply'; end if;
  perform tests.count($q$select 1 from public.jobs where external_id = 'r7'$q$, 0);
  if ops.jobicy_retention_restore('EU-AUTORIZO-A-RESTAURACAO', (select e from ret_export)) <> 'ok:reinserted=1,restored=1' then raise exception 'unexpected restore'; end if;
  perform tests.count($q$select 1 from public.jobs where external_id = 'r6' and description = 'to be restored'$q$, 1);
  perform tests.count($q$select 1 from public.jobs where external_id = 'r7' and description = 'deleted then restored' and requirements = '{x}'$q$, 1);
  perform tests.count($q$select 1 from ops.job_tombstones where external_id = 'r7'$q$, 0);
end $$;
drop table ret_export;

-- the API roles cannot reach it
set role service_role;
do $$ begin
  perform tests.fails($q$select ops.jobicy_retention_apply('EU-AUTORIZO-A-RETENCAO')$q$, 'permission denied');
  perform tests.fails($q$select * from ops.jobicy_retention_plan()$q$, 'permission denied');
  perform tests.fails($q$select * from ops.job_tombstones$q$, 'permission denied');
  perform tests.fails($q$select ops.jobicy_retention_export()$q$, 'permission denied');
  perform tests.fails($q$select ops.jobicy_retention_restore('EU-AUTORIZO-A-RESTAURACAO', '[]'::jsonb)$q$, 'permission denied');
end $$;
reset role;
set role anon;
do $$ begin perform tests.fails($q$select ops.jobicy_retention_apply('EU-AUTORIZO-A-RETENCAO')$q$, 'permission denied'); end $$;
reset role;

delete from public.saved_jobs where job_key = 'jobicy:r5';
delete from auth.users where id = '00000000-0000-4000-8000-0000000000aa';
delete from ops.retention_runs;
delete from ops.job_tombstones;
delete from public.jobs where source_id = 'jobicy';
delete from public.job_sources where id = 'jobicy';
drop table plan0;
\echo 'retention: ok'
