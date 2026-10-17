-- Rollback of 20261027000000: back to the case-only title_has, without the folded columns. (The app falls back to title/city filters by itself.)
create or replace function ops.title_has(p_title text, p_needle text) returns boolean
language sql immutable set search_path = pg_catalog as $$
  select coalesce(p_title, '') ilike '%' || replace(replace(replace(p_needle, E'\\', E'\\\\'), '%', E'\\%'), '_', E'\\_') || '%'
$$;
revoke all on function ops.title_has(text, text) from public, anon, authenticated, service_role;
drop index if exists public.jobs_title_fold_trgm_idx;
drop index if exists public.jobs_city_fold_trgm_idx;
alter table public.jobs drop column if exists title_fold;
alter table public.jobs drop column if exists city_fold;
drop function if exists ops.fold(text);
