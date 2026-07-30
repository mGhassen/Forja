# 135 — Android TV spatial 2D D-pad (all screens)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · shell tabs · settings · overlays · player · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **1 / 8** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I135-T01 | Core: linear next/prev only inside opt-in `ShellTvLinearFocusScope`; default arrows use focused-node `focusInDirection` (`FocusableControl` / `ForjaInteractive` / `ForjaButton`) | ✅ |
| 2 | I135-T02 | Strip default linear hosts — `TvOverlayScope`, settings detail/compact panes, settings category page; keep `FocusScope` + `ShellTvContainDpad` traps | ✅ |
| 3 | I135-T03 | Shell chrome audit — nav / hero / top bar / search / mood / Live Matches use `ReadingOrderTraversalPolicy` for spatial `inDirection` | ✅ |
| 4 | I135-T04 | Player chrome + menus same spatial rule (seek scrub ←/→ exception unchanged) | ✅ |
| 5 | I135-T05 | Widget tests: spatial 2×2 overlay ↓; chrome Play→Rewind / ↑ seek still pass | ✅ |
| 6 | I135-T06 | Feature docs + changelog: TV D-pad is spatial nearest-neighbor app-wide | ✅ |
| 7 | I135-T07 | IPTV portal row: `allowNestedFocus` so **→** reaches favorite → copy → edit → delete | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I135-A01 | Home / Anime / Asian Drama: ↑/↓/←/→ move to on-screen neighbors (catalog coordinator rows/grids); not a single next/prev line across the page | ⬜ |
| 2 | I135-A02 | Search / Lists / Live Matches / IPTV catalog: same spatial rule for chrome + grids | ⬜ |
| 3 | I135-A03 | Settings detail: ←/→/↑/↓ move among detail controls by layout; Back (not ←) returns to category rail | ⬜ |
| 4 | I135-A04 | Player overlays (Sources / Audio / Subs / Settings): spatial inside panel; Back dismisses; no leak to chrome | ⬜ |
| 5 | I135-A05 | Exo / film / IPTV chrome: band ↑/↓ and neighbor ←/→ (seek scrub exception) | ⬜ |
| 6 | I135-A06 | Profile chooser: spatial D-pad among profiles / actions | ⬜ |
| 7 | I135-A07 | Media details: action rows / cast / trailers move spatially / via recipes, not linear next/prev | ⬜ |
| 8 | I135-A08 | Widget test: 2×2 focusables under `TvOverlayScope` — ↓ from top-left reaches bottom-left | ✅ |

---

## Summary

Recent TV focus work made many surfaces feel like a **1D line** (`↑/←` = previous, `↓/→` = next via `ShellTvLinearFocusScope` / `shellTvLinearMenuArrows`). Catalog rows already use the coordinator (screen-space shelves). Everything else — settings, overlays, profile chooser, non-meta chrome — now defaults to **nearest-neighbor `focusInDirection`**.

**Root fix:** Spatial is the default; linear scope becomes rare opt-in (`TvOverlayScope(linear: true)`). Keep `FocusScope` + `ShellTvContainDpad` traps (settings detail, overlays) so Left does not auto-jump to nav; keep catalog coordinator + seek scrub exceptions.

## Related

- [RFC-048](../rfc/fixed/048-[fixed]-tv-focus-graph.md) — spatial-default slice (`R48-C07`, `R48-A19+`)
- [127](127-[open]-android-tv-settings-detail-dpad.md) — detail pane Back ladder (keep; drop linear arrows)
- [130](130-[open]-android-tv-player-dpad-stuck-on-play.md) — focused-node `focusInDirection`
- [025](025-[open]-android-tv-leanback-smoke-unverified.md) — leanback smoke gate
