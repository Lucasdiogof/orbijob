-- Retention of the stored Jobicy jobs (docs/JOBICY_RETENTION.md): keeps the free database inside its quota once new jobs are discovered.
--
-- Policy (the defaults of the functions; every number can be passed explicitly):
--   * a job that is OPEN is never touched;
--   * CLOSED for more than 14 days  -> COMPACTED: description, requirements and skills are emptied (identity, title, company, URL, salary,
--     dates, fingerprint stay). A stored job weighs ~37 KB with its search indexes, ~3.4 KB without the description;
--   * CLOSED for more than 90 days AND referenced by nothing -> DELETED, leaving a tombstone (source, external id, date) in ops.job_tombstones.
--     "Referenced" = saved_jobs, viewed_jobs, applications (job_id) or job_clusters (canonical_job_id). The app today never writes job_id
--     (favourites and applications keep their own snapshot), so nothing references a job; the check stays as a defence.
--   "Closed for N days" is measured from jobs.last_checked_at: the revalidation sets it to the moment it closed the job and nothing touches a
--   closed job afterwards.
--
-- What it does NOT do: touch jobs of other sources, open jobs, job_sources, sync_runs or any user table; it never runs by itself.
-- NOTHING IS SCHEDULED HERE. Scheduling is a separate, guarded step: scripts/supabase/ops/enable_retention_cron.sql
-- (undo: scripts/supabase/ops/disable_retention_cron.sql). Rollback of this migration: supabase/rollback/20261016000000_jobicy_retention.down.sql.
-- Compaction cannot be undone inside the database: take the backup described in docs/JOBICY_RETENTION.md before the first real run.
--
-- Access: like the rest of schema `ops`, closed to anon, authenticated and service_role. It is run by pg_cron / the database owner.

create table ops.job_tombstones (
  source_id    text        not null,
  external_id  text        not null,
  deleted_at   timestamptz not null default now(),
  primary key (source_id, external_id)
);
alter table ops.job_tombstones enable row level security;  -- no policy: nobody but the owner reads it
revoke all on ops.job_tombstones from public, anon, authenticated, service_role;

-- One row per apply call (counts only). Deliberately NOT public.sync_runs: that table is the lease of the Jobicy passes and a row here
-- would make the next revalidation or discovery stand down as "too_soon".
create table ops.retention_runs (
  id          bigint generated always as identity primary key,
  ran_at      timestamptz not null default now(),
  outcome     text        not null,
  compacted   int         not null default 0,
  deleted     int         not null default 0,
  compact_after interval  not null,
  delete_after  interval  not null
);
alter table ops.retention_runs enable row level security;
revoke all on ops.retention_runs from public, anon, authenticated, service_role;

-- Read-only: how many jobs sit in each layer and what would be done. Changes nothing.
create function ops.jobicy_retention_plan(p_compact_after interval default interval '14 days', p_delete_after interval default interval '90 days')
returns table (layer text, jobs bigint) language sql stable as $$
  with j as (
    select status, last_checked_at, (description <> '' or requirements <> '{}' or skills <> '{}') as has_body,
           not (exists (select 1 from public.saved_jobs s where s.job_id = jobs.id)
             or exists (select 1 from public.viewed_jobs v where v.job_id = jobs.id)
             or exists (select 1 from public.applications a where a.job_id = jobs.id)
             or exists (select 1 from public.job_clusters c where c.canonical_job_id = jobs.id)) as unreferenced
      from public.jobs where source_id = 'jobicy')
  select 'open'::text,                         count(*) filter (where status <> 'closed') from j
  union all select 'closed_recent',            count(*) filter (where status = 'closed' and now() - last_checked_at <= p_compact_after) from j
  union all select 'closed_to_compact',        count(*) filter (where status = 'closed' and now() - last_checked_at > p_compact_after and has_body) from j
  union all select 'closed_compacted',         count(*) filter (where status = 'closed' and now() - last_checked_at > p_compact_after and not has_body) from j
  union all select 'closed_to_delete',         count(*) filter (where status = 'closed' and now() - last_checked_at > p_delete_after and unreferenced) from j
  union all select 'closed_kept_referenced',   count(*) filter (where status = 'closed' and now() - last_checked_at > p_delete_after and not unreferenced) from j
$$;

