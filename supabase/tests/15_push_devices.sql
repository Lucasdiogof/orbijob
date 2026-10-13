-- Push (migration 20261024000000) on a REAL PostgreSQL (CI: 16 and 17): the privilege model. A person writes and removes only their own device
-- rows and never pushed_at; the sender's functions live in `ops` and no API role runs them; service_role gains nothing on notifications or
-- devices. The finer rules are covered by worker/test/push-devices.test.ts.
\set ON_ERROR_STOP on

insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000d1'), ('00000000-0000-4000-8000-0000000000d2') on conflict do nothing;
insert into public.notifications (user_id, title) values ('00000000-0000-4000-8000-0000000000d1', 'A new job');

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000d1', false);
do $$
begin
  insert into public.push_devices (user_id, token, platform, locale)
    values ('00000000-0000-4000-8000-0000000000d1', 'push-test-token-d1-xxxxxxxxxxxxxxxx', 'android', 'pt-BR');
  perform tests.count('select 1 from public.push_devices', 1);
  perform tests.fails($q$insert into public.push_devices (user_id, token, platform) values ('00000000-0000-4000-8000-0000000000d2', 'push-other-xxxxxxxxxxxxxxxxxxxxx', 'ios')$q$, 'row-level security');
  perform tests.fails($q$update public.push_devices set user_id = '00000000-0000-4000-8000-0000000000d2'$q$, 'permission denied');
  perform tests.fails($q$update public.notifications set pushed_at = now()$q$, 'permission denied');
  perform tests.fails($q$select * from ops.push_claim(10)$q$, 'permission denied');
  perform tests.fails($q$select ops.push_forget_tokens('{}')$q$, 'permission denied');
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000d2', false);
do $$
begin
  perform tests.count('select 1 from public.push_devices', 0);
  perform tests.affected('delete from public.push_devices', 0);
end $$;
reset role;

set role anon;
do $$
begin
  perform tests.fails($q$select * from public.push_devices$q$, 'permission denied');
end $$;
reset role;

set role service_role;
do $$
begin
  perform tests.fails($q$select * from ops.push_claim(10)$q$, 'permission denied');
  perform tests.fails($q$select * from public.notifications$q$, 'permission denied');
  perform tests.fails($q$select * from public.push_devices$q$, 'permission denied');
end $$;
reset role;

-- the owner (the Edge Function's connection) claims once
do $$
begin
  perform tests.count('select 1 from ops.push_claim(10)', 1);
  perform tests.count('select 1 from ops.push_claim(10)', 0);
end $$;

-- cleanup
delete from public.push_devices;
delete from public.notifications where user_id in ('00000000-0000-4000-8000-0000000000d1', '00000000-0000-4000-8000-0000000000d2');
delete from auth.users where id in ('00000000-0000-4000-8000-0000000000d1', '00000000-0000-4000-8000-0000000000d2');
