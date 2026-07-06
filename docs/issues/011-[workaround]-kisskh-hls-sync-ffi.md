# 011 — Kisskh decrypt and HLS parse sync FFI

**Priority:** P2  
**Severity:** Medium  
**Status:** workaround (2026-07-06) — UI no longer blocks; root cause open  
**Root fix:** [015](015-[open]-rust-blocking-http-engine-debt.md)  
**Area:** `kisskh_subtitle_decryptor.dart`, `hls_master_parser.dart`, `facade.dart`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[open]-sync-ffi-ui-thread-audit.md)

## Status summary

| Layer | Status | Notes |
|-------|--------|-------|
| **Symptom** — main isolate blocks on large parse/decrypt | **workaround** | isolate wrappers |
| **Root** — per-call isolate spawn for parse | **open** (optional) | [015](015-[open]-rust-blocking-http-engine-debt.md) |
| **`decodeXtreamText`** on UI thread | **waived** | tiny base64 decode — `iptv_network.dart:277` |

## Workaround (shipped — 2026-07-06)

Isolate offload — stops UI block on large payloads but **does not fix** per-call isolate spawn. Root fix: [015](015-[open]-rust-blocking-http-engine-debt.md).

1. `runDecryptKisskhBody`, `runParseHlsMasterJson`, `runParseM3uJson` in `isolate_runner.dart`.
2. Call sites: `kisskh_subtitle_decryptor.dart`, `hls_master_parser.dart`, `facade.dart`.

## Root fix (open, optional)

Track in [015](015-[open]-rust-blocking-http-engine-debt.md): avoid isolate spawn per parse if job API or fast-path added.

## Waived (not offloaded)

| File | Call | Reason |
|------|------|--------|
| `iptv_network.dart` | `decodeXtreamText` | Low risk — small base64 field |

## If this file is deleted

Optional engine perf tracked in **[015](015-[open]-rust-blocking-http-engine-debt.md)**.

## Acceptance

- [x] Kisskh decrypt uses isolate wrapper
- [x] HLS/M3U parse uses isolate wrapper
