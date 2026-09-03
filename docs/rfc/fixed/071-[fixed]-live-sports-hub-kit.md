# RFC-071: Live Sports catalog hub kit

**Status:** fixed  
**Depends on:** [RFC-070](../070-[partial]-catalog-hub-protocol.md) · [RFC-065](../065-[open]-live-forja-scrapers.md) · [RFC-062](../062-[open]-native-iptv-sports-matching.md)  
**Area:** `shared/catalog/kit/sources/live_schedule/`, `plugins/hubs/live_sports/`, `CatalogShell`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · 9/9 components · 21/21 acceptance |
| **Current slice** | Generic kit — `kit.list` + `source: live_schedule`; domain under `sources/live_schedule/` |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R71-C01 | `kit.live.*` layout types + protocol live meta fields | ✅ |
| 2 | R71-C02 | `shared/catalog/kit/live/` chrome / body / data / play modules | ✅ |
| 3 | R71-C03 | `LiveModeRegistry` + `LiveScheduleSource` (Forja Live / Forja Sports / Stremio) | ✅ |
| 4 | R71-C04 | `plugins/hubs/live_sports/` pack (`nav` + `layout`) | ✅ |
| 5 | R71-C05 | `CatalogShell` wiring + nav migration off `coreShellNavIds` | ✅ |
| 6 | R71-C06 | `open.surface: live` + LivePlayKit; retire `features/live_matches/` | ✅ |
| 7 | R71-C07 | Domain under `kit/sources/live_schedule/` (not product-named kit types) | ✅ |
| 8 | R71-C08 | Pack layout uses only generic `kit.stack` / `kit.menu` / `kit.list` | ✅ |
| 9 | R71-C09 | Remove `kit.live.*` from `CatalogKitTypes` + CatalogShell | ✅ |

---

## Acceptance (parity gates)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R71-A01 | All 10 `kit.live.*` layout types render from pack layout | ✅ |
| 2 | R71-A02 | Mode menu: enabled modes only; pref migrates `server_v1` → `mode_v1`; shared-schedule mode switch skips reload | ✅ |
| 3 | R71-A03 | Catalog sheet: All + per plugin, lazy load, session cache, per-plugin loading/error in sheet | ✅ |
| 4 | R71-A04 | Schedule sheet: status + horizon; dynamic chip label; widen refetches, narrow filters | ✅ |
| 5 | R71-A05 | Grid: streamed/PPV/merged cards, badges, live-only tap, viewer sum, catalog progress bar | ✅ |
| 6 | R71-A06 | Timeline: Day/12h/6h/3h, NOW line, jump-to-now, hover lift, bucket cap, minute LIVE tick | ✅ |
| 7 | R71-A07 | TV: cards only, full D-pad graph, focus restore, empty → Refresh autofocus | ✅ |
| 8 | R71-A08 | Forja Live play: parallel resolve, progress copy, engine/sniff setting, embed chrome, proxy | ✅ |
| 9 | R71-A09 | Forja Sports: portal stack, channel panel phases, alive-check, Stalker create_link, 30m cache | ✅ |
| 10 | R71-A10 | Stremio play: addon catalogs, premium skip, HLS + headers on ATV, multi-source TV fill | ✅ |
| 11 | R71-A11 | Shell lifecycle: tab hide cancel, pack-change dirty reload, gen-counter cancel, ShellTabRefresh | ✅ |
| 12 | R71-A12 | Phone sheets vs desktop/TV panel split; merged stream sheet; HD/viewer row chrome | ✅ |
| 13 | R71-A13 | All toasts/error paths; engine fail never silent-fallback to embed | ✅ |
| 14 | R71-A14 | Host live tests pass from kit import paths; Rust IPTV parity test unchanged | ✅ |
| 15 | R71-A15 | Cross-imports: goat unlock, settings, BootNeeds, ShellNavPages, registry slot, `.env.example` | ✅ |
| 16 | R71-A16 | `features/live_matches/` deleted; feature doc + changelog + RFC-070 pack count updated | ✅ |

---

## Acceptance (generic kit restructure)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R71-A17 | No `kit.live.*` types in host `CatalogKitTypes` / CatalogShell | ✅ |
| 2 | R71-A18 | Live domain lives under `kit/sources/live_schedule/` (My List pattern) | ✅ |
| 3 | R71-A19 | Pack layout = `kit.stack` + `kit.list { source: live_schedule }` (+ optional `kit.menu`) | ✅ |
| 4 | R71-A20 | CatalogShell mounts live host when layout has `kit.list` + `source: live_schedule` | ✅ |
| 5 | R71-A21 | Host tests assert generic layout + source id — not `kit.live.*` contracts | ✅ |

---

## Summary

Replace the hardcoded Live Matches feature screen with a **plugin-contributed catalog hub**.

**v1 (frozen):** pack nav + host-owned browse/play; briefly used product-named `kit.live.*` slots (wrong — feature dump under kit path).

**Current slice:** kit stays **generic composition** (`stack` / `menu` / `tabs` / `list`). Live Sports is a **list source** (`live_schedule`), same shape as My List (`source: my_list`). Host chrome/play stay in `sources/live_schedule/`, not as kit type vocabulary.

### Modes (retired — see RFC-073)

RFC-071 shipped host-owned browse modes. Product moved resolve choice to match **Providers** / **Live TV**. Mode registry removed in [RFC-073](../073-[open]-live-sports-kit-ownership.md).

### Related

- [RFC-065](../065-[open]-live-forja-scrapers.md) — live_sport plugins
- [RFC-070](../070-[partial]-catalog-hub-protocol.md) — catalog hub protocol
- [live-matches feature doc](../../features/live/live-matches.md)
