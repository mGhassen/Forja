# Issue 112 — IPTV share codes: self-contained tokens (no pastebin)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV / share codes

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5/5** · **2/2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I112-T01 | Rust `portal_share` encode/decode (`F1.` AES-CBC token) | ✅ |
| 2 | I112-T02 | FFI + Dart create/resolve; legacy 8-char rentry fetch kept | ✅ |
| 3 | I112-T03 | Web + admin TS mirror of embedded encode; rentry fetch for legacy | ✅ |
| 4 | I112-T04 | Add-portal UI accepts `F1.` paste + legacy XXXX-XXXX | ✅ |
| 5 | I112-T05 | Feature docs + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I112-A01 | New share copy/import works offline (no rentry) | ✅ |
| 2 | I112-A02 | Legacy 8-char codes still resolve when rentry is up | ✅ |

---

## Summary

Rentry outages made all IPTV share codes look “not found.” New shares are self-contained encrypted `F1.…` tokens (encrypt/decrypt only — no persistence). Legacy 8-character codes still fetch from rentry so existing codes are not orphaned.

## Follow-up

Rentry was removed. 8-character codes (`XXXX-XXXX`) are back: Rust encrypts an `F1.` payload, stored under the short code in `iptv_share_codes` (Supabase). Rows older than 7 days are hidden on read. Inngest `iptv-share-codes-purge` (daily 04:20 UTC, event `iptv/share-codes.purge`) deletes them. Leftover `F1.` tokens still import. Old rentry 8-char codes do not.

## Related

- [IPTV — Xtream](../features/live/iptv-xtream.md)
- [Cloud sync](../features/settings/cloud-sync.md)
