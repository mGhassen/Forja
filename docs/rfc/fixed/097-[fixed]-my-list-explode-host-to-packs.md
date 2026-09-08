# RFC-097: Explode My List host — packs own MetaRuntime feed

**Status:** fixed  
**Depends on:** [RFC-088](088-[fixed]-my-list-pack-only.md) · [RFC-091](091-[fixed]-live-sports-explode-host-to-packs.md) · [RFC-085](../085-[partial]-catalog-kit-generic-only.md)  
**Area:** `plugins/hubs/my_list`, `shared/foundation/services/follow/`, engine runtime bridge, kit list registry

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** components · **10 / 10** acceptance |
| **Current slice** | **Complete** — pack MetaRuntime feed + `ctx.host.myList.load`; thin kit adapter |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R97-C01 | Engine bridge `ctx.host.myList.load` + aggregate | ✅ |
| 2 | R97-C02 | Hub pack MetaRuntime `feed`/`rail` (not layout-only) | ✅ |
| 3 | R97-C03 | Thin `my_list` KitListSource via MetaRuntime | ✅ |
| 4 | R97-C04 | Feature doc + host tests (synthetic) | ✅ |

---

## Acceptance (slice A — engine bridge)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R97-A01 | `ctx.host.myList.load({ status })` returns merged local (+ Simkl) row maps | ✅ |
| 2 | R97-A02 | Hub `feed`/`rail` forces flutter_js when `needsMyListHost` (EngineJS has no bridge) | ✅ |

---

## Acceptance (slice B — pack feed)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 3 | R97-A03 | Hub pack exposes `feed`/`rail`; missing bridge rejects `HOST_MY_LIST_REQUIRED` | ✅ |
| 4 | R97-A04 | Pack shapes rows (`open`, kind/`type`, name) like Live Sports schedule shape | ✅ |

---

## Acceptance (slice C — thin kit source)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 5 | R97-A05 | `source: my_list` is thin MetaRuntime adapter (no Riverpod merge god in KitListSource) | ✅ |
| 6 | R97-A06 | Open + status-pin widgets still wired on the thin source | ✅ |
| 7 | R97-A07 | Status-pin / revision updates keep prior grid (no full skeleton flash) | ✅ |

---

## Acceptance (slice D — docs / tests)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 8 | R97-A08 | Feature doc: pack owns feed; host owns persist/Simkl behind bridge | ✅ |
| 9 | R97-A09 | Host unit tests for aggregate/shape helpers use synthetic fixtures only | ✅ |
| 10 | R97-A10 | Changelog only if user-visible UX changes | ✅ |

---

## Summary

RFC-088 made My List pack-only for chrome (layout/nav) while list data stayed in a fat host `MyListCatalogSource`. Live Sports leapfrogged that with RFC-091 (pack `feed` → `ctx.host.liveFeed.load`). This RFC does the same explode for My List: pack owns MetaRuntime composition; Dart keeps persist, Simkl OAuth, and pin/open adapters behind `ctx.host.myList`.

### Related

- [RFC-088](088-[fixed]-my-list-pack-only.md) — pack-only tab chrome
- [RFC-091](091-[fixed]-live-sports-explode-host-to-packs.md) — Live Sports explode pattern
- [RFC-070](../070-[partial]-catalog-hub-protocol.md) — catalog hub protocol
