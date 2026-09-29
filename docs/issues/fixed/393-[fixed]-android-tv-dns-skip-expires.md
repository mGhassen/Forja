# 393 — Android TV DNS timeout returns after 2 minutes

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Network · Android TV · Home catalog  
**Reported:** 2026-09-29

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I393-T01 | Dart `PackHttp`: after one system-DNS timeout, skip system probes until a later lookup succeeds | ✅ |
| 2 | I393-T02 | Rust `utils::dns` uses the same session skip | ✅ |
| 3 | I393-T03 | Android Exo `ForjaDohDns` uses the same session skip | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I393-A01 | Android TV emulator, app up more than 2 minutes: open a Home title — details load, no second `system DNS timed out` | ⬜ |

---

## Summary

[389](389-[fixed]-android-dns-blocks-catalog.md) raced system DNS with Cloudflare DoH, then skipped system DNS for 2 minutes. On the Android TV emulator, Private DNS never recovers. When that window ended, the next Home open called `InternetAddress.lookup` again. Dart's 5s timeout does not cancel the native lookup. It keeps running in netd. Catalog fetch (`native_fetch`, 25s client timeout) then failed `tmdb HTTP 0` and the error-retry button took focus.

**Root fix:** one system-DNS timeout skips further system probes for the process, in Dart, Rust, and ExoPlayer. A later system lookup that returns addresses clears the skip. An empty DoH answer still falls through to system DNS so LAN names can resolve.

---

## Related

- [389](389-[fixed]-android-dns-blocks-catalog.md) — race + 2-minute skip
- [392](392-[fixed]-android-playback-dns.md) — playback DoH
