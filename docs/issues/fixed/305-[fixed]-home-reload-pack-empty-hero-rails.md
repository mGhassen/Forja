# 305 — Home empty hero / Popular after Reload packs

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** KitShell · Home hub · pack reload

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I305-T01 | Pack install `hubFeedEpoch` bumps `refreshEpoch` + keepPainted (rails rebind) | ✅ |
| 2 | I305-T02 | Clear `PackLoadedPaint` memos for the hub plugin on that epoch | ✅ |
| 3 | I305-T03 | Empty page-feed slice falls through to direct `action:rail` (no Popular title-only) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I305-A01 | Settings → Reload packs → Home shows Spotlight hero + Popular posters again without leaving the tab | ⬜ |

---

## Summary

After **Reload packs**, Home kept Continue Watching / mood / Because but lost the cinematic hero and showed a bare **Popular** title. Soft reload only re-ran `layout`/`feed` and did not bump `PackChromeScope.refreshEpoch`, so `PackLoadedPaint` never rebound. An empty batched feed slice was also painted as ok (title-only ranked row, shrunk hero).

**Root fix:** hub feed epoch mirrors list-feed soft refresh (epoch + force network + keep painted + new page feed) and empty page-feed rails fetch `action:rail` once.
