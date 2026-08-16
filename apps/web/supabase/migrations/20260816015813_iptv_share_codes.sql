-- 8-char IPTV portal share lookup. Payload is an encrypted F1. token (app/web
-- encrypt locally). Anon insert/select so guests can share without a session.

create table public.iptv_share_codes (
  code text primary key
    check (char_length(code) = 8 and code ~ '^[A-Z0-9]+$'),
  token text not null,
  created_at timestamptz not null default now()
);

alter table public.iptv_share_codes enable row level security;

create policy iptv_share_codes_insert_any
  on public.iptv_share_codes
  for insert
  to anon, authenticated
  with check (true);

create policy iptv_share_codes_select_any
  on public.iptv_share_codes
  for select
  to anon, authenticated
  using (true);

grant select, insert on table public.iptv_share_codes to anon, authenticated;
grant all on table public.iptv_share_codes to service_role;
