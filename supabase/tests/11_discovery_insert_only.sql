-- What the database guarantees to the incremental discovery (worker, SYNC_MODE=discover) on a REAL PostgreSQL (CI: 16 and 17).
-- PostgREST's `resolution=ignore-duplicates` is `INSERT ... ON CONFLICT (source_id, external_id) DO NOTHING`; it runs here under the real
-- grants of migration 7 (service_role: SELECT/INSERT/UPDATE on jobs, no DELETE, no write on job_sources). Everything created is removed at the end.
\set ON_ERROR_STOP on

insert into public.job_sources (id, status, attribution, can_redistribute) values ('disc-test', 'CONDITIONAL', 'Remote jobs via Jobicy (https://jobicy.com)', true);
insert into public.jobs (source_id, external_id, company, title, description, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status)
values ('disc-test', '1', 'Acme Inc', 'Reviewed role', 'reviewed text', 'remote', timestamptz '2026-10-01 00:00+00', 'https://jobicy.com/jobs/1', 'https://jobicy.com/jobs/1', 'fp-1', 'closed');

create temp table disc_before as select md5(j::text) as h from public.jobs j where source_id = 'disc-test' and external_id = '1';

set role service_role;
do $$
declare n int;
begin
  -- an id that is already stored: nothing is inserted, nothing returned, the row (closed, reviewed) is untouched
  with ins as (
    insert into public.jobs (source_id, external_id, company, title, description, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status)
    values ('disc-test', '1', '', 'blank', '', 'remote', now(), 'https://jobicy.com/jobs/1', 'https://jobicy.com/jobs/1', 'fp-x', 'open')
    on conflict (source_id, external_id) do nothing returning 1)
  select count(*) into n from ins;
  if n <> 0 then raise exception 'a stored id was inserted again'; end if;

  -- a new id: inserted
  with ins as (
    insert into public.jobs (source_id, external_id, company, title, description, work_mode, last_checked_at, original_url, canonical_url, fingerprint, status)
    values ('disc-test', '2', 'Other', 'New role', 'text', 'remote', now(), 'https://jobicy.com/jobs/2', 'https://jobicy.com/jobs/2', 'fp-2', 'open')
    on conflict (source_id, external_id) do nothing returning 1)
  select count(*) into n from ins;
  if n <> 1 then raise exception 'a new id was not inserted'; end if;

  -- the role cannot erase jobs, hide the source, invent a source or a listing of an unknown source
  perform tests.fails($q$delete from public.jobs where source_id = 'disc-test'$q$, 'permission denied');
  perform tests.fails($q$update public.job_sources set can_redistribute = false where id = 'disc-test'$q$, 'permission denied');
  perform tests.fails($q$insert into public.job_sources (id, status) values ('disc-new', 'READY')$q$, 'permission denied');
  perform tests.fails($q$insert into public.jobs (source_id, external_id, company, title, work_mode, last_checked_at, original_url, canonical_url, fingerprint) values ('no-such-source', '9', 'c', 't', 'remote', now(), 'u', 'u', 'f')$q$, 'foreign key|violates');
end $$;
reset role;

do $$ begin
  if (select md5(j::text) from public.jobs j where source_id = 'disc-test' and external_id = '1') is distinct from (select h from disc_before) then
    raise exception 'the stored row changed';
  end if;
end $$;

-- app users cannot insert jobs at all
set role anon;
do $$ begin
  perform tests.fails($q$insert into public.jobs (source_id, external_id, company, title, work_mode, last_checked_at, original_url, canonical_url, fingerprint) values ('disc-test', '3', 'c', 't', 'remote', now(), 'u', 'u', 'f')$q$, 'row-level security|permission denied');
end $$;
reset role;

drop table disc_before;
delete from public.jobs where source_id = 'disc-test';
delete from public.job_sources where id = 'disc-test';
\echo 'discovery insert-only: ok'
