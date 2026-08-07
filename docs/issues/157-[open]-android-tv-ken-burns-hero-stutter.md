# 157 — Android TV: Ken Burns hero backdrop stutter

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** Android TV · Home / details heroes · Ken Burns

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I157-T01 | `ShellInputPolicy.kenBurnsBackdrop` — false on TV | ✅ |
| 2 | I157-T02 | `KenBurnsBackdrop` skips `Transform.scale` ticker when policy off; static cover image | ✅ |
| 3 | I157-T03 | `RotatingHeroBackdrop` snaps URL crossfade on TV (no 800ms dual-layer blend) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I157-A01 | Android TV Home featured hero: backdrop still (or hard-cuts between stills) — no pan/zoom saccades | ⬜ |
| 2 | I157-A02 | Android TV media / Anime / Asian Drama details hero: same — still backdrop, rotation without Ken Burns judder | ⬜ |

---

## Summary

Home featured hero and details heroes use **Ken Burns** (`KenBurnsBackdrop`: continuous `Transform.scale` + alignment tween over a full-bleed `CachedNetworkImage`). On leanback SoCs that re-rasterizes the layer every frame → visible **saccading** / stutter. Same ATV doctrine as focus chrome ([139](139-[open]-android-tv-shell-focus-chrome-stutter.md)): drop continuous motion on TV; keep Ken Burns on desktop/mobile.

**Note:** Anime / Asian Drama **hub** carousels use the same `KenBurnsBackdrop` path as Home (motion off on TV via `ShellInputPolicy.kenBurnsBackdrop`).

## Related

- [139](139-[open]-android-tv-shell-focus-chrome-stutter.md) — focus chrome snap on TV
- [home.md](../features/movies-tv/home.md) · [media-details.md](../features/movies-tv/media-details.md)
