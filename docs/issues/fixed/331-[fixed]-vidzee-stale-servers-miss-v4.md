# 331 — Vidzee empty Sources (stale servers miss v4 languages)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/vidzee.js` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I331-T01 | Probe live `core.vidzee.wtf/streams` — confirm dcloud/tik 502 on titles that still play in browser | ✅ |
| 2 | I331-T02 | Add player chips incl. **Apre** + `v4:<lang>`; honor API Referer; drop dead playlists | ✅ |
| 3 | I331-T03 | Providers pack bump + feature/changelog docs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I331-A01 | curl: TMDB `1101383` returns ≥1 stream on `v4:English` / `v4:Hindi` with `e=0` | ✅ |
| 2 | I331-A02 | App: Sources → Vidzee lists streams for a title that previously returned 0 (manual) | ⬜ |

---

## Summary

Vidzee Forja only probed `dcloud`, `tik`, `ipcloud`, `v6:Hindi`. The live player also exposes **Apre** (`apre`) and **Acme** language chips (`v4:<lang>`). For titles like *The End of Oak Street* (TMDB `1101383`), the old servers return **502** while `apre` + `v4:*` return plaintext HLS with `e=0`. Sources showed **0** (then only Hindi) even though the browser player has another working chip.

### Fix

- Server list matches the player: `dcloud`, **`apre`**, `tik`, `ipcloud`, `v6:Hindi`, common `v4:*` languages
- Prefer API `headers.Referer` (do not force `player.vidzee.wtf` Origin over CDN Referers)
- Probe the playlist before emitting — drop dead CDN rows (e.g. English 404s)
- Deduplicate identical URLs
- Providers pack **1.6.15**

### Related

- [170](../170-[open]-vidzee-cloudflare-sniff.md) — CF sniff on embed (separate; HTTP path is this issue)
- [328](328-[fixed]-vidnest-stale-server-backends-wrong-title.md) — same class of stale-server miss
- [stream providers](../../features/sources/stream-providers.md)
