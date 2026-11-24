-- Admin authorization and account suspension metadata.
alter table public.profiles
  add column if not exists role text not null default 'user',
  add column if not exists disabled_at timestamptz;

alter table public.profiles
  drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check check (role in ('user', 'admin'));

-- After the owner has created their VOIDCORE account, run this manually:
-- update public.profiles set role = 'admin' where lower(username) = 'voidemissaryx';
