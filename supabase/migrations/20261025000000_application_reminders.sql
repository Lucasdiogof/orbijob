-- Reminders for the application pipeline (migration 16 added interview_at / follow_up_at). They become rows of public.notifications, so the
-- notification centre and the push sender (migration 17) deliver them with no new channel.
--
--   * notifications.kind            'new_job' (alerts) | 'interview' | 'follow_up'.
--   * notifications.application_id  the application a reminder is about (job_id stays null for reminders: the unique (user_id, job_id) of
--                                    job alerts is untouched).
--   * notifications.remind_key      the date the reminder is for; with (application_id, kind) it is unique, so each date is reminded once.
--   * ops.reminders_run()           hourly (pg_cron `reminders-run`, scripts/supabase/ops/enable_reminders_cron.sql): an interview in the next
--                                    24 hours, a follow-up date that is today or passed less than 2 days ago. Only open processes (not hired,
--                                    rejected, withdrawn or closed); the person's notifications switch is respected. Nothing is said about the
--                                    employer: the text is the person's own job title and company.
--   * ops.push_claim                 now also returns `kind` and `application_id` (the sender words a reminder differently).
--
-- Idempotent. Rollback: supabase/rollback/20261025000000_application_reminders.down.sql.

alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check (kind in ('new_job', 'interview', 'follow_up'));
alter table public.notifications add column if not exists application_id uuid references public.applications(id) on delete cascade;
alter table public.notifications add column if not exists remind_key date;
create unique index if not exists notifications_reminder_once on public.notifications (application_id, kind, remind_key) where application_id is not null;
create index if not exists notifications_application_idx on public.notifications (application_id) where application_id is not null;

create or replace function ops.reminders_run(p_now timestamptz default now())
returns text language plpgsql set search_path = pg_catalog, public as $$
declare
  v_interview int := 0;
  v_follow int := 0;
begin
  if not pg_try_advisory_xact_lock(hashtext('ops.reminders_run')) then return 'skipped:locked'; end if;

  with c as (
    select a.id, a.user_id, a.interview_at, a.job_snapshot from public.applications a
     where a.interview_at > p_now and a.interview_at <= p_now + interval '24 hours'
       and a.stage not in ('hired', 'rejected', 'withdrawn', 'closed')
       and coalesce((select (up.settings -> 'notifications' ->> 'enabled')::boolean from public.user_preferences up where up.user_id = a.user_id), true)),
  ins as (
    insert into public.notifications (user_id, kind, application_id, remind_key, title, company, original_url, created_at)
    select c.user_id, 'interview', c.id, (c.interview_at at time zone 'UTC')::date,
           left(coalesce(nullif(btrim(c.job_snapshot ->> 'title'), ''), '—'), 300),
           left(nullif(btrim(c.job_snapshot ->> 'company'), ''), 200),
           case when (c.job_snapshot ->> 'originalUrl') ~ '^https?://' then left(c.job_snapshot ->> 'originalUrl', 2048) end,
           p_now
      from c
    on conflict (application_id, kind, remind_key) where application_id is not null do nothing
    returning 1)
  select count(*) into v_interview from ins;

  with c as (
    select a.id, a.user_id, a.follow_up_at, a.job_snapshot from public.applications a
     where a.follow_up_at <= p_now + interval '1 hour' and a.follow_up_at > p_now - interval '2 days'
       and (a.follow_up_at at time zone 'UTC')::date <= (p_now at time zone 'UTC')::date
       and a.stage not in ('hired', 'rejected', 'withdrawn', 'closed')
       and coalesce((select (up.settings -> 'notifications' ->> 'enabled')::boolean from public.user_preferences up where up.user_id = a.user_id), true)),
  ins as (
    insert into public.notifications (user_id, kind, application_id, remind_key, title, company, original_url, created_at)
    select c.user_id, 'follow_up', c.id, (c.follow_up_at at time zone 'UTC')::date,
           left(coalesce(nullif(btrim(c.job_snapshot ->> 'title'), ''), '—'), 300),
           left(nullif(btrim(c.job_snapshot ->> 'company'), ''), 200),
           case when (c.job_snapshot ->> 'originalUrl') ~ '^https?://' then left(c.job_snapshot ->> 'originalUrl', 2048) end,
           p_now
      from c
    on conflict (application_id, kind, remind_key) where application_id is not null do nothing
    returning 1)
  select count(*) into v_follow from ins;

  return 'ok:interview=' || v_interview || ',follow_up=' || v_follow;
end $$;
revoke all on function ops.reminders_run(timestamptz) from public, anon, authenticated, service_role;
comment on function ops.reminders_run(timestamptz) is 'Hourly: interview and follow-up reminders of open applications as notifications. Migration 20261025000000.';

-- the sender needs the kind (different wording for a reminder) and the application (the app opens it)
drop function if exists ops.push_claim(int);
create function ops.push_claim(p_limit int default 200)
returns table (notification_id uuid, user_id uuid, job_id uuid, title text, company text, token text, platform text, locale text,
               kind text, application_id uuid)
language plpgsql set search_path = pg_catalog, public as $$
begin
  if p_limit < 1 or p_limit > 1000 then raise exception 'push_claim: limit between 1 and 1000'; end if;
  return query
  with c as (
    select n.id from public.notifications n
     where n.pushed_at is null and n.dismissed_at is null and n.read_at is null and n.created_at > now() - interval '6 hours'
     order by n.created_at limit p_limit for update skip locked),
  m as (update public.notifications n set pushed_at = now() from c where n.id = c.id
        returning n.id, n.user_id, n.job_id, n.title, n.company, n.kind, n.application_id)
  select m.id, m.user_id, m.job_id, m.title, m.company, d.token, d.platform, d.locale, m.kind, m.application_id
    from m join public.push_devices d on d.user_id = m.user_id
   where coalesce((select (up.settings -> 'notifications' ->> 'enabled')::boolean from public.user_preferences up where up.user_id = m.user_id), true);
end $$;
revoke all on function ops.push_claim(int) from public, anon, authenticated, service_role;
comment on function ops.push_claim(int) is 'Push sender (Edge Function push-send): claims unsent notifications with the devices to send them to. Migrations 20261024000000 / 20261025000000.';
