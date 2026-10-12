-- CRIA as linhas das fontes de vagas alem do Jobicy. Estado inicial obrigatorio: CONDITIONAL e NAO publicada (a publicacao e outra operacao,
-- guardada: scripts/supabase/ops/publish_source.sql). Idempotente: uma fonte que ja existe nao e alterada.
-- A atribuicao e o texto que acompanha toda vaga da fonte; cada termo de uso pede o link de volta (docs/SOURCES_MATRIX.md).
insert into public.job_sources (id, status, attribution, can_redistribute) values
  ('arbeitnow', 'CONDITIONAL', 'Jobs via Arbeitnow (https://www.arbeitnow.com)', false),
  ('remoteok',  'CONDITIONAL', 'Remote jobs via Remote OK (https://remoteok.com)', false),
  ('remotive',  'CONDITIONAL', 'Remote jobs via Remotive (https://remotive.com)', false)
on conflict (id) do nothing;
