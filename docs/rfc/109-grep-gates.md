# Pack-product host grep gates

**RFC:** [109](../rfc/109-[open]-forja-pack-product-host.md) · **Rule:** [forja-pack-product-host.mdc](../../.cursor/rules/forja-pack-product-host.mdc)

Pre-merge / CI checklist for `apps/forja/lib`:

| Gate | Must be absent |
|------|----------------|
| Product engine dirs | `shared/engine/hub/`, `lists/`, `live/`, `feeds/`, `portals/` |
| IPTV product trees | `features/iptv/`, `shared/host/portals_ui/` |
| Catalog-meta cache | class / file `MetaCache` |
| Live product boot | `KitLiveBoot`, `MatchEvent`, `aggregateLiveFeed` |
| Product host bridges | `liveFeed` / `h.feed` / product `iptv` / `portals` in `ctx.host` |
| Shell product widgets | `kit_` under `shared/shell/`; no `shell/layout/` |
| Host layout private | `shared/host/layout/private/` |
| Host catalog dump | `shared/host/catalog/` |
| IPTV core nav | `'iptv'` in `coreNavDestinations` / `coreNavTabBuilders` |

```bash
# From repo root — expect clean after RFC-109 finish pass
rg -n 'MetaCache|KitLiveBoot|liveFeed|aggregateLiveFeed|MatchEvent|class IptvPortal' apps/forja/lib || true
rg -n 'kit_' apps/forja/lib/shared/shell || true
rg -n 'host/layout/private|host/catalog' apps/forja || true
test ! -d apps/forja/lib/shared/engine/hub
test ! -d apps/forja/lib/shared/engine/lists
test ! -d apps/forja/lib/shared/engine/live
test ! -d apps/forja/lib/shared/engine/feeds
test ! -d apps/forja/lib/shared/engine/portals
test ! -d apps/forja/lib/features/iptv
test ! -d apps/forja/lib/shared/host/portals_ui
test ! -d apps/forja/lib/shared/shell/layout
test ! -d apps/forja/lib/shared/host/layout/private
test ! -d apps/forja/lib/shared/host/catalog
```
