# Issue 304: Live Sports match tap does not open panel / details

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Live Sports · schedule list · `matchOpen` · kit list tap

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I304-T01 | `resolveKitListTapOpen` — panel needs chrome+wide; else details; never fall through to `open.surface:live` on match lists | ✅ |
| 2 | I304-T02 | `showPanel` uses the same resolver (empty / label aliases still paint the side panel) | ✅ |
| 3 | I304-T03 | Leanback `FocusableControl` keeps pointer `onTap` (coalesce Select+synthetic click) so mouse/OK both activate | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I304-A01 | Wide layout + Open matches in → Side panel: tap/OK a match opens Providers beside the schedule | ⬜ |
| 2 | I304-A02 | Open matches in → Detail page (or narrow window): tap/OK opens the match detail page | ⬜ |

---

## Summary

**Symptom:** Tapping / OK on a Live Sports match did nothing — no side panel and no detail page.

**Root cause:** Schedule rows carry `open.surface: live`. When `matchOpen` was missing, empty, a settings **label** (`Side panel`), or panel mode could not show (no chrome / narrow width), the list tap fell through to `openMetaItem` → hub tab re-request — a no-op while already on Live Sports. Leanback also skipped pointer `onTap`, so mouse clicks never activated.

**Fix:** Resolve tap open with `resolveKitListTapOpen` (panel / details / IPTV openTap). Match lists always open panel or details. Pointer activate works on leanback via existing coalesce.
