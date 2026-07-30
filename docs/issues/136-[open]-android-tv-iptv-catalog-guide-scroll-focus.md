# 136 — Android TV IPTV catalog / channel-guide scroll focus + logo density

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · IPTV catalog · in-player channel guide

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I136-T01 | TV `FocusableControl.ensureVisible`: instant jump + keepVisible (no 200ms tween clipping focus) | ✅ |
| 2 | I136-T02 | In-player channel guide: denser rows, square logos (`cacheWidth` only), edge-margin jump scroll | ✅ |
| 3 | I136-T03 | IPTV catalog category/channel lists: denser list tiles, zero focus anim on TV, fixed `itemExtent` | ✅ |
| 4 | I136-T04 | Feature docs + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I136-A01 | Android TV: ↑/↓ in IPTV category + channel (catalog) keeps focus chrome fully visible — no missing highlight while scrolling | ⬜ |
| 2 | I136-A02 | Android TV: in-player channel guide groups/channels same; logos not stretched; rows feel denser | ⬜ |
| 3 | I136-A03 | Android TV: hold ↑/↓ through long category/channel lists — scroll stays snappy (no obvious hitch per step) | ⬜ |

---

## Summary

D-pad focus on IPTV **catalog** (category rail + channel grid/list) and **in-player channel guide** felt cropped because focus scrolled with a **200ms** `ensureVisible` tween (highlight off-screen mid-animation). Channel logos looked deformed when decode used both `cacheWidth` and `cacheHeight`. Rows were oversized; list rebuilds fought animated containers.

**Root fix:** Instant keepVisible scroll on TV; guide/catalog denser layout; logos decode with `cacheWidth` only + `BoxFit.contain`.

## Related

- [RFC-027](../rfc/027-[draft]-iptv-channel-guide.md) — in-player guide
- [135](135-[open]-android-tv-spatial-dpad-all-screens.md) — spatial D-pad (separate)
