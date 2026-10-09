do $$
declare r record; n int;
begin
  for r in select c.relname from pg_class c join pg_namespace s on s.oid = c.relnamespace
           where s.nspname = 'public' and c.relkind in ('r','p') and not c.relrowsecurity loop
    raise exception 'AUDIT: RLS disabled on public.%', r.relname;
  end loop;
  if not (select relrowsecurity from pg_class where oid = 'storage.objects'::regclass) then
    raise exception 'AUDIT: RLS disabled on storage.objects';
  end if;
  for r in select table_name, privilege_type from information_schema.role_table_grants
           where grantee = 'anon' and table_schema = 'public'
             and not (privilege_type = 'SELECT' and table_name in ('job_sources','jobs','job_clusters')) loop
    raise exception 'AUDIT: anon has % on public.%', r.privilege_type, r.table_name;
  end loop;
  for r in select table_name, privilege_type from information_schema.role_table_grants
           where grantee = 'authenticated' and table_schema = 'public'
             and table_name in ('job_sources','jobs','job_clusters','sync_runs')
             and not (privilege_type = 'SELECT' and table_name <> 'sync_runs') loop
    raise exception 'AUDIT: authenticated has % on public.%', r.privilege_type, r.table_name;
  end loop;
  for r in select p.oid, p.proname, p.prosecdef, p.prorettype::regtype::text as ret,
                  has_function_privilege('anon', p.oid, 'execute') as anon_exec,
                  has_function_privilege('authenticated', p.oid, 'execute') as auth_exec
           from pg_proc p join pg_namespace s on s.oid = p.pronamespace
           where s.nspname = 'public' and p.prokind = 'f'
             and p.proname not like 'gin\_%' and p.proname not like 'gtrgm%'
             and p.proname not in ('set_limit','show_limit','show_trgm') loop
    if r.ret = 'event_trigger' and exists (select 1 from pg_event_trigger e where e.evtfoid = r.oid) then
      raise notice 'AUDIT-NOTE: platform event-trigger function public.%() (security definer: %, anon exec: %, authenticated exec: %)',
        r.proname, r.prosecdef, r.anon_exec, r.auth_exec;
      continue;
    end if;
    if r.prosecdef then raise exception 'AUDIT: SECURITY DEFINER function public.%', r.proname; end if;
    if r.anon_exec then raise exception 'AUDIT: anon can execute public.%()', r.proname; end if;
    if r.auth_exec then raise exception 'AUDIT: authenticated can execute public.%()', r.proname; end if;
  end loop;
  select count(*) into n from pg_trigger t where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal;
  if n > 0 then raise exception 'AUDIT: % user trigger(s) on auth.users', n; end if;
  for r in select c.conrelid::regclass as tbl, a.attname as col
           from pg_constraint c
           join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
           where c.contype = 'f' and c.connamespace = 'public'::regnamespace
             and not exists (select 1 from pg_index i where i.indrelid = c.conrelid and i.indkey[0] = c.conkey[1]) loop
    raise exception 'AUDIT: unindexed foreign key %.%', r.tbl, r.col;
  end loop;
  for r in select t.tablename from pg_tables t
           where t.schemaname = 'public'
             and t.tablename not in ('job_sources','jobs','job_clusters','sync_runs')
             and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = t.tablename
                             and p.qual like '%auth.uid()%' and p.permissive = 'PERMISSIVE') loop
    raise exception 'AUDIT: private table % has no owner policy', r.tablename;
  end loop;
  for r in select p.tablename, p.policyname from pg_policies p
           where p.schemaname = 'public' and p.tablename not in ('job_sources','jobs','job_clusters')
             and (p.roles && array['anon','public']::name[]) loop
    raise exception 'AUDIT: policy % on % is open to anon/public', r.policyname, r.tablename;
  end loop;
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
