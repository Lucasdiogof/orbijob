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
grant usage on schema storage to anon, authenticated, service_role;
-- Supabase grants broad table privileges to the API roles by default; RLS and the hardening migration are the real gates.
grant select, insert, update, delete on all tables in schema storage to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;

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
