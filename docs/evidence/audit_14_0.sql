-- OrbiJob 14.0 read-only catalogue audit (run with: npx supabase db query --linked -f docs/evidence/audit_14_0.sql). Counts only; no personal data.
with v as (
  select j.*, s.can_redistribute
  from public.jobs j join public.job_sources s on s.id = j.source_id
  where j.status = 'open' and s.can_redistribute and j.last_checked_at >= now() - interval '72 hours'
)
select source_id,
  count(*) as visible,
  count(*) filter (where country is null) as no_country,
  count(*) filter (where coalesce(length(description), 0) < 80) as short_desc,
  count(*) filter (where published_at is null) as no_date,
  count(*) filter (where published_at < now() - interval '60 days') as older_60d,
  count(*) filter (where coalesce(company, '') = '') as no_company,
  count(*) filter (where salary_min is not null and salary_period is null) as salary_no_period,
  count(*) filter (where original_url !~ '^https://') as bad_url
from v group by 1 order by 2 desc;
