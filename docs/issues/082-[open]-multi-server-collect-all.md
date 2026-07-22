# 082 — Multi-server providers must show every mirror

**Status:** open
**Priority:** P1
**Severity:** High
**Area:** `HostProviderAdapter` · Videasy / VidNest / VidSrc.sbs extractors · `StreamExtractor` chip rotation

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix tasks · **1 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I82-T01 | VidSrc.sbs: sniff every `CFG.servers` mirror; merge all streams (no first-hit return); CFG order (no preferred reorder) | ✅ |
| 2 | I82-T02 | VidNest: probe every API server in bounded parallel; merge all streams | ✅ |
| 3 | I82-T03 | Videasy: drop post-first-hit grace abort; wait for all mirror probes (bounded in-flight) | ✅ |
| 4 | I82-T04 | Chip-rotate embeds (`rotateServerChips`): do not early-complete; keep collecting until timeout | ✅ |
| 5 | I82-T05 | Feature doc + changelog + unit coverage for collect-all / order | ✅ |
| 6 | I82-T06 | No background checks while playing: drop Source auto-probe; stop Auto sibling fill; cancel pending extracts on playback confirm | ✅ |
| 7 | I82-T07 | VidSrc.sbs: first-hit + ≤3s grace then return (cancel leftover WebViews); dead mirrors must not block spinner | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I82-A01 | VidSrc.sbs Source panel lists every sniffed mirror that returned a stream (e.g. PRO Multi + Cinesrc + Vlux + Star), not only the first hit | ⬜ |
| 2 | I82-A02 | VidNest / Videasy return every responsive server/mirror stream in one resolve | ⬜ |
| 3 | I82-A03 | Chip-rotate providers keep multiple chip streams in `sources` when more than one emits during the sniff | ⬜ |
| 4 | I82-A04 | Bounded concurrency (≤4 HTTP / ≤2 WebView) — no unbounded fan-out | ⬜ |
| 5 | I82-A05 | Unit: VidSrc.sbs post-first-hit grace ≤3s (dead mirrors cannot hold resolve open) | ✅ |

---

## Summary

Multi-server hosts discover several mirrors, then Forja threw away everything after the first successful sniff (VidSrc.sbs), first API server (VidNest), or an 8s grace cutoff (Videasy). Chip-rotate WebView sniffs early-completed after one strong playlist.

**Original policy (I82-T01–T06):** check every listed server/mirror with bounded parallelism and show every stream that responds.

**Latency correction (I82-T07):** full wait-for-all blocked play when one mirror hung (~22s sniff timeout). VidSrc.sbs now matches Videasy: first good mirror starts a short grace, then resolve returns and leftover WebViews cancel. Streams found during the grace still merge; dead mirrors after grace do not hold the spinner.

## Related

- [051](051-[open]-embed-multiserver-sniff-proxy-cookies.md) — sniff hardening (proxy / cookies / profiles)
- [071](fixed/071-[fixed]-videasy-grace-discards-mirror-streams.md) — Videasy grace discard (partial; grace still aborted hung siblings)
- [Stream providers](../features/sources/stream-providers.md)
