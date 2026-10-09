-- Behavioural tests: two users, cross-access attempts through every table, storage, triggers and guards.
\set ON_ERROR_STOP on
\set A '00000000-0000-0000-0000-00000000000a'
\set B '00000000-0000-0000-0000-00000000000b'
insert into auth.users (id) values (:'A'), (:'B');
insert into job_sources values ('open-src','CONDITIONAL',null,true), ('closed-src','RESEARCH',null,false);
insert into jobs (id, source_id, external_id, company, title, last_checked_at, original_url, fingerprint, canonical_url) values
  ('c0000000-0000-0000-0000-000000000001','open-src','1','Co','Visible job', now(), 'https://x/1', 'f1', 'https://x/1'),
  ('c0000000-0000-0000-0000-000000000002','closed-src','2','Co','Hidden job', now(), 'https://x/2', 'f2', 'https://x/2');
insert into professional_profiles (id, user_id, name) values
  ('10000000-0000-0000-0000-00000000000a', :'A', 'A profile'), ('10000000-0000-0000-0000-00000000000b', :'B', 'B profile');
insert into applications (id, user_id, job_snapshot) values ('20000000-0000-0000-0000-00000000000b', :'B', '{"title":"x"}');
insert into user_preferences (user_id, theme) values (:'B', 'dark');
insert into saved_jobs (user_id, job_key, snapshot) values (:'B', 'lever:9', '{"title":"b-fav"}');
insert into saved_searches (user_id, query) values (:'B', '{"q":"b-search"}');
insert into resumes (profile_id, user_id, storage_path) values ('10000000-0000-0000-0000-00000000000b', :'B', :'B' || '/cv.pdf');
insert into storage.objects (bucket_id, name, owner) values ('resumes', :'B' || '/cv.pdf', :'B');

-- ===== user A =====
set role authenticated;
select set_config('request.jwt.claim.sub', :'A', false);
do $$
declare A constant text := '00000000-0000-0000-0000-00000000000a';
        B constant text := '00000000-0000-0000-0000-00000000000b';
        PA constant text := '10000000-0000-0000-0000-00000000000a';
        PB constant text := '10000000-0000-0000-0000-00000000000b';
        t text;
begin
  -- reads: nothing of B is visible anywhere
  foreach t in array array['professional_profiles','experiences','education','credentials','resumes','saved_jobs',
      'saved_searches','viewed_jobs','applications','application_events','reminders','user_preferences'] loop
    perform tests.count(format('select 1 from public.%I where user_id = %L', t, B), 0);
  end loop;
  perform tests.count('select 1 from storage.objects', 0);

  -- writes into B's rows / as B
  perform tests.affected(format($q$update public.professional_profiles set name='pwn' where user_id=%L$q$, B), 0);
  perform tests.affected(format($q$delete from public.applications where user_id=%L$q$, B), 0);
  perform tests.affected(format($q$update public.user_preferences set theme='light' where user_id=%L$q$, B), 0);
  perform tests.fails(format($q$insert into public.saved_jobs (user_id, job_key, snapshot) values (%L,'k','{"a":1}')$q$, B), 'row-level security');
  perform tests.fails(format($q$insert into public.user_preferences (user_id) values (%L)$q$, B), 'row-level security');
  perform tests.fails(format($q$insert into public.saved_searches (user_id, query) values (%L,'{}')$q$, B), 'row-level security');

  -- linking own rows to B's parents
  perform tests.fails(format($q$insert into public.experiences (profile_id,user_id,company,title) values (%L,%L,'c','t')$q$, PB, A), 'row-level security');
  perform tests.fails(format($q$insert into public.education (profile_id,user_id,institution) values (%L,%L,'x')$q$, PB, A), 'row-level security');
  perform tests.fails(format($q$insert into public.credentials (profile_id,user_id,kind,name) values (%L,%L,'license','x')$q$, PB, A), 'row-level security');
  perform tests.fails(format($q$insert into public.applications (user_id,profile_id,job_snapshot) values (%L,%L,'{}')$q$, A, PB), 'row-level security');
  perform tests.fails(format($q$insert into public.application_events (application_id,user_id,stage) values ('20000000-0000-0000-0000-00000000000b',%L,'offer')$q$, A), 'row-level security');
  perform tests.fails(format($q$insert into public.reminders (user_id,application_id,due_at,text) values (%L,'20000000-0000-0000-0000-00000000000b',now(),'x')$q$, A), 'row-level security');
  perform tests.fails(format($q$insert into public.resumes (profile_id,user_id,storage_path) values (%L,%L,%L)$q$, PB, A, A||'/cv.pdf'), 'row-level security');
  perform tests.fails(format($q$insert into public.resumes (profile_id,user_id,storage_path) values (%L,%L,%L)$q$, PA, A, B||'/cv.pdf'), 'check constraint');
  perform tests.fails(format($q$insert into public.resumes (profile_id,user_id,storage_path) values (%L,%L,%L)$q$, PA, A, A||'/../'||B||'/cv.pdf'), 'check constraint');

  -- catalogue is read-only and non-redistributable jobs are invisible
  perform tests.count('select 1 from public.jobs', 1);
  perform tests.fails($q$insert into public.jobs (source_id,external_id,company,title,last_checked_at,original_url,fingerprint,canonical_url) values ('open-src','9','c','t',now(),'u','f','c')$q$, 'permission denied');
  perform tests.fails($q$update public.job_sources set can_redistribute = true$q$, 'permission denied');
  perform tests.fails($q$select * from public.sync_runs$q$, 'permission denied');
  perform tests.fails($q$insert into public.saved_jobs (user_id,job_id,job_key) values ('00000000-0000-0000-0000-00000000000a','c0000000-0000-0000-0000-000000000002','hidden')$q$, 'row-level security|check constraint');

  -- storage: own folder only
  perform tests.fails(format($q$insert into storage.objects (bucket_id,name,owner) values ('resumes',%L,%L)$q$, B||'/evil.pdf', A), 'row-level security');
  perform tests.fails($q$insert into storage.objects (bucket_id,name,owner) values ('resumes','loose.pdf','00000000-0000-0000-0000-00000000000a')$q$, 'row-level security');
  perform tests.fails($q$insert into storage.objects (bucket_id,name,owner) values ('other','x/y.pdf','00000000-0000-0000-0000-00000000000a')$q$, 'foreign key|row-level security');
  -- the Storage API deletes with the bypass setting on; RLS must still hide B's object from A
  perform set_config('storage.allow_delete_query', 'true', true);
  perform tests.affected(format($q$delete from storage.objects where name=%L$q$, B||'/cv.pdf'), 0);
  perform set_config('storage.allow_delete_query', 'false', true);
  perform tests.fails($q$delete from storage.objects where name = 'whatever'$q$, 'Direct deletion from storage tables is not allowed');
