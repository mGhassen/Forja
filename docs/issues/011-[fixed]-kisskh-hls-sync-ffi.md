# 011 — Kisskh decrypt and HLS parse sync FFI

**Priority:** P2  
**Severity:** Medium  
**Status:** fixed  
**Area:** `packages/api/lib/api/kisskh_subtitle_decryptor.dart`, `packages/rust/lib/src/utils/hls_master_parser.dart`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[open]-sync-ffi-ui-thread-audit.md)

## Summary

Secondary FFI call sites still on the main isolate. Lower traffic than [005](005-[fixed]-stremio-http-blocks-ui.md)–[007](007-[fixed]-torrent-search-blocks-ui.md) but same failure class on large payloads or slow devices.

## Call sites

| File | Call | Risk |
|------|------|------|
| `kisskh_subtitle_decryptor.dart` | `decryptKisskhBody` | Medium — large subtitle blobs |
| `hls_master_parser.dart` | `parseHlsMasterJson` | Low–medium — big master playlists |
| `facade.dart` | `parseM3uJson` | Medium — large M3U files |
| `iptv_network.dart` | `decodeXtreamText` | Low — base64 field decode |

## Solution (2026-07-06)

Unconditional isolate offload for consistency (no size threshold):

1. Added wrappers in `packages/rust/lib/src/isolate_runner.dart`:
   - `runDecryptKisskhBody(body, {sourceUrl})`
   - `runParseHlsMasterJson(masterUrl, body)`
   - `runParseM3uJson(content)`
2. Updated call sites:
   - `packages/api/lib/api/kisskh_subtitle_decryptor.dart` → `runDecryptKisskhBody`
   - `packages/rust/lib/src/utils/hls_master_parser.dart` → `runParseHlsMasterJson`
   - `packages/rust/lib/src/facade.dart` → `runParseM3uJson` in `Engine.parseM3uChannels`

### Waived (not offloaded)

| File | Call | Reason |
|------|------|--------|
| `iptv_network.dart` | `decodeXtreamText` | Low risk — small base64 field decode; already inside `runRustIsolate` callbacks for HTTP-heavy paths |

## Acceptance

- [x] Kisskh decrypt uses isolate wrapper
- [x] HLS/M3U parse uses isolate wrapper
- [x] [004](004-[open]-sync-ffi-ui-thread-audit.md) rows marked fixed or waived with justification
