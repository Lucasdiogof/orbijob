-- The expiry of jobs a feed no longer lists (migration 10) must not close a job only because the pass did not read far enough.
--
-- Remote OK and Remotive publish their whole feed in one response: "not listed" there means "gone". Arbeitnow is read as a WINDOW: the newest
-- pages of a newest-first feed (worker/src/sources.ts, pageWindow). A job that is still open but older than what the window reached is simply not
-- seen, and the expiry would have closed it 7 days later. From now on, for a window source, a job is judged only when it was published at or after
-- the oldest job the latest 'ok' pass of that source saw (its "floor"). Older jobs are left alone (the app already hides them after 72 h); a
-- source whose floor cannot be computed is skipped, exactly like a source without a recent successful pass.
--
-- Same signature, same guards, same scheduled command. Rollback: supabase/rollback/20261018000000_expire_window_floor.down.sql.
create or replace function ops.expire_unseen_jobs(
  p_confirm text,
  p_after interval default interval '7 days',
  p_sources text[] default array['arbeitnow', 'remoteok', 'remotive'],
  p_batch int default 500
) returns text language plpgsql set search_path = pg_catalog as $$
declare
  v_src text;
  v_closed int;
  v_total int := 0;
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
    -- the feed must have been read successfully recently, otherwise absence proves nothing
    select max(r.started_at) into v_last_ok from public.sync_runs r
     where r.source_id = v_src and r.scope = 'discover' and r.status = 'ok' and r.started_at > now() - interval '36 hours';
    if v_last_ok is null then
      v_skipped := v_skipped || v_src;
      continue;
    end if;
    v_floor := null;
    if v_src = 'arbeitnow' then -- read as a window of its newest pages: judge only what that window covers
      select min(k.published_at) into v_floor from public.jobs k
       where k.source_id = v_src and k.status = 'open' and k.last_checked_at >= v_last_ok;
      if v_floor is null then
        v_skipped := v_skipped || v_src;
        continue;
      end if;
    end if;
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
  end loop;

  v_out := 'ok:expired=' || v_total || coalesce(',skipped=' || nullif(array_to_string(v_skipped, '/'), ''), '');
  insert into ops.retention_runs (outcome, compacted, deleted, compact_after, delete_after) values ('expire:' || v_out, 0, 0, p_after, p_after);
  return v_out;
end $$;
revoke all on function ops.expire_unseen_jobs(text, interval, text[], int) from public, anon, authenticated, service_role;
