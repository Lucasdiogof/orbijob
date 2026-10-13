-- Search alternatives (migration 20261026000000) on a REAL PostgreSQL (CI: 16 and 17). Details: worker/test/search-alternatives.test.ts.
\set ON_ERROR_STOP on
insert into public.job_sources (id, status, attribution, can_redistribute) values ('altsrc', 'CONDITIONAL', 'alt', true) on conflict do nothing;
insert into public.jobs (source_id, external_id, company, title, description, last_checked_at, original_url, canonical_url, fingerprint)
values ('altsrc', 'a1', 'Acme', 'Senior Flutter-Entwickler (m/w/d)', '', now(), 'https://alt.test/1', 'https://alt.test/1', 'fp-alt-1'),
       ('altsrc', 'a2', 'Acme', 'Office Manager', 'work with our civil engineer team', now(), 'https://alt.test/2', 'https://alt.test/2', 'fp-alt-2');
do $$
declare j1 public.jobs; j2 public.jobs;
begin
  select * into j1 from public.jobs where external_id = 'a1' and source_id = 'altsrc';
  select * into j2 from public.jobs where external_id = 'a2' and source_id = 'altsrc';
  if not ops.alert_matches(j1, '{"match":{"term":"desenvolvedor flutter","alts":[["flutter","entwickler"]]}}') then raise exception 'array alternative'; end if;
  if ops.alert_matches(j1, '{"match":{"term":"desenvolvedor java","alts":[["java","entwickler"]]}}') then raise exception 'array needs every part'; end if;
  if ops.alert_matches(j2, '{"match":{"term":"engenheiro civil","alts":["civil engineer"]}}') then raise exception 'profession search must use the title'; end if;
  if not ops.alert_matches(j2, '{"match":{"term":"civil engineer"}}') then raise exception 'free-word search keeps the description'; end if;
end $$;
set role authenticated;
do $$ begin perform tests.fails($q$select ops.title_alt_matches('x', '"x"')$q$, 'permission denied'); end $$;
reset role;
delete from public.jobs where source_id = 'altsrc';
delete from public.job_sources where id = 'altsrc';
