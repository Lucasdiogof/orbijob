-- Trusted terms acceptance (supabase/proposals/20261028000000_terms_acceptances.sql, applied by run.sh before this test): a person cannot write the
-- table directly, cannot change or remove a record, an unknown version is refused, the call is idempotent, people are isolated, anon cannot run it.
\set ON_ERROR_STOP on

insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000e1'), ('00000000-0000-4000-8000-0000000000e2') on conflict do nothing;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000e1', false);
do $$
declare first_at timestamptz; again timestamptz;
begin
  first_at := public.record_terms_acceptance('2026-10-14', '2026-10-20');
  perform tests.count('select 1 from public.terms_acceptances', 1);
  -- idempotent: same record, same server timestamp, still one row
  again := public.record_terms_acceptance('2026-10-14', '2026-10-20');
  if again is distinct from first_at then raise exception 'not idempotent: % vs %', first_at, again; end if;
  perform tests.count('select 1 from public.terms_acceptances', 1);
  -- versions the server does not know are refused
  perform tests.fails($q$select public.record_terms_acceptance('1999-01-01', '2026-10-20')$q$, 'unknown legal version');
  perform tests.fails($q$select public.record_terms_acceptance('2026-10-14', 'x')$q$, 'unknown legal version');
  -- no direct writes
  perform tests.fails($q$insert into public.terms_acceptances (user_id, terms_version, privacy_version) values ('00000000-0000-4000-8000-0000000000e1', '2026-10-14', 'forged')$q$, 'permission denied');
  perform tests.fails($q$update public.terms_acceptances set accepted_at = now() - interval '1 year'$q$, 'permission denied');
  perform tests.fails($q$delete from public.terms_acceptances$q$, 'permission denied');
  -- the allow-list is not readable
  perform tests.fails($q$select * from ops.legal_versions$q$, 'permission denied');
end $$;

-- another person: sees nothing of the first, gets their own record
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000e2', false);
do $$
begin
  perform tests.count('select 1 from public.terms_acceptances', 0);
  perform public.record_terms_acceptance('2026-10-14', '2026-10-20');
  perform tests.count('select 1 from public.terms_acceptances', 1);
end $$;
reset role;

-- without a session the function refuses; anon cannot run it nor read the table
set role authenticated;
select set_config('request.jwt.claim.sub', '', false);
do $$ begin
  perform tests.fails($q$select public.record_terms_acceptance('2026-10-14', '2026-10-20')$q$, 'not authenticated');
end $$;
reset role;
set role anon;
do $$ begin
  perform tests.fails($q$select public.record_terms_acceptance('2026-10-14', '2026-10-20')$q$, 'permission denied');
  perform tests.fails($q$select * from public.terms_acceptances$q$, 'permission denied');
end $$;
reset role;

-- the owner sees both records; the record goes away with the account
do $$ begin perform tests.count('select 1 from public.terms_acceptances', 2); end $$;
delete from auth.users where id = '00000000-0000-4000-8000-0000000000e1';
do $$ begin perform tests.count('select 1 from public.terms_acceptances', 1); end $$;
delete from auth.users where id = '00000000-0000-4000-8000-0000000000e2';
