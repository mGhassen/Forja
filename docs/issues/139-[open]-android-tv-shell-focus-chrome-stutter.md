# 139 — Android TV: shell / catalog focus chrome stutter

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · shell nav rail · catalog focus · D-pad

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I139-T01 | `FocusableControl`: snap focus scale on TV (`instantFocusChrome`) — no 200ms AnimationController | ✅ |
| 2 | I139-T02 | Nav rail: Duration.zero scale/color/underline/saturation; skip rail-engage parent rebuild cascade | ✅ |
| 3 | I139-T03 | `ForjaInteractive` / `ForjaPlainIcon`: Duration.zero scale on TV | ✅ |
| 4 | I139-T04 | TV horizontal scroller `cacheExtent` 2000 → 720 (fewer live focusable cards) | ✅ |
| 5 | I139-T05 | Feature docs + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I139-A01 | Android TV: hold ←/→ across a Home catalog row — focus moves without obvious per-step hitch / scale tween | ⬜ |
| 2 | I139-A02 | Android TV: ↑/↓ on nav rail — icons/labels snap; no whole-rail shrink animation when entering/leaving rail | ⬜ |
| 3 | I139-A03 | Android TV: content ↔ nav rail focus moves feel snappy (no cascade rebuild stutter) | ⬜ |

---

## Summary

D-pad browsing on leanback felt heavily stuttered because **every focus step** ran desktop-style **200ms** focus chrome: `FocusableControl` `AnimationController` + `Transform.scale`, nav rail `AnimatedScale` / color / underline / `ColorFiltered` tweens, plus a **rail-engage** parent `setState` that rebuilt every nav item when focus entered or left the rail. Horizontal rows also kept `cacheExtent: 2000` (many live cards).

**Root fix:** `ShellInputPolicy.instantFocusChrome` (TV) snaps focus chrome to zero duration; skip rail-engage cascade on TV; lower TV row cache extent.

## Related

- [121](121-[open]-android-tv-skip-shell-slide.md) — route slide jank (separate)
- [136](136-[open]-android-tv-iptv-catalog-guide-scroll-focus.md) — IPTV list ensureVisible / denser rows
- [120](120-[open]-android-tv-player-memory-purge.md) — keep-alive / player memory (separate)
