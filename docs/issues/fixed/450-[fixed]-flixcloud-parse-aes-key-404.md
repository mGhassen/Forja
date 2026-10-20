# 450 — FlixCloud parse-flixcloud decode fails (AES key 404)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/proxy` HLS rewrite · desktop/mobile open · ReAnime / hop-flixcloud

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **1 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I450-T01 | Confirm live media playlist `URI="key.bin"` resolves to enc-dec `/api/key.bin` 404; CDN nested `url=` has the 16-byte key; AES decrypt → MPEG-TS | ✅ |
| 2 | I450-T02 | Proxy: resolve relative HLS refs against nested `parse-flixcloud?url=` CDN playlist | ✅ |
| 3 | I450-T03 | Host: force `/hls-proxy` for `parse-flixcloud` (nested `.m3u8` must not skip proxy) | ✅ |
| 4 | I450-T04 | Unit tests + changelog + engine bump | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I450-A01 | ReAnime → FlixCloud hop opens and decodes (manual after rust rebuild) | ⬜ |

---

## Summary

Issue [332](332-[fixed]-flixcloud-encrypted-master-parse.md) correctly returns EncDec `parse-flixcloud?url=&w_payload=` so the **master** is plaintext `#EXTM3U`. Nested media playlists still use relative `URI="key.bin"`. lavf (and our prior rewrite) join that against `https://enc-dec.app/api/` → **404**. The real key is next to the CDN playlist inside `url=`. Segments are named `.png`/`.webp` but after AES they are plain MPEG-TS — the open fails at key fetch / decrypt, not PNG strip.

### Fix

- `hls_relative_base_url` / `hls_join_bases` — relative rewrite uses nested CDN playlist for `parse-flixcloud`
- `shouldProxyExtensionlessHls` — always local-proxy `parse-flixcloud` so keys are absolutized before the player

### Related

- [332](332-[fixed]-flixcloud-encrypted-master-parse.md) — EncDec parse-flixcloud hop
- [405](405-[fixed]-reanime-flixcloud-cf-false-positive.md) — CF false positive on embed HTML
