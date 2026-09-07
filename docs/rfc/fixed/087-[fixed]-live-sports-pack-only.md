# RFC-087: Live Sports pack-only (no host feature root)

**Status:** fixed  
**Depends on:** [RFC-073](073-[fixed]-live-sports-kit-ownership.md) · [RFC-081](081-[fixed]-host-only-platform-nav-defaults.md) · [RFC-086](086-[fixed]-addons-packs-feature-vs-navbar.md)  
**Area:** `plugins/hubs/live_sports*`, `shared/foundation/services/live/`, shell nav

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **8 / 8** acceptance |
| **Current slice** | **Complete** — pack-only Live Sports |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R87-C01 | Delete host product root `features/live_sports/` (layout + core tab builder) | ✅ |
| 2 | R87-C02 | Move schedule/prefs/panel/details registration into `shared/foundation/services/live/` | ✅ |
| 3 | R87-C03 | Remove `live_matches` from `coreShellNavIds` + core destinations/builders | ✅ |
| 4 | R87-C04 | Hub pack(s) sole owners of Live Sports tab chrome (`nav` + `layout`) | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R87-A01 | No `features/live_sports/` tree; no `liveSportsCoreTabBuilder` / `kLiveSportsHostDefaultLayout` | ✅ |
| 2 | R87-A02 | `live_matches` not in `PluginNavRegistry.coreShellNavIds` | ✅ |
| 3 | R87-A03 | Addons Live Sports ON with no hub pack → no Live Sports navbar tab | ✅ |
| 4 | R87-A04 | Enabled `live-sports-hub` (or Cards) pack → KitShell tab from pack layout only | ✅ |
| 5 | R87-A05 | Opaque `live_schedule` list source + streams panel still register on host foundation | ✅ |
| 6 | R87-A06 | Addons Live Sports still gates catalog/settings capability (not host chrome) | ✅ |
| 7 | R87-A07 | Feature doc + changelog describe pack-only Live Sports | ✅ |
| 8 | R87-A08 | RFC-084 canceled; issue 220 closed as superseded | ✅ |

---

## Summary

**Product rule:** Live Sports is **only a plugin**. Host may keep generic schedule/stream **services** under foundation. There is no host feature product root and no core-shell tab without a hub pack.

| Layer | Owns |
|-------|------|
| `plugins/hubs/live_sports*` | Tab `nav` + `layout` (list+panel and/or cards) |
| `plugins/live/**` | Catalog scrape + stream resolve |
| `shared/foundation/services/live/` | Opaque `live_schedule`, MatchStreams, IPTV sports match, prefs/filters, panel host |
| Host shell | IPTV + Settings only as core — **not** `live_matches` |

Supersedes [RFC-084](../canceled/084-[canceled]-live-sports-host-feature-kit.md) (host core tab + default layout).

### Related

- [RFC-073](073-[fixed]-live-sports-kit-ownership.md) — kit + host services (frozen); product ownership corrected here
- [Issue 220](../../issues/canceled/220-[canceled]-live-sports-addon-nav-without-hub-pack.md) — canceled (wrong fix: host core tab)
- [live-matches feature](../../features/live/live-matches.md)
