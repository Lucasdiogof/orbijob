-- Rollback of 20261025000000 (application reminders): removes reminder rows and the reminder machinery; push_claim goes back to migration 17.
drop function if exists ops.reminders_run(timestamptz);
delete from public.notifications where kind <> 'new_job';
drop index if exists public.notifications_reminder_once;
drop index if exists public.notifications_application_idx;
alter table public.notifications drop column if exists remind_key;
alter table public.notifications drop column if exists application_id;
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check (kind in ('new_job'));
drop function if exists ops.push_claim(int);
create function ops.push_claim(p_limit int default 200)
returns table (notification_id uuid, user_id uuid, job_id uuid, title text, company text, token text, platform text, locale text)
language plpgsql set search_path = pg_catalog, public as $$
begin
  if p_limit < 1 or p_limit > 1000 then raise exception 'push_claim: limit between 1 and 1000'; end if;
  return query
  with c as (
    select n.id from public.notifications n
     where n.pushed_at is null and n.dismissed_at is null and n.read_at is null and n.created_at > now() - interval '6 hours'
     order by n.created_at limit p_limit for update skip locked),
  m as (update public.notifications n set pushed_at = now() from c where n.id = c.id
        returning n.id, n.user_id, n.job_id, n.title, n.company)
  select m.id, m.user_id, m.job_id, m.title, m.company, d.token, d.platform, d.locale
    from m join public.push_devices d on d.user_id = m.user_id
   where coalesce((select (up.settings -> 'notifications' ->> 'enabled')::boolean from public.user_preferences up where up.user_id = m.user_id), true);
end $$;
revoke all on function ops.push_claim(int) from public, anon, authenticated, service_role;