end $$;

-- own data works, and the stage history is written by the trigger
do $$
declare A constant text := '00000000-0000-0000-0000-00000000000a'; app uuid; n int;
begin
  insert into public.user_preferences (user_id, theme, locale, countries_of_interest) values (A::uuid, 'dark', 'pt', array['BR','PT']);
  insert into public.saved_jobs (user_id, job_key, snapshot) values (A::uuid, 'lever:1', '{"title":"x"}');
  insert into public.saved_jobs (user_id, job_id, job_key) values (A::uuid, 'c0000000-0000-0000-0000-000000000001', 'open-src:1');
  insert into public.saved_searches (user_id, query) values (A::uuid, '{"q":"nurse"}');
  insert into public.education (profile_id, user_id, institution) values ('10000000-0000-0000-0000-00000000000a', A::uuid, 'Uni');
  insert into public.applications (user_id, profile_id, job_snapshot, stage) values (A::uuid, '10000000-0000-0000-0000-00000000000a', '{"title":"t"}', 'applied') returning id into app;
  update public.applications set stage = 'interview', note = 'n' where id = app;
  update public.applications set note = 'only note' where id = app;
  select count(*) into n from public.application_events where application_id = app;
  if n <> 2 then raise exception 'expected 2 stage events (insert + change), got %', n; end if;
  insert into public.resumes (profile_id, user_id, storage_path) values ('10000000-0000-0000-0000-00000000000a', A::uuid, A || '/cv.pdf');
  insert into storage.objects (bucket_id, name, owner) values ('resumes', A || '/cv.pdf', A::uuid);
  perform tests.count('select 1 from storage.objects', 1);
  -- guards
  perform tests.fails($q$insert into public.saved_jobs (user_id,job_key,snapshot) values ('00000000-0000-0000-0000-00000000000a','dup','{"a":1}'),('00000000-0000-0000-0000-00000000000a','dup','{"a":1}')$q$, 'duplicate key');
  perform tests.fails($q$insert into public.saved_jobs (user_id,job_key) values ('00000000-0000-0000-0000-00000000000a','empty')$q$, 'check constraint');
  perform tests.fails(format($q$insert into public.saved_searches (user_id, query) values (%L, jsonb_build_object('x', repeat('a', 5000)))$q$, A), 'check constraint');
  perform tests.fails($q$update public.user_preferences set theme = 'neon'$q$, 'check constraint');
  perform tests.fails($q$update public.user_preferences set locale = 'xx'$q$, 'check constraint');
  perform tests.fails(format($q$update public.professional_profiles set skills = (select array_agg('s'||g) from generate_series(1,201) g) where user_id=%L$q$, A), 'check constraint');
  -- updated_at moves
  perform pg_sleep(0.01);
  update public.professional_profiles set name = 'renamed' where user_id = A::uuid;
  if (select updated_at <= created_at from public.professional_profiles where user_id = A::uuid) then raise exception 'updated_at not maintained'; end if;
end $$;
do $$ begin
  perform tests.count('select 1 from public.professional_profiles', 1);
  perform tests.count('select 1 from public.applications', 1);
  perform tests.count('select 1 from public.user_preferences', 1);
  perform tests.count('select 1 from public.saved_jobs', 2);
end $$;
reset role;

-- ===== anonymous =====
set role anon;
select set_config('request.jwt.claim.sub', '', false);
do $$
declare t text;
begin
  foreach t in array array['professional_profiles','experiences','education','credentials','resumes','saved_jobs','saved_searches',
      'viewed_jobs','applications','application_events','reminders','user_preferences'] loop
    perform tests.fails(format('select 1 from public.%I', t), 'permission denied');
  end loop;
  perform tests.count('select 1 from public.jobs', 1);
  perform tests.count('select 1 from storage.objects', 0);
end $$;
reset role;

-- ===== service_role bypasses RLS (backend only) =====
set role service_role;
do $$ begin perform tests.count('select 1 from public.jobs', 2); perform tests.count('select 1 from public.applications', 2); end $$;
reset role;
\echo 'behaviour: ok'
