-- OrbiJob operational health, READ-ONLY (10.3). Run against the OrbiJob project only:
--   npx supabase db query --linked -o csv -f scripts/supabase/diagnostics/ops-health.sql
-- One row per check: (check, status, value, note). status is OK, WARN or ALERT; nobody is paged (the free plan has no alerting channel), so run it
-- (or let a scheduled GitHub workflow run it) and read the ALERT/WARN rows. Complements coverage.sql, which describes the catalogue itself.
-- Thresholds are deliberately generous and documented in the note of each row. A pass that stopped at the source's catalogue ceiling
-- (`partial`, error_class `catalogue_full`) is by design and not counted as bad.
with cron_last as (
  select j.jobname, j.active,
         (select max(d.start_time) from cron.job_run_details d where d.jobid = j.jobid) as last_start,
         (select count(*) from cron.job_run_details d where d.jobid = j.jobid and d.start_time > now() - interval '24 hours' and d.status = 'failed') as failed_24h,
         (select count(*) from cron.job_run_details d where d.jobid = j.jobid and d.start_time > now() - interval '24 hours') as runs_24h
    from cron.job j),
src as (
  select s.id, s.can_redistribute,
         (select max(r.started_at) from public.sync_runs r where r.source_id = s.id and r.scope = 'discover' and r.status = 'ok') as last_ok_discover,
         (select count(*) from public.sync_runs r where r.source_id = s.id and r.started_at > now() - interval '24 hours' and r.status not in ('ok', 'running') and coalesce(r.error_class, '') <> 'catalogue_full') as bad_24h
    from public.job_sources s)
select 'cron:' || jobname as check,
       case when not active then 'ALERT' when failed_24h > 0 then 'WARN' when last_start is null then 'WARN' when last_start < now() - interval '26 hours' and jobname !~ '(expire|retention|purge|collect)' then 'ALERT' when last_start < now() - interval '50 hours' then 'ALERT' else 'OK' end as status,
       runs_24h || ' runs, ' || failed_24h || ' failed in 24 h; last ' || coalesce(last_start::text, 'never') as value,
       'inactive = ALERT; never run = WARN (a job created today); hourly/6-hourly jobs silent for 26 h = ALERT, daily jobs (expire/retention/purge) silent for 50 h = ALERT; any failure in 24 h = WARN' as note
  from cron_last
union all
select 'source_discovery:' || id,
       case when not can_redistribute then 'OK'
            when last_ok_discover is null then 'ALERT'
            when last_ok_discover < now() - interval '30 hours' then 'ALERT'
            when last_ok_discover < now() - interval '14 hours' then 'WARN'
            when bad_24h > 0 then 'WARN' else 'OK' end,
       'last ok discovery ' || coalesce(last_ok_discover::text, 'never') || '; ' || bad_24h || ' not-ok passes in 24 h',
       'published sources only: no ok discovery in 30 h = ALERT, in 14 h = WARN (GitHub scheduled runs can be delayed by hours on the free plan)'
  from src
union all
select 'alerts_run', case when max(ran_at) is null or max(ran_at) < now() - interval '3 hours' then 'ALERT' else 'OK' end,
       'last run ' || coalesce(max(ran_at)::text, 'never') || '; ' || count(*) filter (where ran_at > now() - interval '24 hours') || ' runs in 24 h',
       'the hourly alert matcher (ops.alert_runs); silent for 3 h = ALERT' from ops.alert_runs
union all
select 'push_backlog', case when count(*) > 200 then 'ALERT' when count(*) > 0 then 'WARN' else 'OK' end,
       count(*) || ' notifications older than 2 h with a registered device and never pushed',
       'push-send marks a row even when Google is down, so a backlog means the function or its cron is not running'
  from public.notifications n
 where n.pushed_at is null and n.created_at < now() - interval '2 hours' and n.created_at > now() - interval '3 days'
   and exists (select 1 from public.push_devices d where d.user_id = n.user_id)
union all
select 'database_size', case when pg_database_size(current_database()) > 450 * 1024 * 1024 then 'ALERT' when pg_database_size(current_database()) > 400 * 1024 * 1024 then 'WARN' else 'OK' end,
       pg_size_pretty(pg_database_size(current_database())) || ' of 500 MB (free plan)', 'WARN above 400 MB, ALERT above 450 MB'
union all
select 'largest_tables', 'OK', string_agg(t.rel || ' ' || t.sz, '; ' order by t.bytes desc), 'the five biggest relations (growth watch)'
  from (select c.relname as rel, pg_size_pretty(pg_total_relation_size(c.oid)) as sz, pg_total_relation_size(c.oid) as bytes
          from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname in ('public', 'ops') and c.relkind = 'r' order by 3 desc limit 5) t
union all
select 'visible_jobs', case when count(*) < 5000 then 'ALERT' when count(*) < 9000 then 'WARN' else 'OK' end, count(*) || ' open jobs verified in 72 h from published sources',
       'a sharp drop means sources stopped refreshing (6.0 baseline 12,970; 8.0 baseline 13,491)'
  from public.jobs j join public.job_sources s on s.id = j.source_id
 where j.status = 'open' and s.can_redistribute and j.last_checked_at > now() - interval '72 hours'
union all
select 'job_links_https', case when count(*) filter (where original_url !~ '^https://') > 0 then 'ALERT' else 'OK' end,
       count(*) filter (where original_url !~ '^https://') || ' of ' || count(*) || ' open jobs have an original_url that is not https', 'every shown link must be https'
  from public.jobs where status = 'open'
order by 2 desc, 1;
