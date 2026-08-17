# 136 — Android TV IPTV catalog / channel-guide scroll focus + logo density

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · IPTV catalog · in-player channel guide

## Status at a glance

| | |
|--|--|
| **Progress** | **16 / 16** fix · **0 / 7** acceptance · **1** deferred (A05) |

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
| 10 | I136-T10 | In-player channel guide (TV): load logos only after D-pad idle **500ms** (not scroll-only) | ✅ |
| 11 | I136-T11 | IPTV catalog (TV): same D-pad idle **500ms** logo gate on stream focus | ✅ |
| 12 | I136-T12 | TV catalog + guide: keep already-shown logos on scroll; only defer *new* viewport tiles (mid-viewport ↑/↓ never flashes) | ✅ |
| 13 | I136-T13 | Clear channel-pane ExcludeFocus when HW drops float (stuck `_tvCategoryPinFocused` blocked OK/→ into channels) | ✅ |
| 14 | I136-T14 | TV category pin: after pin/unpin, scroll rail to new index + focus that row (supersedes freeze-scroll of T07) | ✅ |
| 15 | I136-T15 | TV category rail: sync-clear focus chrome on blur; selected-only = left bar (no second inkHover fill) | ✅ |
| 16 | I136-T16 | Channel grid last-row ↓ traps (no spatial wrap back to category rail); `moveInGrid` last-row down returns handled | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I136-A01 | Android TV: ↑/↓ in IPTV category + channel (catalog) keeps focus chrome fully visible — no missing highlight while scrolling | ⬜ |
| 2 | I136-A02 | Android TV: in-player channel guide groups/channels same; logos not stretched; rows feel denser | ⬜ |
| 3 | I136-A03 | Android TV: hold ↑/↓ through long category/channel lists — scroll stays snappy (no obvious hitch per step); category left-bar lines stay aligned when holding ↑ | ⬜ |
| 4 | I136-A04 | Android TV: hold OK to float — ↑/↓ one step; no scroll until 2nd visible slot, then pin there until ends; focus stays on float | ⬜ |
| 5 | I136-A05 | Android TV: → on a Live group focuses pin on first press; OK on pin does not jump category rail scroll | ⏭️ |
| 6 | I136-A06 | Android TV: OK on pin focuses the pinned/unpinned group and scrolls the category rail to its new index | ⬜ |
| 7 | I136-A07 | Android TV: ↑/↓ through catalog categories shows only one hover fill at a time (no ghost previous row + selected inkHover) | ⬜ |
| 8 | I136-A08 | Android TV: ↓ on the last channel row stays on that row — does not wrap to the category list | ⬜ |

---

## Summary

D-pad focus on IPTV **catalog** (category rail + channel grid/list) and **in-player channel guide** felt cropped because focus scrolled with a **200ms** `ensureVisible` tween (highlight off-screen mid-animation). Channel logos looked deformed when decode used both `cacheWidth` and `cacheHeight`. Rows were oversized; list rebuilds fought animated containers.

**Root fix:** Instant keepVisible scroll on TV; guide/catalog denser layout; logos decode with `cacheWidth` only + `BoxFit.contain`.

**Follow-up (I136-T05):** Category sidebar still used `SliverList` without fixed extents (channels/portals already had `itemExtent`). Fast ↑ corrected estimated heights → green left-bar / rows jumped. Now `SliverFixedExtentList` + reorderable `itemExtent`, scroll cache, and no full-browser `setState` while D-pad walks unopened groups.

**Follow-up (I136-T06):** TV floating reorder lost primary focus on each ↑/↓ rebuild → KeyRepeat hit spatial/HoldAccel (stride 3) and channels. Parent `HardwareKeyboard` owns the session; moves by category id; rail scrolls only after the floating row reaches the 2nd visible slot (then pins there until ends); channel pane `ExcludeFocus` while floating.

**Follow-up (I136-T07):** → to pin used post-frame focus while KeyRepeat still on the row/pin leaked spatial → into channels (right-left-right). Pin always mounted on TV + sync focus + trap →; OK pin freezes rail scroll (pinned row still moves to front of movable list).

**Follow-up (I136-T08):** Holding ↑/↓ in the in-player channel list decoded every logo mid-scroll. On TV, channel-row `Image.network` stays off until **350ms** after the last scroll settle (placeholders meanwhile); header “Now playing” logo unchanged.

**Follow-up (I136-T09):** Catalog channel grid/list had the same decode thrash. Same 350ms settle gate; live EPG “NOW” footers stay off while scrolling; thumbs decode with `cacheWidth` only.

**Follow-up (I136-T10 / T11):** Scroll-only settle missed mid-viewport ↑/↓ (no jump). Logos now stay off until D-pad focus is idle **500ms** in the in-player guide and catalog stream grid/list.

**Follow-up (I136-T12):** T10/T11 hid *all* logos on every focus/scroll. Now each revealed channel id stays painted; scroll/group swap only stops *new* tiles from decoding until **500ms** idle. Mid-viewport ↑/↓ never flashes.

**Follow-up (I136-T13):** Enter float set `_tvCategoryPinFocused` (ExcludeFocus channels); HW OK/← cleared float without clearing that flag — OK/→ after pin/reorder stayed on the category rail. Clear the flag when float drops (and on row dispose).

**Follow-up (I136-T14):** T07 froze rail scroll on pin so the old viewport slot kept focus while the row jumped to the top of the movable list — focus looked lost. Pin/unpin now scrolls to the row’s new index and focuses it (`I136-A06`; `I136-A05` freeze-scroll deferred).

**Follow-up (I136-T15):** ↑/↓ left a ghost focus fill for one frame (deferred `_focused=false`) plus selected `inkHover` — looked like 2–3 hovers. Blur clears focus chrome sync; on TV selected-only keeps the green left bar without a second fill (`I136-A07`).

**Follow-up (I136-T16):** Last channel-row **↓** was ignored (`moveInGrid` returned false) so Flutter spatial wrap landed on the category rail. Last-row ↓ now traps — same as last-column → (`I136-A08`).

## Related

- [RFC-027](../rfc/027-[draft]-iptv-channel-guide.md) — in-player guide
- [135](135-[open]-android-tv-spatial-dpad-all-screens.md) — spatial D-pad (separate)
