-- Catalog-level security audit. Fails the run on any finding.
\set ON_ERROR_STOP on
do $$
declare r record; n int;
begin
  -- 1. RLS enabled on every table in public and on storage.objects
  for r in select c.relname from pg_class c join pg_namespace s on s.oid = c.relnamespace
           where s.nspname = 'public' and c.relkind in ('r','p') and not c.relrowsecurity loop
    raise exception 'AUDIT: RLS disabled on public.%', r.relname;
  end loop;
  if not (select relrowsecurity from pg_class where oid = 'storage.objects'::regclass) then
    raise exception 'AUDIT: RLS disabled on storage.objects';
  end if;

  -- 2. anon: only SELECT on the public catalogue, nothing else
  for r in select table_name, privilege_type from information_schema.role_table_grants
           where grantee = 'anon' and table_schema = 'public'
             and not (privilege_type = 'SELECT' and table_name in ('job_sources','jobs','job_clusters')) loop
    raise exception 'AUDIT: anon has % on public.%', r.privilege_type, r.table_name;
  end loop;

  -- 3. authenticated: catalogue is read-only; sync_runs untouchable
  for r in select table_name, privilege_type from information_schema.role_table_grants
           where grantee = 'authenticated' and table_schema = 'public'
             and table_name in ('job_sources','jobs','job_clusters','sync_runs')
             and not (privilege_type = 'SELECT' and table_name <> 'sync_runs') loop
    raise exception 'AUDIT: authenticated has % on public.%', r.privilege_type, r.table_name;
  end loop;

  -- 4. no SECURITY DEFINER function and no function callable by API roles in public
  for r in select p.proname from pg_proc p join pg_namespace s on s.oid = p.pronamespace
           where s.nspname = 'public' and p.prosecdef loop
    raise exception 'AUDIT: SECURITY DEFINER function public.%', r.proname;
  end loop;
  for r in select p.proname, rol.rolname from pg_proc p join pg_namespace s on s.oid = p.pronamespace
           cross join (values ('anon'),('authenticated')) rol(rolname)
           where s.nspname = 'public' and has_function_privilege(rol.rolname, p.oid, 'execute')
             and p.prokind = 'f' and p.proname not like 'gin\_%' and p.proname not like 'gtrgm%'
             and p.proname not in ('set_limit','show_limit','show_trgm') loop
    raise exception 'AUDIT: % can execute public.%()', r.rolname, r.proname;
  end loop;

  -- 5. nothing on auth.users from triggers (no admin-privileged hook)
  select count(*) into n from pg_trigger t where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal;
  if n > 0 then raise exception 'AUDIT: % user trigger(s) on auth.users', n; end if;

  -- 6. every foreign key column set is covered by an index (first column match)
  for r in select c.conrelid::regclass as tbl, a.attname as col
           from pg_constraint c
           join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
           where c.contype = 'f' and c.connamespace = 'public'::regnamespace
             and not exists (select 1 from pg_index i where i.indrelid = c.conrelid and i.indkey[0] = c.conkey[1]) loop
    raise exception 'AUDIT: unindexed foreign key %.%', r.tbl, r.col;
  end loop;

  -- 7. every private table has an owner policy that mentions auth.uid()
  for r in select t.tablename from pg_tables t
           where t.schemaname = 'public'
             and t.tablename not in ('job_sources','jobs','job_clusters','sync_runs')
             and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = t.tablename
                             and p.qual like '%auth.uid()%' and p.permissive = 'PERMISSIVE') loop
    raise exception 'AUDIT: private table % has no owner policy', r.tablename;
  end loop;
  -- ...and no policy grants anything to anon or PUBLIC on private tables
  for r in select p.tablename, p.policyname from pg_policies p
           where p.schemaname = 'public' and p.tablename not in ('job_sources','jobs','job_clusters')
             and (p.roles && array['anon','public']::name[]) loop
    raise exception 'AUDIT: policy % on % is open to anon/public', r.policyname, r.tablename;
  end loop;

  -- 8. resume bucket private, size/mime limited, with exactly the four owner policies
  if not exists (select 1 from storage.buckets where id = 'resumes' and not public
                 and file_size_limit = 5242880 and allowed_mime_types = array['application/pdf']) then
    raise exception 'AUDIT: resumes bucket missing or not private/limited';
  end if;
  select count(*) into n from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'resumes\_objects\_%';
  if n <> 4 then raise exception 'AUDIT: expected 4 resumes policies, found %', n; end if;
  for r in select policyname from pg_policies where schemaname = 'storage' and tablename = 'objects'
           and (roles && array['anon','public']::name[]) loop
    raise exception 'AUDIT: storage policy % open to anon/public', r.policyname;
  end loop;
end $$;
select 'audit: ok' as result;
