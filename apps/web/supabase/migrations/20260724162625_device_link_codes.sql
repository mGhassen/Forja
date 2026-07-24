-- Device-code rows for Android TV → portal /connect account linking.
-- Only Edge (service_role) reads/writes; no client RLS policies.

create table public.device_link_codes (
  id uuid primary key default gen_random_uuid(),
  user_code text not null,
  device_code text not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'consumed', 'expired', 'denied')),
  user_id uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz
);

create unique index device_link_codes_user_code_uidx
  on public.device_link_codes (user_code);

create unique index device_link_codes_device_code_uidx
  on public.device_link_codes (device_code);

create index device_link_codes_status_expires_idx
  on public.device_link_codes (status, expires_at);

alter table public.device_link_codes enable row level security;

-- No policies for authenticated/anon — Edge uses service_role only.
revoke all on table public.device_link_codes from public;
revoke all on table public.device_link_codes from anon;
revoke all on table public.device_link_codes from authenticated;
grant all on table public.device_link_codes to service_role;

-- Mark past-expiry pending/approved rows as expired (optional housekeeping).
create or replace function public.expire_device_link_codes()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated int;
begin
  update public.device_link_codes
  set status = 'expired'
  where status in ('pending', 'approved')
    and expires_at < now();
  get diagnostics updated = row_count;
  return updated;
end;
$$;

revoke all on function public.expire_device_link_codes() from public;
grant execute on function public.expire_device_link_codes() to service_role;
