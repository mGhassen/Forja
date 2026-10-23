# Issue 460: Android TV IPTV — nav enter lands on shelf while portal loading

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV hub · Android TV · shell nav D-pad · composition cover

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I460-T01 | Hub land: when enter/restore row + content miss → chrome shelf (`focusChromeRow` / selected shelf fallback) | ✅ |
| 2 | I460-T02 | `enterTabFromNav`: accept topBar land when body has no focusable content rows; do not wipe that chrome memory | ✅ |
| 3 | I460-T03 | Widget test + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I460-A01 | Manual ATV: IPTV portal stuck on loading cover → OK/→ from navbar lands on Live/Movies/Series shelf (not stuck on rail) | ⬜ |

---

## Summary

**Symptom:** On Android TV, while an IPTV portal loads forever (composition cover hides the category rail), OK / → from the navbar could not enter the hub — focus stayed on the rail. The shelf (Live / Movies / Series) was the only focusable chrome, but pack `enter`/`restore: cats` missed and `focusFirstContentRow` skips chrome (`sortOrder < 0`). `enterTabFromNav` also rejected top-bar land when content rows exist, and wiped topBar memory after retries.

**Root fix:** After cats/content miss, land selected chrome shelf; treat topBar as a successful enter when the body has no focusable content rows.

**Related:** [301](../301-[open]-iptv-dpad-focus-hover-chrome.md) · [266](../266-[open]-android-tv-iptv-dpad-up-after-shelf-change.md)
