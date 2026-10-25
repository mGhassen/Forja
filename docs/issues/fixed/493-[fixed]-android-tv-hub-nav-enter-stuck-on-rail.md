# 493 — Android TV hub nav enter stuck on rail

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Shell TV · nav enter · catalog hubs (Asian Drama / Anime / Home)  
**Reported:** 2026-10-25 (manual ATV — Asian Drama OK from navbar)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On Android TV, opening a catalog hub (repro: Asian Drama) sometimes left D-pad focus on the navbar. Remote Right / OK did not move into the hub.

## Root cause

`enterTabFromNav` only retried pack `focus.enter` (~6 frames). Asian Drama / Anime / Home omit `enter` and rely on hero `defaultFocus`. When spotlight/hero was empty or unbound in that window, `_restoreDefault` returned false with no content/chrome fallthrough — focus stayed on the rail. Cousin of [460](460-[fixed]-android-tv-iptv-nav-enter-shelf-while-loading.md).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I493-T01 | `_restoreDefault`: after hero miss → `focusFirstContentRow` → `focusChromeRow` | ✅ |
| 2 | I493-T02 | `enterTabFromNav`: when enter omitted, try default each frame; longer retry; late land after restore miss | ✅ |
| 3 | I493-T03 | Widget test + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I493-A01 | Manual ATV: OK on Asian Drama (cold + revisit) lands in hub (hero or first rail), not stuck on nav | ⬜ |

---

## Links

- [460](460-[fixed]-android-tv-iptv-nav-enter-shelf-while-loading.md) · [243](243-[fixed]-android-tv-live-sports-first-focus-catalog.md) · [158](158-[fixed]-android-tv-nav-right-loses-page-focus.md)
