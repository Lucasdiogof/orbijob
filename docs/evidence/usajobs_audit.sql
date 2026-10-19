-- OrbiJob USAJOBS stored-row audit (read-only): counts only, no personal data. Run: npx supabase db query --linked -f docs/evidence/usajobs_audit.sql
select
  count(*) as stored,
  count(*) filter (where status = 'open') as open_n,
  count(*) filter (where country = 'US') as country_us,
  count(*) filter (where country is null) as no_country,
  count(*) filter (where work_mode = 'remote') as remote_n,
  count(*) filter (where salary_min is not null) as with_salary,
  count(*) filter (where salary_period = 'hour') as salary_hour,
  count(*) filter (where salary_period = 'year') as salary_year,
  count(*) filter (where coalesce(length(description), 0) < 200) as short_desc,
  count(*) filter (where published_at is null) as no_date,
  count(*) filter (where original_url !~ '^https://www\.usajobs\.gov/job/[0-9]+$') as odd_url,
  count(distinct original_url) as distinct_urls,
  count(distinct company) as agencies,
  count(*) filter (where description ~* '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}' and description !~ '\[e-mail\]') as raw_email_left,
  count(*) filter (where description ~ '\(?[0-9]{3}\)?[ .-][0-9]{3}[ .-][0-9]{4}') as phone_like_left,
  count(*) filter (where description ~* 'U\.?S\.? citizen') as mentions_us_citizen,
  round(avg(length(description))) as avg_desc_len,
  min(published_at) as oldest_published,
  max(published_at) as newest_published
from public.jobs where source_id = 'usajobs';
