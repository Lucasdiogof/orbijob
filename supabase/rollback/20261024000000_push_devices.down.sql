-- Rollback of 20261024000000 (push). Removes the device tokens and the sender's functions; notifications themselves are kept.
drop function if exists public.push_forget_tokens(text[]);
drop function if exists public.push_claim(int);
drop function if exists public.push_register(text, text, text);
drop index if exists public.notifications_unpushed_idx;
alter table public.notifications drop column if exists pushed_at;
drop table if exists public.push_devices;
