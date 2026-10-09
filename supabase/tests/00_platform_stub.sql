-- Minimal stand-in for the Supabase platform objects the migrations depend on (roles, auth, storage).
-- TEST ONLY: never run against a real project, where these objects are provided by the platform.
-- roles are cluster-wide: create only if missing so the suite is re-runnable on one server
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin noinherit; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin noinherit; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin noinherit bypassrls; end if;
end $$;
create schema extensions;
create schema auth;
create table auth.users (id uuid primary key, email text);
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid
$$;
grant usage on schema auth, extensions to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

create schema storage;
create table storage.buckets (
  id text primary key, name text not null, public boolean default false,
  file_size_limit bigint, allowed_mime_types text[]
);
create table storage.objects (
  id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets(id),
  name text, owner uuid, metadata jsonb
);
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[] language plpgsql as $$
declare _parts text[];
begin
  select string_to_array(name, '/') into _parts;
  return _parts[1:array_length(_parts, 1) - 1];
end $$;
-- The hosted platform refuses direct DELETEs on its storage tables (files would be left behind). Mimicked here from
-- documented behaviour; the Storage API sets the bypass GUC internally. NOT verified against a live project.
create function storage.protect_delete() returns trigger language plpgsql as $$
begin
  if coalesce(current_setting('storage.allow_delete_query', true), 'false') <> 'true' then
    raise exception 'Direct deletion from storage tables is not allowed. Use the Storage API instead.';
  end if;
  return old;
end $$;
create trigger protect_buckets_delete before delete on storage.buckets for each statement execute function storage.protect_delete();
create trigger protect_objects_delete before delete on storage.objects for each statement execute function storage.protect_delete();
grant usage on schema storage to anon, authenticated, service_role;
-- Supabase grants broad table privileges to the API roles by default; RLS and the hardening migration are the real gates.
grant select, insert, update, delete on all tables in schema storage to anon, authenticated, service_role;
-- Observed on the real project (2026-10-09, PostgreSQL 17.11): objects created by `postgres` in public give the API roles
-- only TRUNCATE, REFERENCES, TRIGGER and MAINTAIN (acl {anon=Dxtm/postgres, authenticated=Dxtm/postgres, service_role=Dxtm/postgres}).
-- NOT select/insert/update/delete: service_role bypasses RLS but has no table privilege until a migration grants it.
-- (MAINTAIN exists only from PostgreSQL 17; it is omitted here so the stub runs on 16 as well.)
alter default privileges in schema public grant truncate, references, trigger on tables to anon, authenticated, service_role;

-- Hosted Supabase projects ship an event trigger that enables RLS on every table created in `public`, implemented by
-- `public.rls_auto_enable()` (SECURITY DEFINER, executable by anon/authenticated through the default PUBLIC EXECUTE).
-- Reported by the owner's real inspection of project rpmlfxwebnlxnwadyvle (2026-10-09). The body below is an
-- APPROXIMATION written for tests; the real definition must be read with scripts/supabase/inspect_predeploy_details.sql.
create function public.rls_auto_enable() returns event_trigger language plpgsql security definer set search_path = pg_catalog as $$
declare cmd record;
begin
  for cmd in select * from pg_event_trigger_ddl_commands()
             where command_tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO') and object_type in ('table', 'partitioned table') loop
    if cmd.schema_name = 'public' then
      execute format('alter table if exists %s enable row level security', cmd.object_identity);
    end if;
  end loop;
end $$;
create event trigger ensure_rls on ddl_command_end when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  execute function public.rls_auto_enable();
-- Default privileges of the platform admin role (observed on the real project: broad grants for supabase_admin objects)
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'supabase_admin') then create role supabase_admin nologin; end if;
end $$;
alter default privileges for role supabase_admin in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges for role supabase_admin in schema public grant all on functions to anon, authenticated, service_role;

-- assertion helpers
create schema tests;
grant usage on schema tests to anon, authenticated, service_role;
create function tests.fails(q text, pat text) returns void language plpgsql as $$
declare failed boolean := false;
begin
  begin
    execute q;
  exception when others then
    failed := true;
    if sqlerrm !~* pat then raise exception 'wrong error for [%]: % (wanted %)', q, sqlerrm, pat; end if;
  end;
  if not failed then raise exception 'expected failure but succeeded: %', q; end if;
end $$;
create function tests.count(q text, expected int) returns void language plpgsql as $$
declare n int;
begin
  execute 'select count(*) from (' || q || ') t' into n;
  if n <> expected then raise exception 'expected % rows, got %: %', expected, n, q; end if;
end $$;
create function tests.affected(q text, expected int) returns void language plpgsql as $$
declare n int;
begin
  execute q;
  get diagnostics n = row_count;
  if n <> expected then raise exception 'expected % affected rows, got %: %', expected, n, q; end if;
end $$;
grant execute on all functions in schema tests to anon, authenticated, service_role;