-- Applies the policy to at most p_batch jobs of each kind. Refuses without the owner's phrase, with a nonsensical policy, while another
-- call runs, and when it would touch more than 20 % of the closed jobs at once (a sign of wrong data) unless p_allow_large is set.
create function ops.jobicy_retention_apply(
  p_confirm text,
  p_compact_after interval default interval '14 days',
  p_delete_after interval default interval '90 days',
  p_batch int default 200,
  p_allow_large boolean default false
) returns text language plpgsql as $$
declare
  v_compacted int := 0;
  v_deleted int := 0;
  v_closed bigint;
  v_candidates bigint;
  v_out text;
begin
  if p_confirm is distinct from 'EU-AUTORIZO-A-RETENCAO' then
    raise exception 'ops.jobicy_retention_apply: sem a frase de autorizacao do proprietario';
  end if;
  if p_compact_after < interval '7 days' then raise exception 'ops.jobicy_retention_apply: compact_after minimo e 7 dias'; end if;
  if p_delete_after < interval '30 days' or p_delete_after < p_compact_after + interval '14 days' then
    raise exception 'ops.jobicy_retention_apply: delete_after minimo e 30 dias e 14 dias depois de compact_after';
  end if;
  if p_batch < 1 or p_batch > 500 then raise exception 'ops.jobicy_retention_apply: batch entre 1 e 500'; end if;

  if not pg_try_advisory_xact_lock(hashtext('ops.jobicy_retention')) then
    insert into ops.retention_runs (outcome, compact_after, delete_after) values ('skipped:locked', p_compact_after, p_delete_after);
    return 'skipped:locked';
  end if;

  select count(*) filter (where status = 'closed') into v_closed from public.jobs where source_id = 'jobicy';
  select coalesce(sum(jobs), 0) into v_candidates from ops.jobicy_retention_plan(p_compact_after, p_delete_after) where layer in ('closed_to_compact', 'closed_to_delete');
  if not p_allow_large and v_candidates > greatest(50, v_closed / 5) then
    v_out := 'refused:too_many_candidates(' || v_candidates || ' of ' || v_closed || ' closed)';
    insert into ops.retention_runs (outcome, compact_after, delete_after) values (v_out, p_compact_after, p_delete_after);
    return v_out;
  end if;

  -- DELETE first (oldest closed, unreferenced), recording a tombstone for each; skip locked rows so a concurrent writer is never waited on.
  with d as (
    select j.id from public.jobs j
     where j.source_id = 'jobicy' and j.status = 'closed' and now() - j.last_checked_at > p_delete_after
       and not exists (select 1 from public.saved_jobs s where s.job_id = j.id)
       and not exists (select 1 from public.viewed_jobs v where v.job_id = j.id)
       and not exists (select 1 from public.applications a where a.job_id = j.id)
       and not exists (select 1 from public.job_clusters c where c.canonical_job_id = j.id)
     order by j.last_checked_at limit p_batch for update skip locked),
  del as (
    delete from public.jobs j using d where j.id = d.id and j.status = 'closed'
    returning j.source_id, j.external_id),
  tomb as (
    insert into ops.job_tombstones (source_id, external_id) select source_id, external_id from del on conflict do nothing returning 1)
  select count(*) into v_deleted from del;

  -- COMPACT: empty the heavy fields of closed jobs that still carry them (the generated search column follows).
  with c as (
    select j.id from public.jobs j
     where j.source_id = 'jobicy' and j.status = 'closed' and now() - j.last_checked_at > p_compact_after
       and (j.description <> '' or j.requirements <> '{}' or j.skills <> '{}')
     order by j.last_checked_at limit p_batch for update skip locked),
  upd as (
    update public.jobs j set description = '', requirements = '{}', skills = '{}'
      from c where j.id = c.id and j.status = 'closed'
    returning 1)
  select count(*) into v_compacted from upd;

  v_out := 'ok:compacted=' || v_compacted || ',deleted=' || v_deleted;
  insert into ops.retention_runs (outcome, compacted, deleted, compact_after, delete_after) values (v_out, v_compacted, v_deleted, p_compact_after, p_delete_after);
  return v_out;
end $$;

revoke all on function ops.jobicy_retention_plan(interval, interval) from public, anon, authenticated, service_role;
revoke all on function ops.jobicy_retention_apply(text, interval, interval, int, boolean) from public, anon, authenticated, service_role;
