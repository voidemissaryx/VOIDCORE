-- Create a profile row for each new VOIDCORE auth user.
create or replace function public.handle_new_voidcore_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare requested_username text;
begin
  requested_username := new.raw_user_meta_data ->> 'username';
  if requested_username is null
     or char_length(requested_username) not between 3 and 24
     or requested_username !~ '^[A-Za-z0-9_]+$' then
    raise exception 'A valid VOIDCORE username is required';
  end if;
  insert into public.profiles (id, username) values (new.id, requested_username);
  return new;
end;
$$;
drop trigger if exists on_auth_user_created_voidcore_profile on auth.users;
create trigger on_auth_user_created_voidcore_profile after insert on auth.users
for each row execute procedure public.handle_new_voidcore_user();
