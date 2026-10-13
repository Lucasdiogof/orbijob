-- Push notifications (Firebase Cloud Messaging) for the alerts of migration 16. In-app delivery is unchanged: public.notifications stays the
-- single source, push is only a copy of a new row sent to the person's devices.
--
--   * push_devices                  device tokens of a signed-in person (Android / iOS), written by the app itself under owner-only RLS; at most 10
--                                   per person (the app makes room by removing its oldest). A device shared by two accounts holds one row per account;
--                                   the app removes its row on sign-out.
--   * notifications.pushed_at       when the row was handed to the sender (or skipped: notifications off, no device). Not writable by the client.
--   * ops.push_claim(limit)         atomically marks up to `limit` unsent rows of the last 6 hours and returns what to send.
--   * ops.push_forget_tokens(text[]) deletes tokens FCM reported as no longer registered.
--   Both live in `ops` (not exposed by the API) and only the owner runs them: the sender is the Edge Function `push-send`, which uses the
--   project's internal database connection. No API role (anon, authenticated, service_role) gains anything on notifications or devices beyond
--   the person's own rows.
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
  unique (user_id, token)
);
create index if not exists push_devices_user_idx on public.push_devices (user_id, last_seen_at desc);
alter table public.push_devices enable row level security;
drop policy if exists push_devices_owner on public.push_devices;
create policy push_devices_owner on public.push_devices for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke all on public.push_devices from anon, authenticated, service_role;
grant select, delete on public.push_devices to authenticated;
grant insert (user_id, token, platform, locale) on public.push_devices to authenticated;
grant update (platform, locale, last_seen_at) on public.push_devices to authenticated;
drop trigger if exists push_devices_quota on public.push_devices;
create trigger push_devices_quota before insert on public.push_devices
  for each row execute function public.enforce_row_quota(10, 'token');

alter table public.notifications add column if not exists pushed_at timestamptz;
create index if not exists notifications_unpushed_idx on public.notifications (created_at) where pushed_at is null;

create or replace function ops.push_claim(p_limit int default 200)
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

create or replace function ops.push_forget_tokens(p_tokens text[])
returns int language sql set search_path = pg_catalog, public as $$
  with d as (delete from public.push_devices where token = any (p_tokens[1:500]) returning 1) select count(*)::int from d
$$;

revoke all on function ops.push_claim(int) from public, anon, authenticated, service_role;
revoke all on function ops.push_forget_tokens(text[]) from public, anon, authenticated, service_role;
comment on function ops.push_claim(int) is 'Push sender (Edge Function push-send): claims unsent notifications with the devices to send them to. Migration 20261024000000.';
