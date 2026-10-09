-- Database that already ran migrations 1-4 (original quota trigger) with a full favourites list, then migration 5.
\set ON_ERROR_STOP on
\set U '00000000-0000-0000-0000-0000000000e1'
set role authenticated;
select set_config('request.jwt.claim.sub', :'U', false);
do $$
declare U constant text := '00000000-0000-0000-0000-0000000000e1';
begin
  perform tests.count(format($q$select 1 from public.saved_jobs where user_id = %L$q$, U), 1000);
  insert into public.saved_jobs (user_id, job_key, snapshot) values (U::uuid, 'k5', '{"v":9}')
    on conflict (user_id, job_key) do update set snapshot = excluded.snapshot;
  if (select snapshot ->> 'v' from public.saved_jobs where job_key = 'k5') <> '9' then raise exception 'upsert did not update'; end if;
  perform tests.fails(format($q$insert into public.saved_jobs (user_id, job_key, snapshot) values (%L, 'new', '{"a":1}')$q$, U), 'quota exceeded');
end $$;
reset role;
\echo 'upgrade path: ok'
