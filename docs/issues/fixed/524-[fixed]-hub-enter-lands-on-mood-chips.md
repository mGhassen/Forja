# 524 — Hub enter lands on mood chips / mid-page instead of hero

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Shell TV · nav enter · Anime / Asian Drama / catalog hubs  
**Reported:** 2026-11-02 (manual — Anime / Asian Drama open focuses Pick your vibe / mid-page)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Opening Anime (or other catalog hubs that omit pack `focus.enter`) from the nav lands D-pad focus on **Pick your vibe** mood chips (or the first early content row) instead of hero **View details**. `ensureVisible` scrolls that section into view.

## Root cause

Issue [493](493-[fixed]-android-tv-hub-nav-enter-stuck-on-rail.md) made `enterTabFromNav` call `_restoreDefault` every retry frame when pack enter is omitted. `_restoreDefault` falls through to `focusFirstContentRow`. Mood chips register immediately with a fixed option count; spotlight CTA / bleed rails often bind later. Landing on `mood-chips` satisfied `_pageHasContentFocus` and stopped hero retries.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I524-T01 | `focusFirstContentRow`: skip `mood-chips` / `mood-results` so vibe cannot steal enter | ✅ |
| 2 | I524-T02 | `enterTabFromNav`: unfocus sticky nav when CTA bound; upgrade to hero if early rail landed | ✅ |
| 3 | I524-T03 | Widget tests (hero over mood; rail over mood) + changelog | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I524-A01 | Manual ATV/desktop: OK / → into Anime lands on View details, not Pick your vibe; Asian Drama lands on View details | ⬜ |

## Links

- [493](493-[fixed]-android-tv-hub-nav-enter-stuck-on-rail.md) · [309](309-[fixed]-android-tv-home-dpad-dies-on-popular.md) · [243](243-[fixed]-android-tv-live-sports-first-focus-catalog.md) · [528](528-[fixed]-hub-open-not-at-top.md)
