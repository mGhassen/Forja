# 528 — Hub open lands mid-page (early body focus) instead of hero

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Shell TV · nav enter · catalog hubs  
**Reported:** 2026-11-03 (manual — Anime opens with hero clipped; focus on Continue Watching)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 9 / 9** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Opening a catalog hub from the nav lands focus on an early body row (often Continue Watching). `ensureVisible` scrolls that row into view and clips the hero. Desktop and TV both use `ensureVisibleOnFocus: true`.

## Root cause

`enterTabFromNav` called full `_restoreDefault` when pack `focus.enter` is omitted. Local Continue Watching registers before the spotlight CTA is focusable; landing it + `ensureVisible` scrolled mid-page. Even after hero-only retries, the **exhaust** path still called `focusFirstContentRow` while the hero binder existed but the CTA node was not mounted yet (~AniList spotlight slower than local CW).

Home usually wins because TMDB spotlight is warm and CW sits under Featured/Popular. Anime / Asian Drama put CW immediately under the hero and AniList/KissKH spotlight stays shimmer longer — **no `defaultFocus` binder** while loading — so late hero poll never started and enter fell through to CW.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I528-T01 | Enter retries: hero-only; stop only when hero CTA has focus | ✅ |
| 2 | I528-T02 | Exhaust with hero binder: late hero-only poll — never first-content steal | ✅ |
| 3 | I528-T03 | Widget test: late hero wins over early body row (generic id) | ✅ |
| 4 | I528-T04 | Changelog | ✅ |
| 5 | I528-T05 | Packs home/anime/asian_drama: `focus.enter/restore: hero-details` | ✅ |
| 6 | I528-T06 | Host `land`: `hero-details` → `focusHero` (no first-content fallthrough) | ✅ |
| 7 | I528-T07 | Pack enter returns bool — sticky CW after hero miss is not success | ✅ |
| 8 | I528-T08 | `enterAwaitsHero`: late poll without binder; never CW on shimmer exhaust | ✅ |
| 9 | I528-T09 | Widget test: no binder → past budget → binder mounts → hero wins | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I528-A01 | Manual: open Anime / Home / Asian Drama with CW history → View details focused, hero at top | ⬜ |

## Links

- [524](524-[fixed]-hub-enter-lands-on-mood-chips.md) · [493](493-[fixed]-android-tv-hub-nav-enter-stuck-on-rail.md)
