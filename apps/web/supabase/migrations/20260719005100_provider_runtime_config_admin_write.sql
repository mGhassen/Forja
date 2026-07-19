-- Allow admins to update the single provider_runtime_config row (RFC-039 ops UI).

create policy provider_runtime_config_admin_update
  on public.provider_runtime_config
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin() and id = 1);
