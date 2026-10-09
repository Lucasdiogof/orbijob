-- OrbiJob quota fix (PROPOSAL - NOT EXECUTED against any Supabase project).
-- Fifth migration. CORRECTIVE: 20261011000000_quotas.sql is left untouched because it may already have been applied
-- to a remote project; this one works both on databases that stop at migration 4 and on fresh ones that run 1-5.
--
-- Two defects in the original trigger function:
--  1. UPSERT at the cap. BEFORE INSERT triggers run before ON CONFLICT is resolved, so re-saving an EXISTING favourite
--     (insert ... on conflict (user_id, job_key) do update) with exactly 1000 rows was refused even though it only
--     updates. Fix: an optional second trigger argument names the natural-key column; when a row with the same key
--     already exists for the user the insert is not a new row and passes (it either becomes the UPDATE, or fails with a
--     plain unique violation). UPDATEs were never affected (the trigger is insert-only).
--  2. Concurrency. Two sessions could both count 999 and both insert, ending at 1001. Fix: a per-user, per-table
--     transaction-level advisory lock serialises the count-then-insert; the second session waits for the first to
--     commit, then counts again. Locks are released automatically at transaction end.
-- Still SECURITY INVOKER and still counting through the caller RLS (own rows only); no policy references its own
-- table, so there is no RLS recursion.

create or replace function public.enforce_row_quota() returns trigger
language plpgsql set search_path = '' as $$
declare
  n bigint;
  max_rows int := tg_argv[0]::int;
  key_column text := nullif(tg_argv[1], '');
  already boolean := false;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(tg_table_name || ':' || new.user_id::text, 0));

  if key_column is not null then
    execute format('select exists (select 1 from %I.%I where user_id = $1 and %I::text = $2)',
                   tg_table_schema, tg_table_name, key_column)
      into already using new.user_id, pg_catalog.to_jsonb(new) ->> key_column;
    if already then
      return new;  -- not a new row: ON CONFLICT will turn it into an UPDATE (or a unique violation will follow)
    end if;
  end if;

  execute format('select count(*) from %I.%I where user_id = $1', tg_table_schema, tg_table_name)
    into n using new.user_id;
  if n >= max_rows then
    raise exception 'quota exceeded: at most % rows in %', max_rows, tg_table_name
      using errcode = '53400';  -- configuration_limit_exceeded
  end if;
  return new;
end $$;
revoke all on function public.enforce_row_quota() from public, anon, authenticated;

-- Only favourites need the natural-key exemption (the app saves them with upsert on (user_id, job_key)).
-- The other three tables always insert brand-new rows with generated ids.
drop trigger saved_jobs_quota on public.saved_jobs;
create trigger saved_jobs_quota before insert on public.saved_jobs
  for each row execute function public.enforce_row_quota(1000, 'job_key');
