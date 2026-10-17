-- Accent-insensitive search (ORBI-001 follow-up): "sênior" finds "Senior", "médico" finds "Medico", "pélvica" finds "pelvica", and the other way round.
--
-- ops.fold(text) lower-cases and removes the diacritics of the Latin letters the catalogue holds (the very table the Flutter app uses,
-- app/lib/core/format/fold.dart: both sides must agree character by character, so no extension is involved and the function is IMMUTABLE).
-- The catalogue gets two generated columns, title_fold and city_fold, with trigram indexes: the app filters on them with the folded term
-- (PostgREST cannot call a function on a column). The alert matcher (ops.title_has) folds both sides, so saved searches agree with the app.
-- The full-text column `search` is NOT rebuilt (it would rewrite every description on the free plan): the app asks it for both spellings.
-- Idempotent. Rollback: supabase/rollback/20261027000000_accent_insensitive_search.down.sql.
create or replace function ops.fold(p_text text) returns text
language sql immutable parallel safe set search_path = pg_catalog as $$
  select translate(lower(coalesce(p_text, '')),
    'àáâãäåçèéêëìíîïñòóôõöùúûüýÿčďěňřšťůžľĺŕłśźżćńąęøő',
    'aaaaaaceeeeiiiinooooouuuuyycdenrstuzllrlszzcnaeoo')
$$;
revoke all on function ops.fold(text) from public, anon, authenticated, service_role;
comment on function ops.fold(text) is 'Lower-case without diacritics; same table as app/lib/core/format/fold.dart. Migration 20261027000000.';

alter table public.jobs add column if not exists title_fold text generated always as (ops.fold(title)) stored;
alter table public.jobs add column if not exists city_fold  text generated always as (ops.fold(city))  stored;
create index if not exists jobs_title_fold_trgm_idx on public.jobs using gin (title_fold extensions.gin_trgm_ops);
create index if not exists jobs_city_fold_trgm_idx  on public.jobs using gin (city_fold extensions.gin_trgm_ops);

-- "title contains" without wildcards from the needle, ignoring case AND accents on both sides
create or replace function ops.title_has(p_title text, p_needle text) returns boolean
language sql immutable set search_path = pg_catalog as $$
  select ops.fold(p_title) like '%' || replace(replace(replace(ops.fold(p_needle), E'\\', E'\\\\'), '%', E'\\%'), '_', E'\\_') || '%'
$$;
revoke all on function ops.title_has(text, text) from public, anon, authenticated, service_role;
