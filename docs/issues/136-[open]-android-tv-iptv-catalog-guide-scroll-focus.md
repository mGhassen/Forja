# 136 — Android TV IPTV catalog / channel-guide scroll focus + logo density

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · IPTV catalog · in-player channel guide

## Status at a glance

| | |
|--|--|
| **Progress** | **9 / 9** fix · **0 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I136-T01 | TV `FocusableControl.ensureVisible`: instant jump + keepVisible (no 200ms tween clipping focus) | ✅ |
| 2 | I136-T02 | In-player channel guide: denser rows, square logos (`cacheWidth` only), edge-margin jump scroll | ✅ |
| 3 | I136-T03 | IPTV catalog category/channel lists: denser list tiles, zero focus anim on TV, fixed `itemExtent` | ✅ |
| 4 | I136-T04 | Feature docs + changelog | ✅ |
| 5 | I136-T05 | Category rail: `SliverFixedExtentList` / reorderable `itemExtent` + scroll cache; skip pending-commit rebuild on ↑/↓; `ensureVisibleMode.item` | ✅ |
| 6 | I136-T06 | TV floating category reorder: HardwareKeyboard lock + id-based ↑/↓ (no HoldAccel); pin scroll at 2nd row; ExcludeFocus channels | ✅ |
| 7 | I136-T07 | TV category pin: sync → focus (trap → / KeyRepeat); freeze rail scroll on OK pin | ✅ |
| 8 | I136-T08 | In-player channel guide (TV): defer channel logos until 350ms after scroll settle | ✅ |
| 9 | I136-T09 | IPTV catalog channel grid/list (TV): same 350ms logo + EPG deferral; `cacheWidth` on thumbs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I136-A01 | Android TV: ↑/↓ in IPTV category + channel (catalog) keeps focus chrome fully visible — no missing highlight while scrolling | ⬜ |
| 2 | I136-A02 | Android TV: in-player channel guide groups/channels same; logos not stretched; rows feel denser | ⬜ |
| 3 | I136-A03 | Android TV: hold ↑/↓ through long category/channel lists — scroll stays snappy (no obvious hitch per step); category left-bar lines stay aligned when holding ↑ | ⬜ |
| 4 | I136-A04 | Android TV: hold OK to float — ↑/↓ one step; no scroll until 2nd visible slot, then pin there until ends; focus stays on float | ⬜ |
| 5 | I136-A05 | Android TV: → on a Live group focuses pin on first press; OK on pin does not jump category rail scroll | ⬜ |

---

## Summary

D-pad focus on IPTV **catalog** (category rail + channel grid/list) and **in-player channel guide** felt cropped because focus scrolled with a **200ms** `ensureVisible` tween (highlight off-screen mid-animation). Channel logos looked deformed when decode used both `cacheWidth` and `cacheHeight`. Rows were oversized; list rebuilds fought animated containers.

**Root fix:** Instant keepVisible scroll on TV; guide/catalog denser layout; logos decode with `cacheWidth` only + `BoxFit.contain`.

**Follow-up (I136-T05):** Category sidebar still used `SliverList` without fixed extents (channels/portals already had `itemExtent`). Fast ↑ corrected estimated heights → green left-bar / rows jumped. Now `SliverFixedExtentList` + reorderable `itemExtent`, scroll cache, and no full-browser `setState` while D-pad walks unopened groups.

**Follow-up (I136-T06):** TV floating reorder lost primary focus on each ↑/↓ rebuild → KeyRepeat hit spatial/HoldAccel (stride 3) and channels. Parent `HardwareKeyboard` owns the session; moves by category id; rail scrolls only after the floating row reaches the 2nd visible slot (then pins there until ends); channel pane `ExcludeFocus` while floating.

**Follow-up (I136-T07):** → to pin used post-frame focus while KeyRepeat still on the row/pin leaked spatial → into channels (right-left-right). Pin always mounted on TV + sync focus + trap →; OK pin freezes rail scroll (pinned row still moves to front of movable list).

**Follow-up (I136-T08):** Holding ↑/↓ in the in-player channel list decoded every logo mid-scroll. On TV, channel-row `Image.network` stays off until **350ms** after the last scroll settle (placeholders meanwhile); header “Now playing” logo unchanged.

**Follow-up (I136-T09):** Catalog channel grid/list had the same decode thrash. Same 350ms settle gate; live EPG “NOW” footers stay off while scrolling; thumbs decode with `cacheWidth` only.

## Related

- [RFC-027](../rfc/027-[draft]-iptv-channel-guide.md) — in-player guide
- [135](135-[open]-android-tv-spatial-dpad-all-screens.md) — spatial D-pad (separate)
