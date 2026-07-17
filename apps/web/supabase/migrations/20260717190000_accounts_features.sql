-- Account-level feature flags (lean JSON).
-- Default '{}': all features disabled. Only store keys when activated
-- (e.g. {"iptvScrape": true}). Never store false flags.

alter table public.accounts
  add column if not exists features jsonb not null default '{}'::jsonb;

comment on column public.accounts.features is
  'Lean account feature flags. Empty object = all off. Enabled keys only (e.g. iptvScrape).';
