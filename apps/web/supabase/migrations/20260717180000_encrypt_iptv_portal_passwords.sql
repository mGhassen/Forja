-- Encrypt iptv_portals.password at rest (pgcrypto).
-- Clients still receive plaintext via get_iptv_portals (authorized only).
-- Studio / raw SELECT shows ciphertext (v1:<base64>).
--
-- Production: set a strong DB setting (cannot run inside a migration txn):
--   alter database postgres set app.settings.iptv_portal_key = '<long-random-secret>';
-- Until set, local/dev uses the fallback below (change before any real deploy).

create extension if not exists pgcrypto with schema extensions;

create or replace function public._iptv_portal_secret()
returns text
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  secret text;
begin
  secret := nullif(current_setting('app.settings.iptv_portal_key', true), '');
  if secret is null or length(secret) < 16 then
    -- Dev-only fallback. Production MUST set app.settings.iptv_portal_key.
    secret := 'forja-local-dev-iptv-portal-key-change-in-prod';
  end if;
  return secret;
end;
$$;

create or replace function public._iptv_encrypt_password(plaintext text)
returns text
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
begin
  if plaintext is null or plaintext = '' then
    return '';
  end if;
  if left(plaintext, 3) = 'v1:' then
    return plaintext;
  end if;
  return 'v1:' || encode(
    pgp_sym_encrypt(plaintext, public._iptv_portal_secret()),
    'base64'
  );
end;
$$;

create or replace function public._iptv_decrypt_password(ciphertext text)
returns text
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
begin
  if ciphertext is null or ciphertext = '' then
    return '';
  end if;
  -- Legacy plaintext (pre-migration)
  if left(ciphertext, 3) <> 'v1:' then
    return ciphertext;
  end if;
  return pgp_sym_decrypt(
    decode(substr(ciphertext, 4), 'base64'),
    public._iptv_portal_secret()
  );
end;
$$;

revoke all on function public._iptv_portal_secret() from public;
revoke all on function public._iptv_encrypt_password(text) from public;
revoke all on function public._iptv_decrypt_password(text) from public;

create or replace function public._iptv_portals_encrypt_password_trg()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  new.password := public._iptv_encrypt_password(new.password);
  return new;
end;
$$;

drop trigger if exists iptv_portals_encrypt_password on public.iptv_portals;
create trigger iptv_portals_encrypt_password
  before insert or update of password on public.iptv_portals
  for each row
  execute function public._iptv_portals_encrypt_password_trg();

update public.iptv_portals
set password = public._iptv_encrypt_password(password)
where password is not null
  and password <> ''
  and left(password, 3) <> 'v1:';

create or replace function public.get_iptv_portals(p_ids uuid[])
returns setof public.iptv_portals
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if public.is_admin() then
    return query
      select
        p.id,
        p.url,
        p.username,
        public._iptv_decrypt_password(p.password) as password,
        p.source,
        p.expiry,
        p.max_connections,
        p.created_at,
        p.updated_at,
        p.created_by,
        p.updated_by
      from public.iptv_portals p
      where p.id = any (p_ids);
    return;
  end if;

  return query
    select
      p.id,
      p.url,
      p.username,
      public._iptv_decrypt_password(p.password) as password,
      p.source,
      p.expiry,
      p.max_connections,
      p.created_at,
      p.updated_at,
      p.created_by,
      p.updated_by
    from public.iptv_portals p
    where p.id = any (p_ids)
      and exists (
        select 1
        from public.user_iptv_portals u
        where u.account_id = auth.uid()
          and u.portal_id = p.id
      );
end;
$$;

grant execute on function public.get_iptv_portals(uuid[])
  to authenticated, service_role;
