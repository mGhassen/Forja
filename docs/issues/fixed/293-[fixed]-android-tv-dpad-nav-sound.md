# 293 — Android TV D-pad navigation / OK click sounds

**Status:** fixed  
**Priority:** P2  
**Severity:** Low  
**Area:** Android TV · D-pad · Settings → Playback

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 2** acceptance (device smoke) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I293-T01 | `forja/platform` → `AudioManager.playSoundEffect` (focus nav + key click) | ✅ |
| 2 | I293-T02 | Central `TvNavSound`: ATV-only; focus move + OK activate; mute while `playerSurfaceActive` | ✅ |
| 3 | I293-T03 | Settings → Playback **Remote click sounds** (default on; device-local) | ✅ |
| 4 | I293-T04 | Changelog + playback settings feature doc | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I293-A01 | ATV: D-pad focus move and OK play system UI sounds outside the player | ⬜ |
| 2 | I293-A02 | Toggle off / fullscreen player → silent; phone/desktop unchanged | ⬜ |

---

## Summary

Android TV D-pad focus and OK had no click feedback. One shell hook (`TvNavSound`) plays system `AudioManager` focus-nav / key-click effects when focus actually moves or OK is pressed. Silent while any fullscreen player surface is up. Settings toggle defaults on; not cloud-synced.

## Related

- [playback-settings](../../features/settings/playback-settings.md)
