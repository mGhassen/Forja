-- Shared TMDB gateway response cache (API JSON + image bytes).
-- Written only by the gateway service role; no client RLS access.

create table public.tmdb_response_cache (
  cache_key text primary key,
  body bytea not null,
  content_type text not null default 'application/json',
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);

comment on table public.tmdb_response_cache is
  'TMDB gateway shared cache — full response bodies keyed by normalized path+query.';

create index tmdb_response_cache_expires_at_idx
  on public.tmdb_response_cache (expires_at);

alter table public.tmdb_response_cache enable row level security;

-- No policies for anon/authenticated — service_role bypasses RLS.
