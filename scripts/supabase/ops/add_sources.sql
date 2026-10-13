-- CRIA as linhas das fontes de vagas alem do Jobicy. Estado inicial obrigatorio: CONDITIONAL e NAO publicada (a publicacao e outra operacao,
-- guardada: scripts/supabase/ops/publish_source.sql). Idempotente: uma fonte que ja existe nao e alterada.
-- A atribuicao e o texto que acompanha toda vaga da fonte; cada termo de uso pede o link de volta (docs/SOURCES_MATRIX.md).
insert into public.job_sources (id, status, attribution, can_redistribute) values
  ('arbeitnow', 'CONDITIONAL', 'Jobs via Arbeitnow (https://www.arbeitnow.com)', false),
  ('remoteok',  'CONDITIONAL', 'Remote jobs via Remote OK (https://remoteok.com)', false),
  ('remotive',  'CONDITIONAL', 'Remote jobs via Remotive (https://remotive.com)', false),
  ('jobtech',   'CONDITIONAL', 'Jobs via Arbetsförmedlingen / Platsbanken (https://arbetsformedlingen.se), open data CC0 from JobTech Dev', false),
  ('twjobs',    'CONDITIONAL', 'Jobs via Taiwan Jobs (臺灣就業通), Workforce Development Agency, Ministry of Labor, Taiwan (https://job.taiwanjobs.gov.tw), Open Government Data License v1.0 (https://data.gov.tw/en/datasets/44062)', false),
  ('jobsconz',  'CONDITIONAL', 'Jobs via Jobs.co.nz (https://jobs.co.nz), New Zealand', false),
  ('getonboard', 'CONDITIONAL', 'Jobs via Get on Board (https://www.getonbrd.com), tech jobs in Latin America', false)
on conflict (id) do nothing;
