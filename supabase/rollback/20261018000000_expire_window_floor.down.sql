-- Rollback of 20261018000000: restores the expiry of migration 10 (no window floor). Same signature, so the scheduled command keeps working.
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
    if not exists (select 1 from public.sync_runs r where r.source_id = v_src and r.scope = 'discover' and r.status = 'ok' and r.started_at > now() - interval '36 hours') then
      v_skipped := v_skipped || v_src;
      continue;
    end if;
    with c as (
      select j.id from public.jobs j
       where j.source_id = v_src and j.status = 'open' and now() - j.last_checked_at > p_after
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
drop function if exists ops.source_window_floor(text, timestamptz);
