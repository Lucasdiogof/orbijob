-- Freshness policy (migration 12). Three changes, no new table and no new column:
--
-- 1. status 'unknown' now has a job: "the source stopped showing it and nothing proves it is gone". ops.expire_unseen_jobs keeps its signature
--    (so both scheduled commands keep working) but no longer treats absence as proof where absence proves nothing:
--      * remoteok, remotive (the feed lists EVERYTHING open): unseen > N days  -> 'closed'      (absence from a complete feed IS the evidence)
--      * arbeitnow (read as a window of the newest pages): inside the window    -> 'closed'
--                                                          older than the window -> 'unknown'    (cannot be verified; hidden by the app anyway)
--      * jobtech (Platsbanken: verified one by one through /ad/{id}, closures come from the 404): unseen > N days -> 'unknown' (revalidation is not
--        reaching it); it is never closed by absence.
--    Any other source keeps the previous rule (closed).
-- 2. The retention (compact after 14 days, delete after 90, referenced jobs kept) now treats 'unknown' like 'closed'. Open jobs are still never touched.
--    Without this a window source piled up 'open' rows nobody could verify until its catalogue ceiling blocked every new import.
-- 3. ops.freshness_report(): read-only counts per source of what is verified, stale (open but not checked in the last 72 h = hidden by the app),
--    unknown and closed. For the watchdog and for humans.
-- Rollback: supabase/rollback/20261019000000_freshness_policy.down.sql (restores migration 11's expiry and migration 10's retention; leaves every job as it is).

create or replace function ops.jobicy_retention_plan(p_compact_after interval default interval '14 days', p_delete_after interval default interval '90 days')
returns table (layer text, jobs bigint) language sql stable set search_path = pg_catalog as $$
  with j as (
    select status, last_checked_at, (description <> '' or requirements <> '{}' or skills <> '{}') as has_body,
           not (exists (select 1 from public.saved_jobs s where s.job_id = jobs.id)
             or exists (select 1 from public.viewed_jobs v where v.job_id = jobs.id)
             or exists (select 1 from public.applications a where a.job_id = jobs.id)
             or exists (select 1 from public.job_clusters c where c.canonical_job_id = jobs.id)) as unreferenced
      from public.jobs)
  select 'open'::text,                         count(*) filter (where status = 'open') from j
  union all select 'closed_recent',            count(*) filter (where status in ('closed', 'unknown') and now() - last_checked_at <= p_compact_after) from j
  union all select 'closed_to_compact',        count(*) filter (where status in ('closed', 'unknown') and now() - last_checked_at > p_compact_after and has_body) from j
  union all select 'closed_compacted',         count(*) filter (where status in ('closed', 'unknown') and now() - last_checked_at > p_compact_after and not has_body) from j
  union all select 'closed_to_delete',         count(*) filter (where status in ('closed', 'unknown') and now() - last_checked_at > p_delete_after and unreferenced) from j
  union all select 'closed_kept_referenced',   count(*) filter (where status in ('closed', 'unknown') and now() - last_checked_at > p_delete_after and not unreferenced) from j
$$;


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

  select count(*) filter (where status in ('closed', 'unknown')) into v_closed from public.jobs;
  select coalesce(sum(jobs), 0) into v_candidates from ops.jobicy_retention_plan(p_compact_after, p_delete_after) where layer in ('closed_to_compact', 'closed_to_delete');
  if not p_allow_large and v_candidates > greatest(50, v_closed / 5) then
    v_out := 'refused:too_many_candidates(' || v_candidates || ' of ' || v_closed || ' closed)';
    insert into ops.retention_runs (outcome, compact_after, delete_after) values (v_out, p_compact_after, p_delete_after);
    return v_out;
  end if;

  -- DELETE first (oldest closed, unreferenced), recording a tombstone for each; skip locked rows so a concurrent writer is never waited on.
  with d as (
    select j.id from public.jobs j
     where j.status in ('closed', 'unknown') and now() - j.last_checked_at > p_delete_after
       and not exists (select 1 from public.saved_jobs s where s.job_id = j.id)
       and not exists (select 1 from public.viewed_jobs v where v.job_id = j.id)
       and not exists (select 1 from public.applications a where a.job_id = j.id)
       and not exists (select 1 from public.job_clusters c where c.canonical_job_id = j.id)
     order by j.last_checked_at limit p_batch for update skip locked),
  del as (
    delete from public.jobs j using d
     where j.id = d.id and j.status in ('closed', 'unknown')
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
     where j.status in ('closed', 'unknown') and now() - j.last_checked_at > p_compact_after
       and (j.description <> '' or j.requirements <> '{}' or j.skills <> '{}')
     order by j.last_checked_at limit p_batch for update skip locked),
  upd as (
    update public.jobs j set description = '', requirements = '{}', skills = '{}'
      from c where j.id = c.id and j.status in ('closed', 'unknown')
    returning 1)
  select count(*) into v_compacted from upd;

  v_out := 'ok:compacted=' || v_compacted || ',deleted=' || v_deleted;
  insert into ops.retention_runs (outcome, compacted, deleted, compact_after, delete_after) values (v_out, v_compacted, v_deleted, p_compact_after, p_delete_after);
  return v_out;
end $$;


