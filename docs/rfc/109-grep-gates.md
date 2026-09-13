# Pack-product host grep gates

**RFC:** [109](../rfc/109-[open]-forja-pack-product-host.md) · **Rule:** [forja-pack-product-host.mdc](../../.cursor/rules/forja-pack-product-host.mdc)

Pre-merge / CI checklist for `apps/forja/lib`:

| Gate | Must be absent |
|------|----------------|
| Product engine dirs | `shared/engine/hub/`, `shared/engine/lists/`, `shared/engine/live/` |
| IPTV product tree | `features/iptv/` |
| Catalog-meta cache | class / file `MetaCache` |
| Live product boot | `KitLiveBoot` |
| Product host bridges | `liveFeed` in `ctx.host` injection |
| Shell catalog widgets | `kit_` under `shared/shell/` |
| IPTV core nav | `'iptv'` in `coreNavDestinations` / `coreNavTabBuilders` |

```bash
# From repo root — expect no matches after RFC-109 code waves land
rg -n 'MetaCache|KitLiveBoot|liveFeed' apps/forja/lib || true
rg -n 'kit_' apps/forja/lib/shared/shell || true
test ! -d apps/forja/lib/shared/engine/hub
test ! -d apps/forja/lib/shared/engine/lists
test ! -d apps/forja/lib/shared/engine/live
test ! -d apps/forja/lib/features/iptv
```
