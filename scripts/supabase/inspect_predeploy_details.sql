-- OrbiJob: READ-ONLY pre-deployment details for a Supabase project (run ONCE in the Dashboard SQL Editor).
-- Answers, in a single shareable JSON, the questions the first inspection could not: what the platform function
-- public.rls_auto_enable really is, which event triggers exist, whether the role that will run the migrations
-- (postgres) may do what migrations 1-5 need (create the history schema, install/move pg_trgm, reference auth.users,
-- create the private bucket, create policies on storage.objects), the default privileges, and how the migration history
-- looks. Catalog metadata only: no table contents, no users, no keys, no secrets.
-- Run:  paste -> Run -> copy the single cell (column "details") -> save as predeploy.json
-- If the SQL Editor rejects BEGIN/ROLLBACK, delete the first and last statements; everything in between is SELECT only.
begin read only;
select jsonb_pretty(jsonb_build_object(
  'predeploy_format', 1,
  'collected_at', now(),
  'server_version', current_setting('server_version'),
  'server_version_num', current_setting('server_version_num')::int,
  'database', current_database(),
  'connected_as', current_user,
  'effective_search_path', current_setting('search_path'),
  'role_settings', (select coalesce(jsonb_agg(jsonb_build_object(
        'role', case when s.setrole = 0 then '(all roles)' else pg_get_userbyid(s.setrole) end,
        'database', case when s.setdatabase = 0 then '(all databases)' else current_database() end,
        'settings', s.setconfig)), '[]')
      from pg_db_role_setting s where s.setdatabase in (0, (select oid from pg_database where datname = current_database()))
        and (s.setrole = 0 or pg_get_userbyid(s.setrole) in ('postgres', 'authenticator', 'anon', 'authenticated', 'service_role'))),

  -- who will run the migrations
  'postgres_role', (select jsonb_build_object(
        'superuser', r.rolsuper, 'createrole', r.rolcreaterole, 'createdb', r.rolcreatedb, 'bypassrls', r.rolbypassrls,
        'inherits', r.rolinherit,
        'member_of', (select coalesce(jsonb_agg(pg_get_userbyid(m.roleid) order by pg_get_userbyid(m.roleid)), '[]')
                      from pg_auth_members m where m.member = r.oid),
        'can_create_in_database', has_database_privilege(r.oid, current_database(), 'CREATE'))
      from pg_roles r where r.rolname = 'postgres'),
  'platform_roles_present', (select coalesce(jsonb_object_agg(n, exists (select 1 from pg_roles where rolname = n)), '{}')
      from unnest(array['anon', 'authenticated', 'service_role', 'authenticator', 'supabase_admin',
                        'supabase_storage_admin', 'supabase_auth_admin', 'dashboard_user']) n),

  'schemas', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', n.nspname, 'owner', pg_get_userbyid(n.nspowner),
        'postgres_usage', has_schema_privilege('postgres', n.oid, 'USAGE'),
        'postgres_create', has_schema_privilege('postgres', n.oid, 'CREATE')) order by n.nspname), '[]')
      from pg_namespace n where n.nspname in ('public', 'extensions', 'auth', 'storage', 'supabase_migrations')),

  -- pg_trgm: availability, trust and where CREATE EXTENSION would put it
  'pg_trgm', jsonb_build_object(
        'available_versions', (select coalesce(jsonb_agg(jsonb_build_object(
              'version', v.version, 'trusted', v.trusted, 'superuser_required', v.superuser, 'relocatable', v.relocatable)), '[]')
            from pg_available_extension_versions v where v.name = 'pg_trgm'),
        'installed', (select jsonb_build_object('schema', n.nspname, 'owner', pg_get_userbyid(e.extowner), 'version', e.extversion)
            from pg_extension e join pg_namespace n on n.oid = e.extnamespace where e.extname = 'pg_trgm'),
        'create_without_schema_would_use', (select s from (
            select trim(both '"' from unnest(string_to_array(replace(current_setting('search_path'), ' ', ''), ','))) as s) q
            where s <> '$user' and exists (select 1 from pg_namespace where nspname = s) and has_schema_privilege(current_user, s, 'CREATE')
            limit 1)),
  'extensions_installed', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', e.extname, 'schema', n.nspname, 'owner', pg_get_userbyid(e.extowner), 'version', e.extversion) order by e.extname), '[]')
      from pg_extension e join pg_namespace n on n.oid = e.extnamespace),

  -- Auth objects the schema depends on
  'auth', jsonb_build_object(
        'users_table_exists', to_regclass('auth.users') is not null,
        'postgres_can_reference_users', has_table_privilege('postgres', to_regclass('auth.users'), 'REFERENCES'),
        'uid_function_exists', to_regprocedure('auth.uid()') is not null,
        'authenticated_can_execute_uid', has_function_privilege('authenticated', to_regprocedure('auth.uid()'), 'EXECUTE'),
        'user_triggers', case when to_regclass('auth.users') is null then null else
            (select coalesce(jsonb_agg(t.tgname order by t.tgname), '[]') from pg_trigger t
             where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal) end),

  -- Storage objects the private bucket depends on
  'storage', jsonb_build_object(
        'buckets_exists', to_regclass('storage.buckets') is not null,
        'objects_exists', to_regclass('storage.objects') is not null,
        'buckets_owner', (select pg_get_userbyid(c.relowner) from pg_class c where c.oid = to_regclass('storage.buckets')),
        'objects_owner', (select pg_get_userbyid(c.relowner) from pg_class c where c.oid = to_regclass('storage.objects')),
        'objects_rls_enabled', (select c.relrowsecurity from pg_class c where c.oid = to_regclass('storage.objects')),
        'postgres_can_insert_buckets', has_table_privilege('postgres', to_regclass('storage.buckets'), 'INSERT'),
        'postgres_can_update_buckets', has_table_privilege('postgres', to_regclass('storage.buckets'), 'UPDATE'),
        'postgres_is_objects_owner_or_member', (select pg_has_role('postgres', c.relowner, 'USAGE')
            from pg_class c where c.oid = to_regclass('storage.objects')),
        'buckets_columns', (select coalesce(jsonb_agg(column_name order by ordinal_position), '[]')
            from information_schema.columns where table_schema = 'storage' and table_name = 'buckets'),
        'foldername_exists', to_regprocedure('storage.foldername(text)') is not null,
        'objects_policies', (select coalesce(jsonb_agg(policyname order by policyname), '[]') from pg_policies
            where schemaname = 'storage' and tablename = 'objects'),
        'triggers_on_storage_tables', (select coalesce(jsonb_agg(c.relname || '.' || t.tgname order by c.relname, t.tgname), '[]')
            from pg_trigger t join pg_class c on c.oid = t.tgrelid
            where c.relnamespace = 'storage'::regnamespace and not t.tgisinternal),
        'buckets', case when to_regclass('storage.buckets') is null then null else
            coalesce((select (xpath('//j/text()', query_to_xml(
              'select coalesce(jsonb_agg(jsonb_build_object(''id'', id, ''public'', public)), ''[]''::jsonb)::text as j from storage.buckets',
              false, false, '')))[1]::text::jsonb), '[]'::jsonb) end),

  -- event triggers (they can change or block DDL) and the platform function that was reported
  'event_triggers', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', e.evtname, 'event', e.evtevent, 'tags', e.evttags, 'enabled', e.evtenabled,
        'owner', pg_get_userbyid(e.evtowner), 'function', fn.nspname || '.' || p.proname) order by e.evtname), '[]')
      from pg_event_trigger e join pg_proc p on p.oid = e.evtfoid join pg_namespace fn on fn.oid = p.pronamespace),
  'public_functions_detail', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', p.proname,
        'identity_args', pg_get_function_identity_arguments(p.oid),
        'owner', pg_get_userbyid(p.proowner),
        'language', l.lanname,
        'returns', p.prorettype::regtype::text,
        'security_definer', p.prosecdef,
        'config', p.proconfig,
        'acl', p.proacl::text,
        'anon_can_execute', has_function_privilege('anon', p.oid, 'EXECUTE'),
        'authenticated_can_execute', has_function_privilege('authenticated', p.oid, 'EXECUTE'),
        'bound_event_triggers', (select coalesce(jsonb_agg(e.evtname), '[]') from pg_event_trigger e where e.evtfoid = p.oid),
        'extension_member', exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e'),
        'comment', obj_description(p.oid, 'pg_proc'),
        'definition', case when p.prokind = 'f' then pg_get_functiondef(p.oid) end) order by p.proname), '[]')
      from pg_proc p join pg_language l on l.oid = p.prolang
      where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'),

  -- default privileges, decoded: who receives what on objects created in public
  'default_privileges_public', (select coalesce(jsonb_agg(jsonb_build_object(
        'created_by', pg_get_userbyid(d.defaclrole), 'object_type',
        case d.defaclobjtype when 'r' then 'table' when 'S' then 'sequence' when 'f' then 'function' when 'T' then 'type' else d.defaclobjtype::text end,
        'grantee', case when a.grantee = 0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
        'privilege', a.privilege_type) order by pg_get_userbyid(d.defaclrole), d.defaclobjtype, a.privilege_type), '[]')
      from pg_default_acl d, lateral aclexplode(d.defaclacl) a where d.defaclnamespace = 'public'::regnamespace),
  'default_privileges_global', (select coalesce(jsonb_agg(jsonb_build_object(
        'created_by', pg_get_userbyid(d.defaclrole), 'object_type', d.defaclobjtype::text,
        'grantee', case when a.grantee = 0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
        'privilege', a.privilege_type)), '[]')
      from pg_default_acl d, lateral aclexplode(d.defaclacl) a where d.defaclnamespace = 0),

  -- effective migration history
  'migration_history', jsonb_build_object(
        'schema_exists', exists (select 1 from pg_namespace where nspname = 'supabase_migrations'),
        'table_exists', to_regclass('supabase_migrations.schema_migrations') is not null,
        'versions', case when to_regclass('supabase_migrations.schema_migrations') is null then null else
            coalesce((select jsonb_agg(v order by v) from (
              select unnest(xpath('//version/text()', query_to_xml(
                'select version from supabase_migrations.schema_migrations', false, false, '')))::text as v) s), '[]'::jsonb) end),

  -- anything of OrbiJob's own already present (names only)
  'orbijob_objects_present', jsonb_build_object(
        'public_tables', (select coalesce(jsonb_agg(c.relname order by c.relname), '[]') from pg_class c
            where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')),
        'resumes_bucket', case when to_regclass('storage.buckets') is null then null else
            coalesce((select (xpath('//j/text()', query_to_xml(
              'select count(*)::text as j from storage.buckets where id = ''resumes''', false, false, '')))[1]::text::int), 0) end)
)) as details;
rollback;
