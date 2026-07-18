-- Remote provider runtime config (hosts, path templates, CDN Referer rules).
-- Single-row JSON overlay; extract logic stays in the app. Anon/authenticated
-- can read; only service_role writes (ops / Studio with service role).

create table public.provider_runtime_config (
  id int primary key default 1 check (id = 1),
  schema_version int not null default 1,
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

comment on table public.provider_runtime_config is
  'Global provider runtime overlay (hosts/paths/CDN rules). Schema 1 — see RFC-039.';

alter table public.provider_runtime_config enable row level security;

create policy provider_runtime_config_select_all
  on public.provider_runtime_config
  for select
  to anon, authenticated
  using (true);

-- Seed current Forja builtins so Studio can edit without guessing shape.
insert into public.provider_runtime_config (id, schema_version, config)
values (
  1,
  1,
  '{
    "schema": 1,
    "anime": {
      "megaplay": {
        "host": "megaplay.buzz",
        "pathCatalog": "/stream/s-2/{embedId}/{lang}",
        "pathAnilist": "/stream/ani/{anilistId}/{ep}/{lang}",
        "scrapeReferer": "https://www.enma.lol/"
      },
      "vidwish": {
        "host": "vidwish.live",
        "pathCatalog": "/stream/s-2/{embedId}/{lang}",
        "pathAnilist": "/stream/ani/{anilistId}/{ep}/{lang}",
        "scrapeReferer": "https://www.enma.lol/"
      },
      "miruroOrigins": [
        "https://www.miruro.tv",
        "https://www.miruro.to",
        "https://www.miruro.bz",
        "https://www.miruro.ru"
      ]
    },
    "cdnRefererRules": [
      {
        "hostContains": ["mewstream", "nekostream", "lostproject", "megaplay"],
        "referer": "https://megaplay.buzz/",
        "origin": "https://megaplay.buzz"
      },
      {
        "hostContains": ["watching.onl", "vidwish"],
        "referer": "https://vidwish.live/",
        "origin": "https://vidwish.live"
      },
      {
        "hostContains": ["fast4speed"],
        "referer": "https://allmanga.to/",
        "origin": "https://allmanga.to"
      }
    ]
  }'::jsonb
)
on conflict (id) do nothing;
