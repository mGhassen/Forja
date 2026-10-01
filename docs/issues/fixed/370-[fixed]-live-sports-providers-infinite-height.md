# 370 — Live Sports Providers infinite height (streams look broken)

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Live Sports · Sources tiles · Providers panel  
**Reported:** 2026-09-24

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I370-T01 | Restore Stack + Positioned probe bar on source tiles (no `Row(stretch)` in ListView) | ✅ |
| 2 | I370-T02 | Widget test: `SourcesPanelChannelTile` inside `ListView` lays out without exception | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I370-A01 | Open a Live Sports match → Providers fills as resolves return — no `BoxConstraints forces an infinite height` | ⬜ |
| 2 | I370-A02 | VOD Sources torrent/webstreaming tiles still show hover download / copy-magnet rail | ⬜ |

---

## Summary

Resolve was fine (`raw=1` / `2` / `3` on PPV / Streamed / WatchFooty). Painting stream rows crashed: PackGreenPlay / Downloads tile refactor used `Row(crossAxisAlignment: stretch)` for the probe bar. ListView children get unbounded max height → stretch → infinite height → `child.hasSize` / null-check cascade. Looks like “resolve failed.”

**Root fix:** Stack + Positioned probe bar again (same pattern as issue 352 — avoid IntrinsicHeight). Columns use `mainAxisSize: min`.
