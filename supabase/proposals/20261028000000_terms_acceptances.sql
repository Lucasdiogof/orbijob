-- PROPOSAL, NOT APPLIED, NOT PART OF THE MIGRATION CHAIN. Lives in supabase/proposals/ on purpose: nothing applies this folder (CI applies
-- supabase/migrations/*.sql to throw-away databases only, and scripts/supabase/apply.sh pushes supabase/migrations only). The SQL test
-- supabase/tests/19_terms_acceptance.sql applies this file in the throw-away database of supabase/tests/run.sh, so CI proves it without touching
-- production. To adopt it the OWNER moves it to supabase/migrations/ in a reviewed change (updating scripts/supabase/classify_state.mjs and
-- supabase/rollback/rollback_all.sql like any other migration) and applies it with the gated apply.sh BEFORE the app that calls it ships.
--
-- Trusted, server-side record that a person accepted the Terms and the Privacy policy. `user_metadata` (written at sign-up) is editable by the
-- person through auth.updateUser, so it is only a secondary note. Here the timestamp is the server clock, the rows cannot be changed or removed by
-- the person, and the only way in is a function that checks the versions against a list kept on the server.
-- Idempotent: safe to run twice.
create schema if not exists ops;

-- versions of the published legal texts the server accepts (the dates printed on the site pages); the owner adds a row when a text is republished
create table if not exists ops.legal_versions (
  kind text not null check (kind in ('terms', 'privacy')),
  version text not null check (version ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
  primary key (kind, version)
);
alter table ops.legal_versions enable row level security;
revoke all on ops.legal_versions from public, anon, authenticated;
insert into ops.legal_versions (kind, version) values ('terms', '2026-10-14'), ('privacy', '2026-10-20') on conflict do nothing;

create table if not exists public.terms_acceptances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  terms_version text not null check (char_length(terms_version) between 1 and 20),
  privacy_version text not null check (char_length(privacy_version) between 1 and 20),
  accepted_at timestamptz not null default now(),
  unique (user_id, terms_version, privacy_version)
);
alter table public.terms_acceptances enable row level security;
revoke all on public.terms_acceptances from public, anon, authenticated;
grant select on public.terms_acceptances to authenticated;
drop policy if exists terms_acceptances_select_own on public.terms_acceptances;
create policy terms_acceptances_select_own on public.terms_acceptances
  for select to authenticated using (user_id = (select auth.uid()));
-- no insert/update/delete policy and no such grant: the person cannot write the table directly

create or replace function public.record_terms_acceptance(p_terms_version text, p_privacy_version text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  at timestamptz;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if not exists (select 1 from ops.legal_versions where kind = 'terms' and version = p_terms_version)
     or not exists (select 1 from ops.legal_versions where kind = 'privacy' and version = p_privacy_version) then
    raise exception 'unknown legal version' using errcode = '22023';
  end if;
  insert into public.terms_acceptances (user_id, terms_version, privacy_version)
    values (uid, p_terms_version, p_privacy_version)
    on conflict (user_id, terms_version, privacy_version) do nothing;
  select t.accepted_at into at from public.terms_acceptances t
    where t.user_id = uid and t.terms_version = p_terms_version and t.privacy_version = p_privacy_version;
  return at;
end $$;
revoke execute on function public.record_terms_acceptance(text, text) from public, anon;
grant execute on function public.record_terms_acceptance(text, text) to authenticated;
