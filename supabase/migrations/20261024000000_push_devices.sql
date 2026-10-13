-- Push notifications (Firebase Cloud Messaging) for the alerts of migration 16. In-app delivery is unchanged: public.notifications stays the
-- single source, push is only a copy of a new row sent to the person's devices.
--
--   * push_devices                 one row per device token of a signed-in person (Android / iOS). Owner-only RLS; at most 10 per person.
--   * notifications.pushed_at      when the row was handed to the sender (or skipped: notifications off, no device). Not writable by the client.
--   * public.push_claim(limit)     the ONLY door of the sender (GitHub Actions, scripts/push-send.mjs, with the automation key): atomically marks
--                                  up to `limit` unsent rows of the last 6 hours and returns what to send. SECURITY DEFINER, executable by
--                                  service_role only, so that key gains no read access to notifications or devices.
--   * public.push_forget_tokens()  deletes tokens FCM reported as no longer registered. Same restriction.
--
-- Idempotent. Rollback: supabase/rollback/20261024000000_push_devices.down.sql.

create table if not exists public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  token text not null check (char_length(token) between 20 and 4096),
  platform text not null check (platform in ('android', 'ios', 'web')),
  locale text check (locale is null or char_length(locale) <= 20),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (token)
);
create index if not exists push_devices_user_idx on public.push_devices (user_id);
alter table public.push_devices enable row level security;
drop policy if exists push_devices_owner on public.push_devices;
create policy push_devices_owner on public.push_devices for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke all on public.push_devices from anon, authenticated, service_role;
-- reading and removing own devices; registering goes through public.push_register (handles a token taken over from another account)
grant select, delete on public.push_devices to authenticated;
drop trigger if exists push_devices_quota on public.push_devices;
create trigger push_devices_quota before insert on public.push_devices
  for each row execute function public.enforce_row_quota(10, 'token');

alter table public.notifications add column if not exists pushed_at timestamptz;
create index if not exists notifications_unpushed_idx on public.notifications (created_at) where pushed_at is null;

-- A token registered by another account on the same device (shared phone, sign-out + sign-in) is taken over by the person signing in now:
-- the unique token would otherwise refuse the insert, and the previous account must stop receiving pushes on a device it no longer uses.
create or replace function public.push_register(p_token text, p_platform text, p_locale text default null)
returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'push_register: sign in first'; end if;
  if p_token is null or char_length(p_token) not between 20 and 4096 then raise exception 'push_register: invalid token'; end if;
  if p_platform not in ('android', 'ios', 'web') then raise exception 'push_register: invalid platform'; end if;
  delete from public.push_devices where token = p_token and user_id <> v_uid;
  -- a new phone must not hit the 10-device quota: the least recently seen devices of this person make room
  delete from public.push_devices where id in (
    select id from public.push_devices where user_id = v_uid and token <> p_token order by last_seen_at desc offset 9);
  insert into public.push_devices (user_id, token, platform, locale) values (v_uid, p_token, p_platform, left(p_locale, 20))
    on conflict (token) do update set platform = excluded.platform, locale = excluded.locale, last_seen_at = now();
end $$;
revoke all on function public.push_register(text, text, text) from public, anon, service_role;
grant execute on function public.push_register(text, text, text) to authenticated;

create or replace function public.push_claim(p_limit int default 200)
returns table (notification_id uuid, user_id uuid, job_id uuid, title text, company text, token text, platform text, locale text)
language plpgsql security definer set search_path = pg_catalog, public as $$
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
revoke all on function public.push_claim(int) from public, anon, authenticated;
grant execute on function public.push_claim(int) to service_role;

create or replace function public.push_forget_tokens(p_tokens text[])
returns int language sql security definer set search_path = pg_catalog, public as $$
  with d as (delete from public.push_devices where token = any (p_tokens[1:500]) returning 1) select count(*)::int from d
$$;
revoke all on function public.push_forget_tokens(text[]) from public, anon, authenticated;
grant execute on function public.push_forget_tokens(text[]) to service_role;
