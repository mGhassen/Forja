# 462 — Details hero SUB/DUB D-pad unreachable + dropdown dead

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · details hero · stream languages  
**Reported:** 2026-10-23 (manual details hero)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On details (Home / Anime), D-pad could not move onto the hero **SUB** / **DUB** language segments (often stuck on My List), and OK on a segment opened a menu the remote could not navigate.

## Root cause

1. Hero `itemCount` reserved **one** slot for the language filter while `KitMultiselectPlayFilter` registered **two** (SUB + DUB). Right from SUB clamped to the last counted index → DUB unreachable.
2. Dropdown used Material `MenuAnchor` / `CheckboxMenuButton`, which never joined the leanback focus graph (My List already uses Overlay + `TvOverlayScope`).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I462-T01 | Count SUB+DUB slots in details hero `itemCount` via `focusSlotCount` | ✅ |
| 2 | I462-T02 | Replace `MenuAnchor` with Overlay + `TvOverlayScope` (My List pattern); Back dismisses | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I462-A01 | ATV details: ←/→ reaches SUB then DUB after My List; OK opens menu; ↑/↓ walks Clear + languages; Back closes | ⬜ |
| 2 | I462-A02 | Desktop mouse: SUB/DUB open and toggle languages without breaking hero layout | ⬜ |

## Links

- [425](../425-[open]-home-stream-language-filter.md) — stream language multiselect
- [443](443-[fixed]-anime-stream-languages-like-home.md) — Anime same control
