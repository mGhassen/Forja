# 330 — MobiKora unlock miss loops “Unlocking source…”

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Live Sports · MobiKora · nest unlock · live player

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I330-T01 | Nest unlock: decode `document.write("\x…")` + extract syria-player `proxy.php?stream=` | ✅ |
| 2 | I330-T02 | Skip YouTube embeds in nest walk (native-only) | ✅ |
| 3 | I330-T03 | Host: treat syria-player proxy as playable HLS URL | ✅ |
| 4 | I330-T04 | Host: unlock miss clears play-when-ready so watchdog does not re-unlock forever | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I330-A01 | BeIN / syria-player Alba tabs unlock to `proxy.php?stream=` when upstream serves HLS | ⬜ |
| 2 | I330-A02 | YouTube-only channel (e.g. SSC Sport 1 today) toasts “No playable stream” and does not loop Unlocking | ⬜ |

---

## Problem

MobiKora channel pages nest AlbaPlayer → `cdn.syria-player.info`. That leaf hides the player HTML in hex `document.write` and exposes HLS via `proxy.php?stream=` (no `.m3u8` in the path). Nest unlock returned empty; the live player kept “Unlocking source…” and the cold-open watchdog re-unlocked every 30s.

Separately, some Alba tabs are YouTube-only (e.g. SSC Sport 1 during Gulf Cup). Native unlock correctly returns empty — host must not spin forever.

## Fix

- Pack `forjahq-livesports` **2.0.17**: expand hex `document.write`, pull `streamUrl` / syria-player proxies, skip YouTube nests.
- Host: syria-player `proxy.php?stream=` counts as play-ready; unlock miss sets `_userPlayWhenReady = false` and clears the unlock banner.

## Notes

YouTube-only upstream has no native play URL — omit / toast, never WebView ([no-embed-playback](../../../.cursor/rules/no-embed-playback.mdc)).
