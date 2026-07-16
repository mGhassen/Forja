-- Table grants for PostgREST roles (anon / authenticated / service_role).
-- Without these, service_role JWT gets "permission denied" on user_settings.

grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on table public.user_settings
  to authenticated, service_role;

grant select on table public.releases to anon, authenticated, service_role;
grant select on table public.release_assets to anon, authenticated, service_role;
grant select on table public.announcements to anon, authenticated, service_role;

grant all on table public.releases to service_role;
grant all on table public.release_assets to service_role;
grant all on table public.announcements to service_role;
