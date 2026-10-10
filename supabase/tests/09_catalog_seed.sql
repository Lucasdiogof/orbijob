-- Throw-away catalogue for the PostgREST contract test (scripts/supabase/catalog_postgrest_contract.mjs).
-- Run ONLY against a disposable database that already holds the migrations. Never against a real project.
-- Dates are fixed relative to the clock the Flutter golden file was recorded with: 2026-10-10T12:00:00Z.
-- Rows named "hidden" must never be returned to a client, whatever the query.

insert into public.job_sources (id, status, attribution, can_redistribute) values
  ('jobicy',   'CONDITIONAL', 'Remote jobs via Jobicy (https://jobicy.com)', true),
  ('lever',    'READY',       'Lever',                                        true),
  ('research', 'RESEARCH',    null,                                           false),
  ('notredis', 'CONDITIONAL', null,                                           false),  -- right status, not redistributable
  ('blocked',  'BLOCKED',     null,                                           true);   -- redistributable flag but blocked status

-- column order: source, external id, company, title, work mode, country, geo restrictions, salary (min,max,cur,period), published, status
insert into public.jobs
  (source_id, external_id, company, title, description, country, work_mode, contract_type,
   salary_min, salary_max, salary_currency, salary_period, published_at, last_checked_at,
   original_url, apply_url, status, geo_restrictions, fingerprint, canonical_url)
values
  -- visible, newest first: 1, 4, 2, 8, 3, 5
  ('jobicy','1','Juniper Square','Flutter Developer','Build mobile apps.','US','remote','Full-Time',
     100000,120000,'USD','year','2026-10-09T10:00:00Z','2026-10-10T00:00:00Z',
     'https://jobicy.com/jobs/1','https://jobicy.com/jobs/1','open','{US}','f1','https://jobicy.com/jobs/1'),
  ('jobicy','2','Care Co','Nurse Practitioner','Patient care.',null,'remote','Full-Time',
     null,null,null,null,'2026-10-07T10:00:00Z','2026-10-10T00:00:00Z',
     'https://jobicy.com/jobs/2','https://jobicy.com/jobs/2','open','{Anywhere}','f2','https://jobicy.com/jobs/2'),
  ('jobicy','3','Emea Ltd','Senior Engineer EMEA','Platform work.',null,'remote','Full-Time',
     80000,90000,'GBP','year','2026-09-20T10:00:00Z','2026-10-10T00:00:00Z',
     'https://jobicy.com/jobs/3','https://jobicy.com/jobs/3','open','{EMEA}','f3','https://jobicy.com/jobs/3'),
  ('jobicy','4','Cafe Lisboa','Barista Lisbon','Coffee.','PT','onsite','Part-Time',
     8,8,'EUR','hour','2026-10-08T10:00:00Z','2026-10-10T00:00:00Z',
     'https://jobicy.com/jobs/4','https://jobicy.com/jobs/4','open','{}','f4','https://jobicy.com/jobs/4'),
  ('lever','5','Klinik Berlin','Physio Berlin','Pelvic floor physio.','DE','hybrid','Full-Time',
     null,null,null,null,null,'2026-10-10T00:00:00Z',
     'https://jobs.lever.co/x/5','https://jobs.lever.co/x/5/apply','open','{}','f5','https://jobs.lever.co/x/5'),
  ('jobicy','8','Edge Inc','Remote Eligible Specialist','Anywhere in CA or US.',null,'remote','Contract',
     null,null,null,null,'2026-10-06T10:00:00Z','2026-10-10T00:00:00Z',
     'https://jobicy.com/jobs/8','https://jobicy.com/jobs/8','open','{CA,US}','f8','https://jobicy.com/jobs/8'),
  -- visible, oldest: remote with NO usable location (empty list = eligibility unknown). It must never match a country filter.
  ('jobicy','11','Nowhere Inc','Unknown Location Analyst','Location not stated.',null,'remote','Full-Time',
     null,null,null,null,'2026-09-01T10:00:00Z','2026-10-10T00:00:00Z',
     'https://jobicy.com/jobs/11','https://jobicy.com/jobs/11','open','{}','f11','https://jobicy.com/jobs/11'),
  -- hidden: open, but nobody has vouched for it for more than 72 h (last_checked_at is old): never offered as an opportunity
  ('jobicy','12','Stale Co','Unverified Old Listing','Not confirmed lately.','US','remote','Full-Time',
     null,null,null,null,'2026-10-09T08:00:00Z','2026-10-01T00:00:00Z',
     'https://jobicy.com/jobs/12','https://jobicy.com/jobs/12','open','{US}','f12','https://jobicy.com/jobs/12'),
  -- hidden: closed job of an authorised source
  ('jobicy','7','Gone Co','Hidden Closed Job','x','US','remote','Full-Time',
     null,null,null,null,'2026-10-09T09:00:00Z','2026-10-10T00:00:00Z',
     'https://jobicy.com/jobs/7','https://jobicy.com/jobs/7','closed','{US}','f7','https://jobicy.com/jobs/7'),
  -- hidden: open jobs of sources that are not authorised
  ('research','6','R Co','Hidden Research Job','x','US','remote','Full-Time',
     100000,120000,'USD','year','2026-10-09T11:00:00Z','2026-10-10T00:00:00Z',
     'https://example.invalid/6','https://example.invalid/6','open','{US}','f6','https://example.invalid/6'),
  ('notredis','9','N Co','Hidden Not Redistributable','x','US','remote','Full-Time',
     null,null,null,null,'2026-10-09T12:00:00Z','2026-10-10T00:00:00Z',
     'https://example.invalid/9','https://example.invalid/9','open','{US}','f9','https://example.invalid/9'),
  ('blocked','10','B Co','Hidden Blocked Source Job','x','US','remote','Full-Time',
     null,null,null,null,'2026-10-09T12:30:00Z','2026-10-10T00:00:00Z',
     'https://example.invalid/10','https://example.invalid/10','open','{US}','f10','https://example.invalid/10');
