# 088 — Stale webstreaming cache / history replays dead tokenized HLS

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `WebstreamingStreamCache` · resume · details Play · HLS probe

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** fix · **2/3** acceptance (app smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I88-T01 | Reject cache/history URLs when `?token=` JWT `exp` is past (2m skew) | ✅ |
| 2 | I88-T02 | Shorten webstreaming session/disk TTL to 25m (match anime) | ✅ |
| 3 | I88-T03 | `readLive` + probe before open on resume / details / pinned resolve; drop on fail | ✅ |
| 4 | I88-T04 | HLS segment probe counts 401/403/404 as poison (CloudStream leaf fail) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I88-A01 | Unit: expired JWT → `isUnplayableCachedStreamUrl` | ✅ |
| 2 | I88-A02 | Unit: fresh JWT accepted; skew window rejects | ✅ |
| 3 | I88-A03 | App: replay title after token TTL → re-resolve, no mid-play segment 403 storm | ⬜ |

---

## Summary

Green Play / Continue Watching reused session+disk cache (2h) and watch-history `streamUrl` with **no** JWT expiry check and **no** CDN probe. CloudStream `page-N.html?token=` links then 403 mid-play while the master still looked cached.

### Fix (shipped)

- Parse JWT `exp` on `?token=` URLs; treat expired / near-expiry as unplayable for cache write/read.
- TTL 25 minutes.
- `WebstreamingStreamCache.readLive` probes first source; drops entry on failure.
- Resume, details Play, pinned resolve, and in-memory details streams use live check before open.
- HLS media probe counts HTTP 401/403/404 segment responses as failures (was fail-open when all segments errored).

## Related

- [043](043-[fixed]-dead-cache-full-auto-reresolve.md) — dead-cache full Auto re-resolve (post-open recovery)
- [054](054-[fixed]-vidsrc-cloudstream-referer-blocks-segments.md) — Referer/Origin on CloudStream segments
- [Direct streaming](../../features/movies-tv/direct-streaming-mode.md)
