# 392 — Playback dies when system DNS cannot resolve hosts

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Player · Android · DNS  
**Reported:** 2026-09-29

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I392-T01 | ExoPlayer HTTP uses OkHttp with system DNS + Cloudflare DoH (same rules as PackHttp), including DRM license requests | ✅ |
| 2 | I392-T02 | MediaKit loopback proxy resolves through PackHttp and forwards plain HTTP as well as CONNECT | ✅ |
| 3 | I392-T03 | Movies, IPTV, Live Sports, and trailer MediaKit opens set that proxy when system DNS fails or NAT64 is the only IPv6 | ✅ |
| 4 | I392-T04 | YouTube trailer extract in its worker isolate installs the same DoH HttpClient | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I392-A01 | Android TV emulator with `EAI_NODATA` on system DNS plays a catalog stream on ExoPlayer and on MediaKit | ⬜ |

---

## Summary

Catalog HTTP already fell back to DNS-over-HTTPS. Playback did not. ExoPlayer used `HttpURLConnection` (`android_getaddrinfo`). MediaKit / libmpv uses the same system resolver and only had a loopback proxy for NAT64, which itself called system DNS and ignored `http://`.

**Root fix:** ExoPlayer resolves through OkHttp with the PackHttp rules (system and DoH in parallel, IPv4 preferred, 60s cache, skip a hung system lookup for 2 minutes). MediaKit, which cannot take a DNS hook, opens through the existing loopback proxy when system DNS fails; that proxy now dials `PackHttp.resolveHost` and forwards plain HTTP. IPTV, Live Sports, and trailers set the proxy on open. YouTube extract runs in an isolate that did not inherit the app’s DoH client — that isolate installs it before the lookup.

---

## Related

- Catalog / hotspot DNS: [298](298-[fixed]-android-tv-hotspot-dns-unreachable.md) · [389](389-[fixed]-android-dns-blocks-catalog.md)
- NAT64 dial: `Ipv4ConnectProxy`
