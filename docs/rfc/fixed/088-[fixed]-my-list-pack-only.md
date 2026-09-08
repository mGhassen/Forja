# RFC-088: My List pack-only (no host feature root)

**Status:** fixed  
**Depends on:** [RFC-070](../070-[partial]-catalog-hub-protocol.md) · [RFC-085](../085-[partial]-catalog-kit-generic-only.md) · [RFC-087](087-[fixed]-live-sports-pack-only.md)  
**Area:** `plugins/hubs/my_list/`, `shared/foundation/services/follow/`, shell nav

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** components · **5 / 5** acceptance |
| **Current slice** | **Complete** — pack-only My List (peer of RFC-087) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R88-C01 | Delete host product root `features/my_list/` | ✅ |
| 2 | R88-C02 | Move catalog source / merge / open / registration into `shared/foundation/services/follow/` | ✅ |
| 3 | R88-C03 | Hub pack sole owner of My List tab chrome (`nav` + `layout`) — already true; keep | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R88-A01 | No `features/my_list/` tree | ✅ |
| 2 | R88-A02 | `mylist` not in `PluginNavRegistry.coreShellNavIds` (unchanged) | ✅ |
| 3 | R88-A03 | Opaque `my_list` list source registers on foundation at boot | ✅ |
| 4 | R88-A04 | Feature doc describes pack-only My List | ✅ |
| 5 | R88-A05 | Changelog notes host folder evacuated (no user-visible behavior change) | ✅ |

---

## Summary

**Product rule:** My List is **only a plugin** (same as Live Sports / RFC-087). Host keeps list/follow **services** under foundation. No host feature product root.

| Layer | Owns |
|-------|------|
| `plugins/hubs/my_list` | Tab `nav` + `layout` |
| `shared/foundation/services/follow/` | `MyListService` bridge, merge, enrich, kit list source, open |
| Host shell | No `mylist` core destination |

Tab was already pack-gated ([R70-A60](../070-[partial]-catalog-hub-protocol.md)). This RFC only evacuates `features/my_list/` into foundation. [R85-C03](../085-[partial]-catalog-kit-generic-only.md) stays frozen ✅ as historical “domain home”; ownership is corrected here.

### Related

- [RFC-097](097-[fixed]-my-list-explode-host-to-packs.md) — pack MetaRuntime feed (peer of Live Sports RFC-091)
- [RFC-087](087-[fixed]-live-sports-pack-only.md) — Live Sports pack-only peer
- [my-list feature](../../features/movies-tv/my-list.md)
