# 394 — Remove Cloudflare DNS-over-HTTPS

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Network · Android · Engine HTTP

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **1 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I394-T01 | Dart `PackHttp` and Android `HttpOverrides` use the platform resolver | ✅ |
| 2 | I394-T02 | Rust catalog HTTP uses reqwest's resolver; IPTV keeps AF_INET only | ✅ |
| 3 | I394-T03 | ExoPlayer uses platform DNS; MediaKit proxy stays for DNS64 only | ✅ |
| 4 | I394-T04 | Drop the unreleased changelog notes and the user-guide sentences that described the fallback | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I394-A01 | No Cloudflare DNS client remains in Dart, Rust HTTP, or ExoPlayer | ✅ |

---

## Summary

The fallback was built for an Android TV phone-hotspot / emulator Private DNS hang. The TV is not used that way. The race then lived in three copies (Dart, Rust, Exo) and produced the blank-rails and playback bugs in [389](389-[fixed]-android-dns-blocks-catalog.md), [392](392-[fixed]-android-playback-dns.md), and [393](393-[fixed]-android-tv-dns-skip-expires.md).

Name lookup is the platform resolver again. IPTV still asks for A records (`AF_INET`) so Windows DNS64 does not return an empty address list. MediaKit still opens the loopback proxy when DNS returns a real IPv4 address plus a `64:ff9b::/96` AAAA.

An emulator whose Private DNS never answers will fail lookup again. That is the platform resolver, not a Forja fallback.

---

## Related

- [298](298-[fixed]-android-tv-hotspot-dns-unreachable.md) — added the fallback
- [389](389-[fixed]-android-dns-blocks-catalog.md) · [392](392-[fixed]-android-playback-dns.md) · [393](393-[fixed]-android-tv-dns-skip-expires.md)
- Windows IPv4-only portals stay: [261](261-[fixed]-windows-iptv-portal-unreachable-dns64.md)
