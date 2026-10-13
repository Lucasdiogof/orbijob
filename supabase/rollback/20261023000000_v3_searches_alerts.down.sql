-- Undo of 20261023000000_v3_searches_alerts.sql: stops the alert run, drops its functions, tables and triggers, and restores the previous
-- shape of saved_searches and applications. It deletes the notifications and the hidden-jobs lists (derived / convenience data) and the
-- interview_at / follow_up_at dates; saved searches, applications and every job stay. Applications in the new stages (interested, hired)
-- are moved to the nearest old stage first, so the old constraint can be restored.
-- Then forget the version if it was recorded:  delete from supabase_migrations.schema_migrations where version = '20261023000000';
do $$ begin if to_regnamespace('cron') is not null then perform cron.unschedule(jobname) from cron.job where jobname = 'alerts-run'; end if; end $$;
drop function if exists ops.alerts_run(int);
drop function if exists ops.alert_matches(public.jobs, jsonb);
drop function if exists ops.title_has(text, text);
drop table if exists ops.alert_runs;
drop table if exists public.notifications;
drop table if exists public.hidden_jobs;
drop trigger if exists saved_searches_alert_state on public.saved_searches;
drop trigger if exists saved_searches_touch on public.saved_searches;
drop function if exists public.saved_search_alert_state();
alter table public.saved_searches
  drop constraint if exists saved_searches_name_len,
  drop constraint if exists saved_searches_frequency_check,
  drop constraint if exists saved_searches_query_size,
  drop column if exists name, drop column if exists alerts_enabled, drop column if exists frequency,
  drop column if exists alert_cursor, drop column if exists last_alert_run_at, drop column if exists updated_at;
alter table public.saved_searches add constraint saved_searches_query_size check (octet_length(query::text) <= 4096);
grant insert, update on public.saved_searches to authenticated;
update public.applications set stage = 'applied' where stage = 'interested';
update public.applications set stage = 'offer' where stage = 'hired';
alter table public.applications drop constraint if exists applications_stage_check;
alter table public.applications add constraint applications_stage_check
  check (stage in ('applied', 'screening', 'interview', 'offer', 'rejected', 'withdrawn', 'closed'));
alter table public.applications drop column if exists interview_at, drop column if exists follow_up_at;
drop index if exists public.jobs_first_seen_idx;
alter table public.jobs drop column if exists first_seen_at;
