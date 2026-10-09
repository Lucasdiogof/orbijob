-- After rollback_all.sql nothing of OrbiJob may remain.
\set ON_ERROR_STOP on
do $$
declare n int;
begin
  select count(*) into n from pg_tables where schemaname = 'public';
  if n > 0 then raise exception 'ROLLBACK: % table(s) left in public', n; end if;
  select count(*) into n from pg_proc p join pg_namespace s on s.oid = p.pronamespace
   where s.nspname = 'public' and p.prorettype <> 'event_trigger'::regtype;  -- platform event-trigger functions stay
  if n > 0 then raise exception 'ROLLBACK: % function(s) left in public', n; end if;
  if exists (select 1 from storage.buckets where id = 'resumes') then raise exception 'ROLLBACK: bucket left'; end if;
  select count(*) into n from pg_policies where schemaname = 'storage' and policyname like 'resumes\_objects\_%';
  if n > 0 then raise exception 'ROLLBACK: % storage policy(ies) left', n; end if;
  if exists (select 1 from pg_extension where extname = 'pg_trgm') then raise exception 'ROLLBACK: pg_trgm left'; end if;
end $$;
\echo 'rollback: clean'
