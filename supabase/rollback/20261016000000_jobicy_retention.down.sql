-- Undo of 20261016000000_jobicy_retention.sql: stops the weekly retention and removes what the migration created.
-- Not run by anything automatically. Run it only on purpose (SQL Editor / CLI as postgres), then forget the version if it was recorded:
--   delete from supabase_migrations.schema_migrations where version = '20261016000000';
-- It does NOT bring back compacted descriptions or deleted jobs (restore those from the pre-run backup) and it does NOT touch any other job,
-- sync_runs, or user data. The tombstone list and the run log are dropped with it.
do $$
begin
  if to_regnamespace('cron') is not null then
    perform cron.unschedule(jobname) from cron.job where jobname = 'jobicy-retention';
  end if;
end $$;
drop function if exists ops.jobicy_retention_restore(text, jsonb);
drop function if exists ops.jobicy_retention_export(interval, interval, int);
drop function if exists ops.jobicy_retention_apply(text, interval, interval, int, boolean);
drop function if exists ops.jobicy_retention_plan(interval, interval);
drop table if exists ops.retention_runs;
drop table if exists ops.job_tombstones;
