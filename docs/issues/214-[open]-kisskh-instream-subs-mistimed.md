# KissKh in-stream subs mistimed vs site player

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Asian Drama / KissKh provider / player subtitles

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix tasks · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I214-T01 | KissKh provider JS: fetch `/api/Sub/{episodeId}` with subtitle `kkey` and attach rows to streams | ✅ |
| 2 | I214-T02 | Host: decrypt KissKh Sub CDN cues on load (desktop / mobile / Exo) | ✅ |
| 3 | I214-T03 | Auto-pick prefers provider-attached KissKh subs over HLS mux “In-stream” tracks | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I214-A01 | Asian Drama → KissKh play (e.g. My Bias My Boss E1): active sub is KissKh Sub API (source kisskh), timing matches kisskh.co | ⬜ |
| 2 | I214-A02 | Subtitles menu still lists HLS mux tracks as In-stream; picking KissKh row stays synced | ⬜ |

---

## Summary

KissKh’s website player loads **`/api/Sub/{id}`** (signed + AES line-decrypt). Forja’s JS provider only opened Episode video URLs, so the player auto-picked **HLS muxed** text tracks labeled In-stream — often mistimed vs the same episode on the site.

**Root cause:** Sub API fetch + decrypt dropped when extract moved to `plugins/providers/kisskh.js`; host still preferred mux over provider sideloads.

**Fix:** Restore Sub API in the provider; decrypt on load via `KissKhSubtitleDecryptor`; prefer provider-attached subs over HLS mux.

## Related

- [Subtitles](../features/playback/subtitles.md)
- [Asian Drama](../features/hubs/asian-drama.md)
- Old path: `KissKhSubtitleDecryptor` + pre-JS `kisskh_extractor.dart` Sub ingest
