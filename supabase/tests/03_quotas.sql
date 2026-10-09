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

  -- Regression (favourites at the cap): existing rows stay editable and re-saving them (upsert) must not hit the quota.
  insert into public.saved_jobs (user_id, job_key, snapshot) values (U::uuid, 'k1', '{"v":2}')
    on conflict (user_id, job_key) do update set snapshot = excluded.snapshot;
  if (select snapshot ->> 'v' from public.saved_jobs where job_key = 'k1') is distinct from '2' then
    raise exception 'upsert of an existing favourite at the cap did not update the row';
  end if;
  update public.saved_jobs set note = 'still editable' where job_key = 'k2';
  if (select count(*) from public.saved_jobs where note = 'still editable') <> 1 then raise exception 'update at the cap failed'; end if;
  -- ...while a NEW key through upsert, or a plain insert, is still refused; a duplicate key is a unique violation
  perform tests.fails(format($q$insert into public.saved_jobs (user_id, job_key, snapshot) values (%L, 'brand-new', '{"a":1}')
    on conflict (user_id, job_key) do update set snapshot = excluded.snapshot$q$, U), 'quota exceeded');
  perform tests.fails(format($q$insert into public.saved_jobs (user_id, job_key, snapshot) values (%L, 'k3', '{"a":1}')$q$, U), 'duplicate key');
  perform tests.count(format($q$select 1 from public.saved_jobs where user_id = %L$q$, U), 1000);

  insert into public.applications (user_id, job_snapshot) select U::uuid, '{}' from generate_series(1, 2000) g;
  perform tests.fails(format($q$insert into public.applications (user_id, job_snapshot) values (%L, '{}')$q$, U), 'quota exceeded');
end $$;
reset role;
\echo 'quotas: ok'
