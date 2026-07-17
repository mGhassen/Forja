-- Lean profile_settings payloads: drop films, strip M3U channels[], omit empty favorites.

update public.profile_settings
set
  payload = (
    (payload - 'films')
    || jsonb_build_object(
      'iptv',
      coalesce(payload -> 'iptv', '{}'::jsonb)
        || jsonb_build_object(
          'portals',
          coalesce(
            (
              select jsonb_agg(
                case
                  when coalesce((elem ->> 'favorite')::boolean, false)
                  then elem
                  else elem - 'favorite'
                end
              )
              from jsonb_array_elements(
                coalesce(payload -> 'iptv' -> 'portals', '[]'::jsonb)
              ) elem
            ),
            '[]'::jsonb
          ),
          'm3uPlaylists',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'id', pl ->> 'id',
                  'name', pl ->> 'name',
                  'sourceUrl', pl ->> 'sourceUrl',
                  'addedAt', pl -> 'addedAt',
                  'updatedAt', pl -> 'updatedAt'
                )
              )
              from jsonb_array_elements(
                coalesce(payload -> 'iptv' -> 'm3uPlaylists', '[]'::jsonb)
              ) pl
              where nullif(trim(pl ->> 'sourceUrl'), '') is not null
            ),
            '[]'::jsonb
          )
        )
    )
  ),
  updated_at = now()
where payload ? 'films'
   or payload #> '{iptv,m3uPlaylists}' is not null;
