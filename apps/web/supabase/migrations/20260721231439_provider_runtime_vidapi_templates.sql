-- Add VidAPI template embed URLs (https://vidapi.xyz/).
-- TMDB ids — same as other HostRequired embeds. JSON API is not available yet.
-- In-scope only. Do not push without explicit approval.

update public.provider_runtime_config
set
  config = jsonb_set(
    config,
    '{templates,vidapi}',
    '{
      "movie": "https://vidapi.xyz/embed/movie/{tmdb}",
      "tv": "https://vidapi.xyz/embed/tv/{tmdb}/{season}/{episode}"
    }'::jsonb,
    true
  ),
  updated_at = now()
where id = 1;
