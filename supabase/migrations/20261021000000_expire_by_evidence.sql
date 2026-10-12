-- Migration 14: the expiry decides by EVIDENCE, and a source added later is safe by default.
--
-- Migration 12 hard-coded two special cases (arbeitnow: window; jobtech: verified one by one) and closed everything else by absence. A new source whose list is a
-- daily extract (the Taiwan Jobs dataset) would have been closed by mistake when it left the extract. Now the only sources closed by absence are the two that list
-- EVERY open job in a single answer (remoteok, remotive); arbeitnow keeps its window rule (closed inside the window, 'unknown' beyond it); every other source,
-- including the ones added later, turns 'unknown' (hidden, kept 30 days with its text, recoverable) and is never closed without the source's own evidence.
-- The default list of the scheduled command now includes twjobs. Same signature, same guards, same scheduled commands.
-- Rollback: supabase/rollback/20261021000000_expire_by_evidence.down.sql (puts migration 12's expiry back).

-- The single place that says how a source is judged when its jobs stop being listed (read-only; the expiry calls it).
create or replace function ops.expiry_rule(p_source text) returns text language sql immutable set search_path = pg_catalog as $$
  select case when p_source in ('remoteok', 'remotive') then 'feed' when p_source = 'arbeitnow' then 'window' else 'verified' end
$$;
revoke all on function ops.expiry_rule(text) from public, anon, authenticated, service_role;

create or replace function ops.expire_unseen_jobs(
  p_confirm text,
  p_after interval default interval '7 days',
  p_sources text[] default array['arbeitnow', 'remoteok', 'remotive', 'twjobs'],
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
  v_mode text;
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
    -- 'feed': the source lists EVERY open job in one answer, so absence is the evidence (closed). 'window': newest pages only (closed inside the window, unknown beyond).
    -- 'verified': anything else (the Platsbanken, verified one by one; the Taiwan daily extract; every source added later): absence proves nothing, so a stale job
    -- becomes 'unknown', never 'closed'. A new source is safe by default.
    v_mode := ops.expiry_rule(v_src);
    if v_mode <> 'verified' then
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

    if v_mode <> 'verified' then
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

    if v_mode <> 'feed' then
      -- nothing proves these are gone: they become 'unknown' (the app shows only 'open'; last_checked_at stays as the date of the last real check)
      with c as (
        select j.id from public.jobs j
         where j.source_id = v_src and j.status = 'open' and now() - j.last_checked_at > p_after
           and (v_mode = 'verified' or j.published_at is null or j.published_at < v_floor)
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
