-- Sources for the live PostgREST tests of a THROW-AWAY CI database. Created here, as the OWNER (postgres), because since migration
-- 20261014000000 the service_role used by the Worker can neither create nor change sources.
--   jobicy         the state PUBLISHED (the contract tests read the stored attribution as a client would)
--   stress-*       two private sources for the lease measurement
insert into public.job_sources (id, status, attribution, can_redistribute) values
  ('jobicy', 'CONDITIONAL', 'Remote jobs via Jobicy (https://jobicy.com)', true),
  ('stress-atomic', 'RESEARCH', null, false),
  ('stress-legacy', 'RESEARCH', null, false);
