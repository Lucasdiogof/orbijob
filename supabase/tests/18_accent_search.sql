-- Accent-insensitive search (migration 20261027000000) on a REAL PostgreSQL (CI: 16 and 17).
\set ON_ERROR_STOP on
insert into public.job_sources (id, status, attribution, can_redistribute) values ('accsrc', 'CONDITIONAL', 'acc', true) on conflict do nothing;
insert into public.jobs (source_id, external_id, company, title, city, description, last_checked_at, original_url, canonical_url, fingerprint)
values ('accsrc', 'c1', 'Acme', 'Desenvolvedor Sênior', 'Goiânia', '', now(), 'https://acc.test/1', 'https://acc.test/1', 'fp-acc-1'),
       ('accsrc', 'c2', 'Acme', 'Senior Medico', 'Łódź', '', now(), 'https://acc.test/2', 'https://acc.test/2', 'fp-acc-2');
do $$
declare j1 public.jobs; j2 public.jobs;
begin
  select * into j1 from public.jobs where external_id = 'c1' and source_id = 'accsrc';
  select * into j2 from public.jobs where external_id = 'c2' and source_id = 'accsrc';
  if j1.title_fold <> 'desenvolvedor senior' or j1.city_fold <> 'goiania' then raise exception 'folded columns: %, %', j1.title_fold, j1.city_fold; end if;
  if j2.city_fold <> 'lodz' then raise exception 'folded Polish city: %', j2.city_fold; end if;
  if ops.fold('Pélvica ÅØ') <> 'pelvica ao' then raise exception 'fold: %', ops.fold('Pélvica ÅØ'); end if;
  if not ops.alert_matches(j1, '{"match":{"term":"senior"}}') or not ops.alert_matches(j1, '{"match":{"term":"sênior"}}') then raise exception 'sênior = senior'; end if;
  if not ops.alert_matches(j2, '{"match":{"term":"médico"}}') then raise exception 'médico = medico'; end if;
  if not ops.alert_matches(j1, '{"match":{"term":"goiania"}}') then raise exception 'city without accent'; end if;
  if ops.alert_matches(j1, '{"match":{"term":"medico"}}') then raise exception 'no false positive'; end if;
  if ops.title_has('100% sênior', '%') is not true or ops.title_has('sênior', '%') then raise exception 'wildcards stay literal'; end if;
end $$;
-- the folded filter the app sends is served by the trigram index and returns the right rows
do $$ begin
  if (select count(*) from public.jobs where source_id = 'accsrc' and title_fold ilike '%senior%') <> 2 then raise exception 'title_fold filter'; end if;
end $$;
set role anon;
do $$ begin perform tests.fails($q$select ops.fold('x')$q$, 'permission denied'); end $$;
reset role;
delete from public.jobs where source_id = 'accsrc';
delete from public.job_sources where id = 'accsrc';
