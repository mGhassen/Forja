# Forja RFC Index

Design docs for Forja. Topic RFCs (001–010) define **what**; version RFCs (011–014) define **when**.

## Version roadmap

| Version | Release RFC | Ship target | Summary |
|---------|-------------|-------------|---------|
| **v1.0** | [RFC-011](011-v1.0-mvp.md) | macOS (+ mobile parity) | Feature-first app, 19 nav tabs, engines, unified player, IPTV, Stremio, provider registry |
| **v1.1** | [RFC-012](012-v1.1-casting-providers.md) | + iOS/Android casting | AirPlay, Chromecast, expanded providers, player overlay wired |
| **v1.2** | [RFC-013](013-v1.2-sync-lan-party.md) | + cloud optional | Supabase settings sync, LAN companion, watch party |
| **v3.0** | [RFC-014](014-v3-web-rust.md) | Browser | Web client (HLS-only), Rust/WASM core |

## Topic RFCs

| RFC | Topic | Primary version | Status |
|-----|-------|-----------------|--------|
| [001](001-monorepo.md) | Monorepo + feature boundaries | v1.0 | **Shipped** (feature-first) |
| [002](002-iptv-groups.md) | IPTV portal groups | v1.0 | **Shipped** |
| [003](003-player-overlay.md) | Player overlay + server grid | v1.1 | Stub UI, not wired |
| [004](004-provider-registry.md) | Stream provider registry | v1.0 core / v1.1 expand | **Partial** (registry exists) |
| [005](005-casting.md) | AirPlay + Chromecast | v1.1 | Stub only |
| [006](006-supabase-sync.md) | Settings sync | v1.2 | Stub only |
| [007](007-lan-companion.md) | LAN remote API | v1.2 | Not started |
| [008](008-watch-party.md) | Watch party sync | v1.2+ | Placeholder button |
| [009](009-rust-ffi.md) | Rust core FFI | v3.0 | Not started |
| [010](010-web-client.md) | Web client | v3.0 | Not started |
| [015](015-in-app-updates.md) | In-app update system | v1.0 partial / v1.1 | **Partial** |

## Dependency graph

```
v1.0 (011) ──► v1.1 (012) ──► v1.2 (013) ──► v3.0 (014)
     │              │              │
  RFC-001       RFC-003        RFC-006
  RFC-002       RFC-004        RFC-007
  RFC-004       RFC-005        RFC-008
  RFC-015 (updates)
```

## Conventions

- **Shipped** — in production code path today
- **Partial** — engine or UI exists but not fully integrated
- **Stub** — scaffold under `apps/forja/lib/shared/` with no feature wiring
- **Not started** — spec only
