-- Per-user row quotas (resumes, saved jobs, saved searches, applications).
\set ON_ERROR_STOP on
\set U '00000000-0000-0000-0000-0000000000c1'
insert into auth.users (id) values (:'U');
insert into professional_profiles (id, user_id, name) values ('10000000-0000-0000-0000-0000000000c1', :'U', 'Q');
set role authenticated;
select set_config('request.jwt.claim.sub', :'U', false);
do $$
declare U constant text := '00000000-0000-0000-0000-0000000000c1'; i int;
begin
  for i in 1..10 loop
    insert into public.resumes (profile_id, user_id, storage_path) values ('10000000-0000-0000-0000-0000000000c1', U::uuid, U || '/' || i || '.pdf');
  end loop;
  perform tests.fails(format($q$insert into public.resumes (profile_id,user_id,storage_path) values ('10000000-0000-0000-0000-0000000000c1',%L,%L)$q$, U, U || '/11.pdf'), 'quota exceeded');
  -- freeing a slot allows a new row again
  delete from public.resumes where storage_path = U || '/1.pdf';
  insert into public.resumes (profile_id, user_id, storage_path) values ('10000000-0000-0000-0000-0000000000c1', U::uuid, U || '/12.pdf');

  insert into public.saved_searches (user_id, query) select U::uuid, jsonb_build_object('n', g) from generate_series(1, 100) g;
  perform tests.fails(format($q$insert into public.saved_searches (user_id, query) values (%L, '{}')$q$, U), 'quota exceeded');

  insert into public.saved_jobs (user_id, job_key, snapshot) select U::uuid, 'k' || g, '{"a":1}' from generate_series(1, 1000) g;
  perform tests.fails(format($q$insert into public.saved_jobs (user_id, job_key, snapshot) values (%L, 'over', '{"a":1}')$q$, U), 'quota exceeded');

  insert into public.applications (user_id, job_snapshot) select U::uuid, '{}' from generate_series(1, 2000) g;
  perform tests.fails(format($q$insert into public.applications (user_id, job_snapshot) values (%L, '{}')$q$, U), 'quota exceeded');
end $$;
reset role;
\echo 'quotas: ok'
