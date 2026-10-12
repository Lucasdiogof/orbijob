-- Migrations 20261017000000 and 20261018000000 (window floor) on a REAL PostgreSQL (CI: 16 and 17): the expiry of jobs a feed-based source no longer lists, and the retention that now
-- covers every source. Everything created is removed at the end.
\set ON_ERROR_STOP on

insert into public.job_sources (id, status, attribution, can_redistribute) values ('arbeitnow', 'CONDITIONAL', 'Jobs via Arbeitnow (https://www.arbeitnow.com)', true);
insert into public.jobs (source_id, external_id, company, title, description, requirements, skills, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status, published_at)
select 'arbeitnow', v.id, 'Acme', 'Role ' || v.id, 'a long description', '{x}', '{y}', 'unspecified', now() - v.age, 'https://www.arbeitnow.com/jobs/' || v.id, 'https://www.arbeitnow.com/jobs/' || v.id, 'fp-sm-' || v.id, v.st, now() - v.pub
  from (values ('s1', interval '9 days', 'open', interval '10 days'), ('s2', interval '2 days', 'open', interval '3 days'), ('s3', interval '30 days', 'closed', interval '31 days'),
               ('s4', interval '120 days', 'closed', interval '121 days'), ('s5', interval '9 days', 'open', interval '40 days')) as v(id, age, st, pub);

do $$
declare r text;
begin
  -- no successful discovery pass yet: nothing is judged
  r := ops.expire_unseen_jobs('EU-AUTORIZO-A-EXPIRACAO', interval '7 days', array['arbeitnow']);
  if r <> 'ok:expired=0,skipped=arbeitnow' then raise exception 'unexpected (no run): %', r; end if;
  perform tests.count($q$select 1 from public.jobs where external_id = 's1' and status = 'open'$q$, 1);

  insert into public.sync_runs (source_id, scope, status, started_at, finished_at) values ('arbeitnow', 'discover', 'ok', now() - interval '1 hour', now() - interval '59 minutes');
  -- an ok pass that saw nothing gives no window floor: Arbeitnow is still not judged (migration 20261018000000)
  r := ops.expire_unseen_jobs('EU-AUTORIZO-A-EXPIRACAO', interval '7 days', array['arbeitnow']);
  if r <> 'ok:expired=0,skipped=arbeitnow' then raise exception 'unexpected (no floor): %', r; end if;
  -- the pass saw one job published 20 days ago: s1 (10 days) is inside the window and gone; s5 (40 days) is beyond it: not closed, marked unknown (migration 20261019000000)
  insert into public.jobs (source_id, external_id, company, title, description, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status, published_at)
    values ('arbeitnow', 's6', 'Acme', 'Role s6', 'a long description', 'unspecified', now(), 'https://www.arbeitnow.com/jobs/s6', 'https://www.arbeitnow.com/jobs/s6', 'fp-sm-s6', 'open', now() - interval '20 days');
  r := ops.expire_unseen_jobs('EU-AUTORIZO-A-EXPIRACAO', interval '7 days', array['arbeitnow']);
  perform tests.count($q$select 1 from public.jobs where external_id = 's5' and status = 'unknown'$q$, 1);
  if r <> 'ok:expired=1,unknown=1' then raise exception 'unexpected expire: %', r; end if;
  perform tests.count($q$select 1 from public.jobs where external_id = 's1' and status = 'closed' and description = 'a long description'$q$, 1);
  perform tests.count($q$select 1 from public.jobs where external_id = 's2' and status = 'open'$q$, 1);
  if ops.expire_unseen_jobs('EU-AUTORIZO-A-EXPIRACAO', interval '7 days', array['arbeitnow']) <> 'ok:expired=0' then raise exception 'not idempotent'; end if;

  perform tests.fails($q$select ops.expire_unseen_jobs('no')$q$, 'frase de autorizacao');
  perform tests.fails($q$select ops.expire_unseen_jobs('EU-AUTORIZO-A-EXPIRACAO', interval '1 day')$q$, 'minimo e 4 dias');
  perform tests.fails($q$select ops.expire_unseen_jobs('EU-AUTORIZO-A-EXPIRACAO', interval '7 days', array['jobicy'])$q$, 'jobicy tem endpoint');

  -- the retention covers this source: s3 (closed 30 days) is compacted, s4 (closed 120 days, unreferenced) is deleted; open s2 is untouched
  r := ops.jobicy_retention_apply('EU-AUTORIZO-A-RETENCAO', interval '14 days', interval '90 days', 200, true);
  if r not like 'ok:compacted=%,deleted=%' then raise exception 'unexpected retention: %', r; end if;
  perform tests.count($q$select 1 from public.jobs where external_id = 's3' and description = '' and status = 'closed'$q$, 1);
  perform tests.count($q$select 1 from public.jobs where external_id = 's4'$q$, 0);
  perform tests.count($q$select 1 from ops.job_tombstones where source_id = 'arbeitnow' and external_id = 's4'$q$, 1);
  perform tests.count($q$select 1 from public.jobs where external_id = 's2' and description = 'a long description'$q$, 1);
end $$;

set role service_role;
do $$ begin perform tests.fails($q$select ops.expire_unseen_jobs('EU-AUTORIZO-A-EXPIRACAO')$q$, 'permission denied'); end $$;
reset role;
set role anon;
do $$ begin perform tests.fails($q$select ops.expire_unseen_jobs('EU-AUTORIZO-A-EXPIRACAO')$q$, 'permission denied'); end $$;
reset role;

delete from ops.retention_runs;
delete from ops.job_tombstones where source_id = 'arbeitnow';
delete from public.sync_runs where source_id = 'arbeitnow';
delete from public.jobs where source_id = 'arbeitnow';
delete from public.job_sources where id = 'arbeitnow';
\echo 'sources maintenance: ok'
