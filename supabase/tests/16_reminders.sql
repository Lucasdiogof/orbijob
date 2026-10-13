-- Application reminders (migration 20261025000000) on a REAL PostgreSQL (CI: 16 and 17): one reminder per date, only for open processes, never
-- for another account, and no API role can run the function. Details: worker/test/reminders.test.ts.
\set ON_ERROR_STOP on

insert into auth.users (id) values ('00000000-0000-4000-8000-0000000000e1'), ('00000000-0000-4000-8000-0000000000e2') on conflict do nothing;
insert into public.applications (user_id, job_snapshot, stage, interview_at, follow_up_at) values
  ('00000000-0000-4000-8000-0000000000e1', '{"title":"Physio","company":"Clinic","originalUrl":"https://r.test/1"}', 'interview', now() + interval '5 hours', null),
  ('00000000-0000-4000-8000-0000000000e1', '{"title":"Closed one"}', 'rejected', now() + interval '5 hours', null),
  ('00000000-0000-4000-8000-0000000000e2', '{"title":"Other"}', 'applied', null, now() - interval '1 hour');
do $$
begin
  if ops.reminders_run() <> 'ok:interview=1,follow_up=1' then raise exception 'unexpected first run'; end if;
  if ops.reminders_run() <> 'ok:interview=0,follow_up=0' then raise exception 'not idempotent'; end if;
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-0000000000e1', false);
do $$
begin
  perform tests.count($q$select 1 from public.notifications where kind = 'interview' and title = 'Physio'$q$, 1);
  perform tests.count($q$select 1 from public.notifications where kind = 'follow_up'$q$, 0);
  perform tests.fails($q$select ops.reminders_run()$q$, 'permission denied');
end $$;
reset role;
set role service_role;
do $$ begin perform tests.fails($q$select ops.reminders_run()$q$, 'permission denied'); end $$;
reset role;

-- cleanup
delete from public.notifications where user_id in ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000e2');
delete from public.applications where user_id in ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000e2');
delete from auth.users where id in ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000e2');
