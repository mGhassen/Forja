# 395 — IPTV and playback can use a real IPv6 address

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV · Player · DNS

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I395-T01 | Portal DNS keeps real IPv6 and still drops a `64:ff9b` translation when a real address exists | ✅ |
| 2 | I395-T02 | Portal HTTP is not bound to IPv4, so a real AAAA can connect | ✅ |
| 3 | I395-T03 | MediaKit proxy dials real IPv6 and still dials IPv4 when the other address is only `64:ff9b` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I395-A01 | Unit tests: real IPv6 kept; translation dropped beside IPv4; translation kept when it is the only address | ✅ |

---

## Summary

After the Cloudflare DNS removal, portal lookup and the MediaKit dial still kept only IPv4. A real IPv6 address never reached the socket. The socket was also bound to `0.0.0.0`, so hyper dropped every AAAA.

Real IPv4 and real IPv6 are both usable. A `64:ff9b::/96` translation is still dropped when a real address exists, and an IPv4 lookup still runs when DNS returns only that translation. If the translation is the only address, it is kept.

---

## Related

- [261](261-[fixed]-windows-iptv-portal-unreachable-dns64.md) · [269](../269-[open]-windows-iptv-portal-af-inet-dns64.md)
- [394](394-[fixed]-remove-cloudflare-doh.md)