create or replace function ops.jobicy_retention_export(
  p_compact_after interval default interval '14 days',
  p_delete_after interval default interval '90 days',
  p_limit int default 1000
) returns jsonb language sql stable set search_path = pg_catalog as $$
  select coalesce(jsonb_agg(to_jsonb(j) - 'search' order by j.last_checked_at), '[]'::jsonb)
    from (select * from public.jobs
           where status in ('closed', 'unknown') and now() - last_checked_at > p_compact_after
             and (description <> '' or requirements <> '{}' or skills <> '{}'
                  or (now() - last_checked_at > p_delete_after
                      and not exists (select 1 from public.saved_jobs s where s.job_id = jobs.id)
                      and not exists (select 1 from public.viewed_jobs v where v.job_id = jobs.id)
                      and not exists (select 1 from public.applications a where a.job_id = jobs.id)
                      and not exists (select 1 from public.job_clusters c where c.canonical_job_id = jobs.id)))
           order by last_checked_at limit least(greatest(p_limit, 1), 5000)) j
$$;



create or replace function ops.expire_unseen_jobs(
  p_confirm text,
  p_after interval default interval '7 days',
  p_sources text[] default array['arbeitnow', 'remoteok', 'remotive'],
  p_batch int default 500
) returns text language plpgsql set search_path = pg_catalog as $$
declare
  v_src text;
  v_closed int;
  v_unknown int;
  v_total int := 0;
  v_unknown_total int := 0;
  v_skipped text[] := '{}';
  v_last_ok timestamptz;
  v_floor timestamptz;
  v_out text;
begin
  if p_confirm is distinct from 'EU-AUTORIZO-A-EXPIRACAO' then
    raise exception 'ops.expire_unseen_jobs: sem a frase de autorizacao do proprietario';
  end if;
  if p_after < interval '4 days' then raise exception 'ops.expire_unseen_jobs: p_after minimo e 4 dias'; end if;
  if p_batch < 1 or p_batch > 2000 then raise exception 'ops.expire_unseen_jobs: batch entre 1 e 2000'; end if;
  if 'jobicy' = any (p_sources) then raise exception 'ops.expire_unseen_jobs: o jobicy tem endpoint de status e nunca expira por ausencia'; end if;
  if not pg_try_advisory_xact_lock(hashtext('ops.expire_unseen_jobs')) then return 'skipped:locked'; end if;

  foreach v_src in array p_sources loop
    if v_src <> 'jobtech' then
      -- the feed must have been read successfully recently, otherwise absence proves nothing
      select max(r.started_at) into v_last_ok from public.sync_runs r
       where r.source_id = v_src and r.scope = 'discover' and r.status = 'ok' and r.started_at > now() - interval '36 hours';
      if v_last_ok is null then
        v_skipped := v_skipped || v_src;
        continue;
      end if;
    end if;
    v_floor := null;
    if v_src = 'arbeitnow' then -- read as a window of its newest pages: only what that window covers can be judged closed
      v_floor := ops.source_window_floor(v_src, v_last_ok);
      if v_floor is null then
        v_skipped := v_skipped || v_src;
        continue;
      end if;
    end if;

    if v_src <> 'jobtech' then
      with c as (
        select j.id from public.jobs j
         where j.source_id = v_src and j.status = 'open' and now() - j.last_checked_at > p_after
           and (v_floor is null or j.published_at >= v_floor)
         order by j.last_checked_at limit p_batch for update skip locked),
      upd as (
        update public.jobs j set status = 'closed', last_checked_at = now()
          from c where j.id = c.id and j.status = 'open'
        returning 1)
      select count(*) into v_closed from upd;
      v_total := v_total + v_closed;
    end if;

    if v_src = 'arbeitnow' or v_src = 'jobtech' then
      -- nothing proves these are gone: they become 'unknown' (the app shows only 'open'; last_checked_at stays as the date of the last real check)
      with c as (
        select j.id from public.jobs j
         where j.source_id = v_src and j.status = 'open' and now() - j.last_checked_at > p_after
           and (v_src = 'jobtech' or j.published_at is null or j.published_at < v_floor)
         order by j.last_checked_at limit p_batch for update skip locked),
      upd as (
        update public.jobs j set status = 'unknown'
          from c where j.id = c.id and j.status = 'open'
        returning 1)
      select count(*) into v_unknown from upd;
      v_unknown_total := v_unknown_total + v_unknown;
    end if;
  end loop;

  v_out := 'ok:expired=' || v_total || case when v_unknown_total > 0 then ',unknown=' || v_unknown_total else '' end
           || coalesce(',skipped=' || nullif(array_to_string(v_skipped, '/'), ''), '');
  insert into ops.retention_runs (outcome, compacted, deleted, compact_after, delete_after) values ('expire:' || v_out, 0, 0, p_after, p_after);
  return v_out;
end $$;
revoke all on function ops.expire_unseen_jobs(text, interval, text[], int) from public, anon, authenticated, service_role;

-- Read-only: per source, how many jobs are verified (visible in the app), stale (open but not checked for 72 h: hidden), unknown, closed.
create or replace function ops.freshness_report()
returns table (source_id text, open_visible bigint, open_stale bigint, unknown bigint, closed bigint, oldest_open_check timestamptz, newest_check timestamptz)
language sql stable set search_path = pg_catalog as $$
  select j.source_id,
         count(*) filter (where j.status = 'open' and j.last_checked_at >= now() - interval '72 hours'),
         count(*) filter (where j.status = 'open' and j.last_checked_at < now() - interval '72 hours'),
         count(*) filter (where j.status = 'unknown'),
         count(*) filter (where j.status = 'closed'),
         min(j.last_checked_at) filter (where j.status = 'open'),
         max(j.last_checked_at)
    from public.jobs j group by j.source_id order by j.source_id
$$;
revoke all on function ops.freshness_report() from public, anon, authenticated, service_role;

revoke all on function ops.jobicy_retention_plan(interval, interval) from public, anon, authenticated, service_role;
revoke all on function ops.jobicy_retention_export(interval, interval, int) from public, anon, authenticated, service_role;
revoke all on function ops.jobicy_retention_apply(text, interval, interval, int, boolean) from public, anon, authenticated, service_role;
