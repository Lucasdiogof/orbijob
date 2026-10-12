-- Undo of 20261022000000_jobsconz_revalidation.sql: stops the Jobs.co.nz revalidation and drops its two functions. It does NOT touch any job.
-- Then forget the version if it was recorded:  delete from supabase_migrations.schema_migrations where version = '20261022000000';
do $$ begin if to_regnamespace('cron') is not null then perform cron.unschedule(jobname) from cron.job where jobname in ('jobsconz-revalidate-start', 'jobsconz-revalidate-collect'); end if; end $$;
drop function if exists ops.jobsconz_revalidate_start();
drop function if exists ops.jobsconz_revalidate_collect();
