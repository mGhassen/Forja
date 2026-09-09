# 252 — IPTV portal + channel status checks show red for everything

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** IPTV catalog · portal health · live stream alive probe  
**Reported:** 2026-09-09

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I252-T01 | Portal health: drop hardcoded 5s probe; use 15s Xtream/Stalker / 90s M3U | ✅ |
| 2 | I252-T02 | Rust/admin/worker: broaden `xtream_user_auth_ok` (true/enabled + account-shaped blobs; keep Banned/Expired red) | ✅ |
| 3 | I252-T03 | Stream probe: async on engine runtime (no per-probe `Runtime::new`); early TS/playlist accept | ✅ |
| 4 | I252-T04 | Bulk alive recheck: concurrency 24 → 3; skip while player holds a seat | ✅ |
| 5 | I252-T05 | Changelog + feature doc auth wording | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I252-A01 | Active Xtream portal that plays/catalogs paints green on IPTV tab open / Portals hover | ⬜ |
| 2 | I252-A02 | Hover a playable live channel (player closed) → green border/dot; Re-check all does not paint the whole grid red on a 1-seat Mag panel | ⬜ |

---

## Summary

Portal dots and live channel borders both fail closed. Two independent bugs made **working** portals/channels look dead:

1. **Portal** — health used a **5s** login timeout (slow Mag → transport red) and auth required exactly `auth=1` / `status=Active`. Mag forks that return `auth: true`, `status: Enabled`, or a full account blob without those fields stayed red while disk-cached catalog + play still worked.
2. **Channels** — bulk “Re-check all streams” ran **24** parallel probes, each spinning a **new Tokio runtime** inside `spawn_blocking`. Connection-limited panels + runtime storm → almost every stream `alive: false`. Lazy hover was better (concurrency 2) but still waited for 16KiB before accepting MPEG-TS, so slow live starts timed out red.

**Root fix:** shared async probe path, early TS/playlist success, low bulk concurrency, skip bulk while playing, wider portal auth + sane timeouts.

### Related

- [144](../144-[open]-iptv-catalog-stream-health-never-reprobes.md) — re-probe TTL (separate)
- [RFC-075](../../rfc/fixed/075-[fixed]-iptv-portal-probe-detail.md) — structured portal probe
- [iptv-xtream](../../features/live/iptv-xtream.md)
