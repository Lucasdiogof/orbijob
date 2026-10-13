-- OrbiJob catalogue coverage and health, READ-ONLY. Run against the OrbiJob project only:
--   npx supabase db query --linked -o csv -f scripts/supabase/diagnostics/coverage.sql
-- One row per measure: (section, key, value, note). Counts are exact counts of the stored catalogue at the time of the query; "visible" means
-- what the app shows: open, from a published source, verified in the last 72 hours.
with visible as (
  select j.* from public.jobs j join public.job_sources s on s.id = j.source_id
   where j.status = 'open' and s.can_redistribute and s.status in ('READY', 'CONDITIONAL') and j.last_checked_at > now() - interval '72 hours'),
areas(area, re) as (values
  ('technology', 'developer|engineer|software|devops|programm|entwickler|utvecklare|desenvolvedor|desarrollador|data |cloud'),
  ('health', 'nurse|nursing|physician|physio|fisioterap|pflege|sjuksköterska|läkare|arzt|ärzt|psycholog|pharmac|dentist|tandläkare|undersköterska|caregiver|therap'),
  ('education', 'teacher|lehrer|lärare|professor|tutor|educator|förskollärare|erzieher|docente'),
  ('sales', 'sales|vertrieb|säljare|verkäufer|account executive|business development'),
  ('logistics', 'driver|fahrer|chaufför|logistic|warehouse|lager|courier|truck'),
  ('construction/industry', 'electrician|elektriker|welder|svetsare|mechanic|mechaniker|technician|tekniker|construction|bau|carpenter|snickare|operator'),
  ('hospitality', 'chef|cook|kock|koch|waiter|servitör|hotel|restaurant|barista|housekeep'),
  ('finance/admin', 'accountant|ekonom|controller|finance|buchhalt|administrat|assistant|assistent|secretary|office'),
  ('services', 'clean|städ|reinigung|security|väktare|hairdress|frisör|customer service|kundtjänst|support'))
select 'source' section, source_id key, count(*)::text value, 'visible jobs' note from visible group by source_id
union all select 'source_new_7d', source_id, count(*)::text, 'first stored in the last 7 days' from public.jobs where first_seen_at > now() - interval '7 days' group by source_id
union all select 'source_stale', s.id, coalesce(max(r.started_at)::text, 'never'), 'last discovery pass that ended ok'
  from public.job_sources s left join public.sync_runs r on r.source_id = s.id and r.scope = 'discover' and r.status = 'ok' group by s.id
union all select 'source_failures_7d', source_id, count(*)::text, 'discovery/revalidation passes not ok in 7 days (' || string_agg(distinct coalesce(error_class, status), ',') || ')'
  from public.sync_runs where started_at > now() - interval '7 days' and status <> 'ok' group by source_id
union all select 'country', coalesce(country, '(unknown)'), count(*)::text, 'visible jobs; unknown = the source states no single country' from visible group by country
union all select 'work_mode', work_mode, count(*)::text, 'visible jobs' from visible group by work_mode
union all select 'area', a.area, count(*)::text, 'visible jobs whose TITLE matches a broad pattern (diagnostic, not the app taxonomy)'
  from visible v join areas a on v.title ~* a.re group by a.area
union all select 'area', '(none)', count(*)::text, 'visible jobs matching no broad pattern' from visible v where not exists (select 1 from areas a where v.title ~* a.re)
union all select 'quality', 'no_company', count(*)::text, 'visible jobs without a company' from visible where btrim(company) = ''
union all select 'quality', 'no_place', count(*)::text, 'visible jobs without country, city or eligibility' from visible where country is null and city is null and coalesce(geo_restrictions, '{}') = '{}'
union all select 'quality', 'short_description', count(*)::text, 'visible jobs with a description under 200 characters' from visible where length(coalesce(description, '')) < 200
union all select 'quality', 'no_published_date', count(*)::text, 'visible jobs without a publication date' from visible where published_at is null
union all select 'quality', 'cross_source_duplicates', count(*)::text, 'fingerprints shared by open jobs of two or more sources' from (select fingerprint from public.jobs where status = 'open' group by fingerprint having count(distinct source_id) > 1) d
union all select 'validity', 'open_not_verified_72h', count(*)::text, 'open jobs the app hides because nothing confirmed them in 72 h' from public.jobs where status = 'open' and last_checked_at <= now() - interval '72 hours'
union all select 'validity', 'past_expiry_still_open', count(*)::text, 'open jobs published over 60 days ago' from public.jobs where status = 'open' and published_at < now() - interval '60 days'
union all select 'growth', to_char(d, 'YYYY-MM-DD'), (select count(*) from public.jobs where first_seen_at::date = d)::text, 'jobs first stored that day'
  from generate_series(current_date - 6, current_date, interval '1 day') d
union all select 'storage', 'database', pg_size_pretty(pg_database_size(current_database())), 'free plan limit 500 MB'
order by 1, 2;
