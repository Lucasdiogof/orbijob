-- Undo of 20261017000000_sources_maintenance.sql: stops the expiry, drops it, and puts the Jobicy-only retention back.
-- Not run by anything automatically. Then forget the version if it was recorded:  delete from supabase_migrations.schema_migrations where version = '20261017000000';
-- It does NOT reopen jobs that the expiry closed and does NOT touch any job.
do $$
begin
  if to_regnamespace('cron') is not null then
    perform cron.unschedule(jobname) from cron.job where jobname = 'sources-expire-unseen';
  end if;
end $$;
drop function if exists ops.expire_unseen_jobs(text, interval, text[], int);
-- Read-only: how many jobs sit in each layer and what would be done. Changes nothing.
create or replace function ops.jobicy_retention_plan(p_compact_after interval default interval '14 days', p_delete_after interval default interval '90 days')
returns table (layer text, jobs bigint) language sql stable set search_path = pg_catalog as $$
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
create or replace function ops.jobicy_retention_apply(
  p_confirm text,
  p_compact_after interval default interval '14 days',
  p_delete_after interval default interval '90 days',
  p_batch int default 200,
  p_allow_large boolean default false
) returns text language plpgsql set search_path = pg_catalog as $$
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
    delete from public.jobs j using d
     where j.id = d.id and j.status = 'closed'
       -- re-checked at delete time: a reference committed after the candidate list was read must still stop the delete (and the cascade)
       and not exists (select 1 from public.saved_jobs s where s.job_id = j.id)
       and not exists (select 1 from public.viewed_jobs v where v.job_id = j.id)
       and not exists (select 1 from public.applications a where a.job_id = j.id)
       and not exists (select 1 from public.job_clusters c where c.canonical_job_id = j.id)
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

-- Recovery. EXPORT (read-only): the full rows the next apply would compact or delete, oldest first, at most p_limit. Save the result to a file
-- (with the SHA-256) BEFORE the first real run and before any run with other numbers.
create or replace function ops.jobicy_retention_export(
  p_compact_after interval default interval '14 days',
  p_delete_after interval default interval '90 days',
  p_limit int default 1000
) returns jsonb language sql stable set search_path = pg_catalog as $$
  select coalesce(jsonb_agg(to_jsonb(j) - 'search' order by j.last_checked_at), '[]'::jsonb)
    from (select * from public.jobs
           where source_id = 'jobicy' and status = 'closed' and now() - last_checked_at > p_compact_after
             and (description <> '' or requirements <> '{}' or skills <> '{}'
                  or (now() - last_checked_at > p_delete_after
                      and not exists (select 1 from public.saved_jobs s where s.job_id = jobs.id)
                      and not exists (select 1 from public.viewed_jobs v where v.job_id = jobs.id)
                      and not exists (select 1 from public.applications a where a.job_id = jobs.id)
                      and not exists (select 1 from public.job_clusters c where c.canonical_job_id = jobs.id)))
           order by last_checked_at limit least(greatest(p_limit, 1), 5000)) j
$$;

-- RESTORE: puts an export back. Jobs that were deleted are re-inserted with their old id (and their tombstone removed); jobs that still exist but
-- were compacted get their description, requirements and skills back. Nothing that exists with content is overwritten.
create or replace function ops.jobicy_retention_restore(p_confirm text, p_data jsonb) returns text
language plpgsql set search_path = pg_catalog as $$
declare v_ins int; v_upd int;
begin
  if p_confirm is distinct from 'EU-AUTORIZO-A-RESTAURACAO' then
    raise exception 'ops.jobicy_retention_restore: sem a frase de autorizacao do proprietario';
  end if;
  if p_data is null or jsonb_typeof(p_data) <> 'array' then raise exception 'ops.jobicy_retention_restore: esperava um array JSON (a saida de ops.jobicy_retention_export)'; end if;

  with src as (select * from jsonb_populate_recordset(null::public.jobs, p_data) where source_id = 'jobicy'),
  ins as (
    insert into public.jobs (id, source_id, external_id, cluster_id, company, title, description, country, city, language, work_mode, contract_type,
                             salary_min, salary_max, salary_currency, salary_period, published_at, last_checked_at, requirements, skills,
                             original_url, apply_url, status, geo_restrictions, isco08, fingerprint, canonical_url)
    select id, source_id, external_id, null, company, title, description, country, city, language, work_mode, contract_type,
           salary_min, salary_max, salary_currency, salary_period, published_at, last_checked_at, requirements, skills,
           original_url, apply_url, status, geo_restrictions, isco08, fingerprint, canonical_url from src
    on conflict do nothing returning 1)
  select count(*) into v_ins from ins;

  with src as (select * from jsonb_populate_recordset(null::public.jobs, p_data) where source_id = 'jobicy'),
  upd as (
    update public.jobs j set description = s.description, requirements = s.requirements, skills = s.skills
      from src s where j.id = s.id and j.description = '' and s.description <> '' returning 1)
  select count(*) into v_upd from upd;

  delete from ops.job_tombstones t
   using (select source_id, external_id from jsonb_populate_recordset(null::public.jobs, p_data)) s
   where t.source_id = s.source_id and t.external_id = s.external_id
     and exists (select 1 from public.jobs j where j.source_id = s.source_id and j.external_id = s.external_id);
  return 'ok:reinserted=' || v_ins || ',restored=' || v_upd;
end $$;

revoke all on function ops.jobicy_retention_plan(interval, interval) from public, anon, authenticated, service_role;
revoke all on function ops.jobicy_retention_export(interval, interval, int) from public, anon, authenticated, service_role;
revoke all on function ops.jobicy_retention_restore(text, jsonb) from public, anon, authenticated, service_role;
revoke all on function ops.jobicy_retention_apply(text, interval, interval, int, boolean) from public, anon, authenticated, service_role;
