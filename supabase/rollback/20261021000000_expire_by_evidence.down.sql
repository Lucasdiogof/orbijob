-- Undo of 20261021000000_expire_by_evidence.sql: migration 12's expiry (arbeitnow: window; jobtech: verified; any other source closed by absence).
-- Not run by anything automatically. Then forget the version if it was recorded:  delete from supabase_migrations.schema_migrations where version = '20261021000000';
-- It does NOT touch any job.
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

revoke all on function ops.expire_unseen_jobs(text, interval, text[], int) from public, anon, authenticated, service_role;
drop function if exists ops.expiry_rule(text);
