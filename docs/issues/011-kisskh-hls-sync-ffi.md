# 011 — Kisskh decrypt and HLS parse sync FFI

**Priority:** P2  
**Severity:** Medium  
**Status:** open  
**Area:** `packages/api/lib/api/kisskh_subtitle_decryptor.dart`, `packages/rust/lib/src/utils/hls_master_parser.dart`  
**Reported:** 2026-07-06  
**Parent:** [004](004-sync-ffi-ui-thread-audit.md)

## Summary

Secondary FFI call sites still on the main isolate. Lower traffic than [005](005-stremio-http-blocks-ui.md)–[007](007-torrent-search-blocks-ui.md) but same failure class on large payloads or slow devices.

## Call sites

| File | Call | Risk |
|------|------|------|
| `kisskh_subtitle_decryptor.dart` | `decryptKisskhBody` | Medium — large subtitle blobs |
| `hls_master_parser.dart` | `parseHlsMasterJson` | Low–medium — big master playlists |
| `facade.dart` | `parseM3uJson` | Medium — large M3U files |
| `iptv_network.dart` | `decodeXtreamText` | Low — base64 field decode |

## Fix

- Wrap decrypt/parse FFI in `runRustIsolate` when input size > threshold or unconditionally for consistency
- `decodeXtreamText` — profile first; offload only if needed

## Acceptance

- [ ] Kisskh decrypt uses isolate wrapper
- [ ] HLS/M3U parse uses isolate wrapper or documented size threshold
- [ ] [004](004-sync-ffi-ui-thread-audit.md) rows marked fixed or waived with justification
