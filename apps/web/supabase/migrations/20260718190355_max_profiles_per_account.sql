-- Cap each account at 5 profiles.

create or replace function public.enforce_max_profiles_per_account()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    select count(*)::int
    from public.profiles
    where account_id = new.account_id
  ) >= 5 then
    raise exception 'Maximum of 5 profiles per account'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_enforce_max on public.profiles;

create trigger profiles_enforce_max
  before insert on public.profiles
  for each row execute function public.enforce_max_profiles_per_account();
