# 013 — 111477 captcha / Cloudflare handling still in Dart

**Priority:** P3  
**Severity:** Low  
**Status:** open  
**Area:** `packages/api/lib/playback/site111477_proxy.dart`, `crates/site111477`  
**Reported:** 2026-07-06  
**Tracked:** P2-92 known gap

## Summary

Loopback proxy consolidated in Rust (P2-92 ✅), but **captcha and Cloudflare challenge handling** remain in Dart. Split-brain maintenance risk; behavior may diverge from Rust proxy path.

## Impact

- Not a UI-freeze issue by default (proxy lifecycle FFI is fast)
- Future port gaps if 111477 site changes challenge flow
- Technical debt blocking full engine normalization

## Acceptance

- [ ] Document current Dart vs Rust split in crate README
- [ ] Port captcha/CF to `crates/site111477` or explicitly accept permanent host responsibility in ENGINE_BOUNDARY
