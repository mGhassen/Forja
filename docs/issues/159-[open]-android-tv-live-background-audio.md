# 159 — Android TV: live / IPTV audio continues after Home

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Live Matches · IPTV · app lifecycle · settings sync

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I159-T01 | Stop cloud-syncing `play_in_background` (device-local) | ✅ |
| 2 | I159-T02 | One-shot phone/TV migrate: reset polluted KV to platform default | ✅ |
| 3 | I159-T03 | `keepsPlayingInBackground` always false on Android TV; hide Settings toggle | ✅ |
| 4 | I159-T04 | IPTV pause on `_userPlayWhenReady` (live buffering race) | ✅ |
| 5 | I159-T05 | Live embed WebView lifecycle pause (incl. Streamed underlay) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I159-A01 | Physical Android TV: Live Match playing → Home → no Forja audio; return resumes | ⬜ |
| 2 | I159-A02 | Desktop: leave window with Play in background on — audio keeps going | ⬜ |

---

## Summary

Issue [134](fixed/134-[fixed]-player-audio-continues-after-app-switch.md) added lifecycle pause for MediaKit / Exo / IPTV, gated by **Play in background**. That pref defaults **on** on desktop and **off** on phone/TV, but it was **cloud-synced** — desktop `true` overwrote Android TV, so Home left Live Matches / IPTV decoding.

**Root fix:** device-local pref (no sync), one-shot reset on phone/TV, Android TV always pauses (`keepsPlayingInBackground`), harden IPTV pause while live is buffering, pause Live embed WebView (including Streamed underlay kept for CDN proxy).

## Related

- [134](fixed/134-[fixed]-player-audio-continues-after-app-switch.md) — original pause wiring
- [Player](../features/playback/player.md)
- [Playback settings](../features/settings/playback-settings.md)
