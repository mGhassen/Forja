# 358 — WatchFooty `wfty.st` fails open (PNG-named MPEG-TS)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Live Sports · WatchFooty · hls-proxy · MediaKit

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I358-T01 | `/hls-proxy`: image-extension playlists upgrade to `strip=png` (do not 502) — MPEG-TS under `.png` names | ✅ |
| 2 | I358-T02 | Live `proxyPlayUrl` passes `strip=png` for `wfty.st`; goat m3u8 probe rejects only image **magic**, not URI suffix | ✅ |
| 3 | I358-T03 | sportsembed `unlock.mjs` accepts alphanumeric match ids (e.g. `ba34ab52`) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I358-A01 | Live Sports → WatchFooty mirror on a live fixture opens native player (not Failed to open hls-proxy) | ⬜ |

---

## Summary

Unlock returns a signed `lb*.wfty.st`…`playlist.m3u8` with sportsembed Referer. The playlist lists **image CDN URLs** (`.png`) whose bodies are **MPEG-TS**. `/hls-proxy` treated that as a WAF stills decoy and returned 502 → MediaKit `Failed to open`.

**Root fix:** rewrite those playlists with `strip=png` so segment responses sniff TS / set `video/mp2t`. Pack unlock also accepts hex match ids used by newer WatchFooty fixtures.
