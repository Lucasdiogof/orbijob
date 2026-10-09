-- OrbiJob per-user quotas (PROPOSAL - NOT EXECUTED against any Supabase project).
-- Fourth migration. Bounds what a single account can store so one user cannot exhaust the project's database
-- allowance. Implemented as BEFORE INSERT triggers, not policies: a policy that counts rows of its own table makes
-- PostgreSQL fail with "infinite recursion detected in policy". The trigger is SECURITY INVOKER, so the count goes
-- through the caller's RLS (own rows only) and no privileged code path exists. Limits are generous for real use;
-- raise them with a new migration. Concurrent inserts can overshoot a limit slightly; that is acceptable here.
--
-- Not covered by SQL: the NUMBER of files in the Storage bucket. storage.objects belongs to the platform, so no trigger
-- is added to it, and a counting policy would recurse as above. Row quota on `resumes` bounds legitimate use; stray
-- uploads without a row are removed by the orphan sweeper described in docs/SUPABASE_MIGRATION_PLAN.md.

create function public.enforce_row_quota() returns trigger
language plpgsql set search_path = '' as $$
declare
  n bigint;
  max_rows int := tg_argv[0]::int;
begin
  execute format('select count(*) from %I.%I where user_id = $1', tg_table_schema, tg_table_name)
    into n using new.user_id;
  if n >= max_rows then
    raise exception 'quota exceeded: at most % rows in %', max_rows, tg_table_name
      using errcode = '53400';  -- configuration_limit_exceeded
  end if;
  return new;
end $$;
revoke all on function public.enforce_row_quota() from public, anon, authenticated;

create trigger resumes_quota        before insert on public.resumes        for each row execute function public.enforce_row_quota(10);
create trigger saved_jobs_quota     before insert on public.saved_jobs     for each row execute function public.enforce_row_quota(1000);
create trigger saved_searches_quota before insert on public.saved_searches for each row execute function public.enforce_row_quota(100);
create trigger applications_quota   before insert on public.applications   for each row execute function public.enforce_row_quota(2000);
