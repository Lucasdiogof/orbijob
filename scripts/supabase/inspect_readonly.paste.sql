select jsonb_pretty(jsonb_build_object(
  'format', 1,
  'collected_at', now(),
  'server_version', current_setting('server_version'),
  'database', current_database(),
  'connected_as', current_user,
  'schemas', (select coalesce(jsonb_agg(nspname order by nspname), '[]') from pg_namespace
              where nspname !~ '^pg_' and nspname <> 'information_schema'),
  'extensions', (select coalesce(jsonb_agg(jsonb_build_object('name', e.extname, 'schema', n.nspname, 'version', e.extversion)
                                           order by e.extname), '[]')
                 from pg_extension e join pg_namespace n on n.oid = e.extnamespace),
  'migration_versions', case when to_regclass('supabase_migrations.schema_migrations') is null then null else
      coalesce((select jsonb_agg(v order by v) from (
        select unnest(xpath('//version/text()', query_to_xml(
          'select version from supabase_migrations.schema_migrations', false, false, '')))::text as v) s), '[]'::jsonb) end,
  'public_tables', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', c.relname, 'rls', c.relrowsecurity,
        'owner', pg_get_userbyid(c.relowner)) order by c.relname), '[]')
      from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')),
  'public_policies', (select coalesce(jsonb_agg(jsonb_build_object(
        'table', tablename, 'name', policyname, 'command', cmd, 'permissive', permissive, 'roles', roles)
        order by tablename, policyname), '[]') from pg_policies where schemaname = 'public'),
  'public_triggers', (select coalesce(jsonb_agg(jsonb_build_object('table', c.relname, 'name', t.tgname)
        order by c.relname, t.tgname), '[]')
      from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where c.relnamespace = 'public'::regnamespace and not t.tgisinternal),
  'public_functions', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', p.proname, 'security_definer', p.prosecdef,
        'anon_can_execute', has_function_privilege('anon', p.oid, 'execute'),
        'authenticated_can_execute', has_function_privilege('authenticated', p.oid, 'execute'),
        'quota_has_key_arg', position('key_column' in p.prosrc) > 0) order by p.proname), '[]')
      from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'),
  'public_grants', (select coalesce(jsonb_agg(jsonb_build_object('role', grantee, 'table', table_name, 'privileges', privs)
        order by grantee, table_name), '[]') from (
        select grantee, table_name, jsonb_agg(privilege_type order by privilege_type) as privs
        from information_schema.role_table_grants
        where table_schema = 'public' and grantee in ('anon', 'authenticated', 'service_role')
        group by grantee, table_name) g),
  'default_privileges_public', (select coalesce(jsonb_agg(jsonb_build_object(
        'owner', pg_get_userbyid(d.defaclrole), 'object_type', d.defaclobjtype, 'acl', d.defaclacl::text)), '[]')
      from pg_default_acl d where d.defaclnamespace = 'public'::regnamespace),
  'auth_users_triggers', case when to_regclass('auth.users') is null then null else
      (select coalesce(jsonb_agg(t.tgname order by t.tgname), '[]') from pg_trigger t
       where t.tgrelid = to_regclass('auth.users') and not t.tgisinternal) end,
  'storage_policies', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', policyname, 'command', cmd, 'roles', roles) order by policyname), '[]')
      from pg_policies where schemaname = 'storage' and tablename = 'objects'),
  'storage_buckets', case when to_regclass('storage.buckets') is null then null else
      coalesce((select (xpath('//j/text()', query_to_xml(
        'select coalesce(jsonb_agg(jsonb_build_object(''id'', id, ''public'', public, ''file_size_limit'', file_size_limit, '
        || '''allowed_mime_types'', allowed_mime_types) order by id), ''[]''::jsonb)::text as j from storage.buckets',
        false, false, '')))[1]::text::jsonb), '[]'::jsonb) end
)) as inspection;
