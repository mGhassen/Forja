# 011 — Kisskh decrypt and HLS parse sync FFI

**Priority:** P2  
**Severity:** Medium  
**Status:** fixed (2026-07-06) — `EngineWorkerPool` for parse/decrypt jobs  
**Root fix:** [015](015-[fixed]-rust-blocking-http-engine-debt.md)  
**Area:** `kisskh_subtitle_decryptor.dart`, `hls_master_parser.dart`, `facade.dart`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[fixed]-sync-ffi-ui-thread-audit.md)
## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** |
| **Backlog** | [0.4.3](../backlog/done/0.4.3-[done].md) |


**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---



## Workaround (shipped — 2026-07-06)

Isolate offload — stops UI block on large payloads but **does not fix** per-call isolate spawn. Root fix: [015](015-[fixed]-rust-blocking-http-engine-debt.md).

1. `runDecryptKisskhBody`, `runParseHlsMasterJson`, `runParseM3uJson` in `isolate_runner.dart`.
2. Call sites: `kisskh_subtitle_decryptor.dart`, `hls_master_parser.dart`, `facade.dart`.

## Root fix (open, optional)

Track in [015](015-[fixed]-rust-blocking-http-engine-debt.md): avoid isolate spawn per parse if job API or fast-path added.

## Waived (not offloaded)

| File | Call | Reason |
|------|------|--------|
| `iptv_network.dart` | `decodeXtreamText` | Low risk — small base64 field |

## If this file is deleted

Optional engine perf tracked in **[015](015-[fixed]-rust-blocking-http-engine-debt.md)**.

## Acceptance

- [x] Kisskh decrypt uses isolate wrapper
- [x] HLS/M3U parse uses isolate wrapper
