# Pack-product host grep gates

**RFC:** [109](../rfc/109-[open]-forja-pack-product-host.md) · **Rule:** [forja-pack-product-host.mdc](../../.cursor/rules/forja-pack-product-host.mdc) · skill [forja-pack-product-host](../../.cursor/skills/forja-pack-product-host/SKILL.md)

Pre-merge / CI checklist for `apps/forja/lib`:

| Gate | Must be absent |
|------|----------------|
| Product engine dirs | `shared/engine/hub/`, `lists/`, `live/`, `feeds/`, `portals/` |
| IPTV product trees | `features/iptv/`, `shared/host/portals_ui/` |
| Catalog-meta cache | class / file `MetaCache` |
| Live product boot | `KitLiveBoot`, `MatchEvent`, `aggregateLiveFeed` |
| Product host bridges | `liveFeed` / `h.feed` / product `iptv` / `portals` in `ctx.host` |
| Shell product widgets | `kit_` under `lib/shell/` (except frame composers); no `shell/layout/` |
| Host layout parking | `shared/host/layout/` (entire tree) |
| Foundation layout orchestrators | `packages/forja_foundation/lib/layout/` |
| Kit product parking | `KitListPaint`, `PluginFeedSource`, `live_schedule_feed`, `HostListRegistry`, `pack_layout_host_wire` |
| Host catalog dump | `shared/host/catalog/` |
| IPTV core nav | `'iptv'` in `coreNavDestinations` / `coreNavTabBuilders` |

```bash
# From repo root — expect clean after RFC-109 finish pass
rg -n 'MetaCache|KitLiveBoot|liveFeed|aggregateLiveFeed|MatchEvent|class IptvPortal' apps/forja/lib || true
rg -n 'kit_' apps/forja/lib/shell --glob '!**/chrome/**' || true
rg -n 'host/layout|host/catalog' apps/forja/lib || true
rg -n 'KitListPaint|PluginFeedSource|HostListRegistry|live_schedule_feed|pack_layout_host_wire' apps/forja/lib || true
test ! -d apps/forja/lib/shared/engine/hub
test ! -d apps/forja/lib/shared/engine/lists
test ! -d apps/forja/lib/shared/engine/live
test ! -d apps/forja/lib/shared/engine/feeds
test ! -d apps/forja/lib/features/iptv
test ! -d apps/forja/lib/shared/host/portals_ui
test ! -d apps/forja/lib/shared/shell
test ! -d apps/forja/lib/shell/layout
test ! -d apps/forja/lib/shared/host/layout
test ! -d apps/forja/lib/shared/host/catalog
test ! -d packages/forja_foundation/lib/layout
test ! -f apps/forja/lib/shared/engine/runtime/kit/pack_layout_host_wire.dart
test ! -f apps/forja/lib/shared/engine/runtime/kit/live_schedule_feed.dart
```
