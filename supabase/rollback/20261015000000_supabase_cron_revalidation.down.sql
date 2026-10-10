-- Undo of 20261015000000_supabase_cron_revalidation.sql: stops the in-database Jobicy revalidation and removes what the migration created.
-- Not run by anything automatically. Run it only on purpose (SQL Editor / CLI as postgres), then forget the version if it was recorded:
--   delete from supabase_migrations.schema_migrations where version = '20261015000000';
-- It does NOT drop the extensions pg_cron and pg_net (other things may use them) and it does NOT touch jobs, sync_runs rows or any user data.
do $$
begin
  if to_regnamespace('cron') is not null then
    perform cron.unschedule(jobname) from cron.job where jobname in ('jobicy-revalidate-start', 'jobicy-revalidate-collect', 'ops-cron-history-purge');
  end if;
end $$;
drop schema if exists ops cascade;   -- the two functions, slot_run_id and the batch log
