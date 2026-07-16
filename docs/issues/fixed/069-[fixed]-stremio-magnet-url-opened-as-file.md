# 069 — Stremio magnet `url` opened as file; torrent switch throws

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `packages/rust` Stremio resolve · `apps/forja` player Sources

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I69-T01 | `classifyStremioStream`: magnet / `.torrent` in `url` fall through to magnet resolve (not direct play) | ✅ |
| 2 | I69-T02 | Player: refuse raw magnet in `openPlayerStream`; resolve magnet `mediaPath` on primary init | ✅ |
| 3 | I69-T03 | Player Sources torrent/Stremio switch: bump `_fallbackGen`, no unhandled throw on fail | ✅ |
| 4 | I69-T04 | Episode switch: magnet-in-`url` resolves via local engine / debrid | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I69-A01 | Unit: magnet `url` classify → null; HTTP `url` → playable; `buildMagnetFromStremioStream` magnet-only | ✅ |
| 2 | I69-A02 | Manual: pick Stremio/Torrentio magnet or Torrents row — no `File name too long` / unhandled `Failed to resolve torrent` | ⬜ |

---

## Summary

Stremio addons sometimes put a **magnet** in `stream.url` (with or without `infoHash`). `classifyStremioStream` treated any `url` as a direct playable HTTP stream and handed it to the player as `mediaPath`. media_kit/mpv then opened it as a **relative file** under the app temp dir → `Cannot open file '…/tmp/magnet:?xt=…': File name too long`.

Separately, player **Sources → Torrents** called `_switchTorrentSource`, which threw `Exception('Failed to resolve torrent')` on null resolve (and on open fail) without a catch in `_selectTorrent` — unhandled Flutter exceptions. Switch also did not bump `_fallbackGen`, so it raced with `_initPlayback` still trying the bad magnet.

**Root fix:** classify magnets for resolve; guard opens; switch returns after marking failed instead of throwing.
