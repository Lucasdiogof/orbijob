-- service_role must have exactly the privileges the backend needs: no more (least privilege) and no less (it has to work).
-- Run on a database whose defaults match the REAL project (00_platform_stub.sql: postgres-owned tables give service_role
-- only TRUNCATE/REFERENCES/TRIGGER by default), so this fails without 20261013000000_service_role_grants.sql.
\set ON_ERROR_STOP on
do $$
declare r record; want text[]; got text[]; t text;
begin
  -- 1. exact privilege matrix on every table in public
  for t in select c.relname from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','p') order by 1 loop
    want := case t
      when 'job_sources'  then array['INSERT','SELECT','UPDATE']
      when 'jobs'         then array['DELETE','INSERT','SELECT','UPDATE']
      when 'job_clusters' then array['DELETE','INSERT','SELECT','UPDATE']
      when 'sync_runs'    then array['INSERT','SELECT','UPDATE']
      when 'resumes'      then array['SELECT']
      else array[]::text[] end;
    select coalesce(array_agg(p order by p), array[]::text[]) into got
      from unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
     where has_table_privilege('service_role', format('public.%I', t), p);
    if got <> want then raise exception 'SERVICE_ROLE: public.% has % but should have %', t, got, want; end if;
  end loop;
  -- 2. no EXECUTE on any function in public (the backend does not call them)
  for r in select p.proname from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'
           and p.prorettype <> 'event_trigger'::regtype and has_function_privilege('service_role', p.oid, 'execute') loop
    raise exception 'SERVICE_ROLE: can execute public.%()', r.proname;
  end loop;
  -- 3. tables created from now on start with nothing for service_role
  create table public.zz_future_probe (id int);
  if has_table_privilege('service_role', 'public.zz_future_probe', 'SELECT')
     or has_table_privilege('service_role', 'public.zz_future_probe', 'TRUNCATE') then
    raise exception 'SERVICE_ROLE: a new table inherits privileges for service_role';
  end if;
  drop table public.zz_future_probe;
end $$;

-- 4. behaviour as the role: the operations the backend performs work (RLS bypassed) and the forbidden ones fail
set role service_role;
do $$
declare src text := 'e2e-svc'; jid uuid; cid uuid; rid uuid;
begin
  insert into public.job_sources (id, status, can_redistribute) values (src, 'READY', true);
  update public.job_sources set attribution = 'a' where id = src;
  insert into public.jobs (source_id, external_id, company, title, last_checked_at, original_url, fingerprint, canonical_url)
    values (src, 'x1', 'C', 'T', now(), 'https://example.invalid/1', 'fp', 'https://example.invalid/1') returning id into jid;
  update public.jobs set status = 'closed' where id = jid;
  insert into public.job_clusters (canonical_job_id) values (jid) returning id into cid;
  update public.jobs set cluster_id = cid where id = jid;
  insert into public.sync_runs (source_id, status) values (src, 'running') returning id into rid;
  update public.sync_runs set status = 'ok', finished_at = now() where id = rid;
  perform tests.count('select 1 from public.sync_runs', 1);
  perform 1 from public.resumes limit 1;                                         -- readable (RLS bypassed: rows of every user)
  update public.jobs set cluster_id = null where id = jid;
  delete from public.job_clusters where id = cid;
  delete from public.jobs where id = jid;
  -- forbidden
  perform tests.fails($q$delete from public.job_sources where id = 'e2e-svc'$q$, 'permission denied');
  perform tests.fails($q$delete from public.sync_runs$q$, 'permission denied');
  perform tests.fails($q$insert into public.resumes (profile_id, user_id, storage_path) values (gen_random_uuid(), gen_random_uuid(), 'x')$q$, 'permission denied');
  perform tests.fails($q$delete from public.resumes$q$, 'permission denied');
  perform tests.fails($q$select 1 from public.professional_profiles$q$, 'permission denied');
  perform tests.fails($q$select 1 from public.saved_jobs$q$, 'permission denied');
  perform tests.fails($q$select 1 from public.applications$q$, 'permission denied');
  perform tests.fails($q$select 1 from public.user_preferences$q$, 'permission denied');
  perform tests.fails($q$truncate public.jobs$q$, 'permission denied');
  perform tests.fails($q$select public.enforce_row_quota()$q$, 'permission denied');
end $$;
reset role;
-- the sync_runs row and the source created above are removed by the owner (the role cannot delete them by design)
delete from public.sync_runs where source_id = 'e2e-svc';
delete from public.job_sources where id = 'e2e-svc';
\echo 'service_role: ok'
