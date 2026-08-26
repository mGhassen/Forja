# 209 — Forja Sports Stalker opens after minting every channel link

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Live Matches · Forja Sports · Stalker `create_link`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I209-T01 | `create_link` only the picked channel before open; siblings keep `streamId` | ✅ |
| 2 | I209-T02 | Play gen + cancellable loading so rapid taps do not stack players | ✅ |
| 3 | I209-T03 | Player Stalker refresh falls back to armed Forja Sports portal (failover / reconnect) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I209-A01 | Stalker Forja Sports: pick one channel → player opens after a single `create_link` (not N sequential) | ⬜ |
| 2 | I209-A02 | Tap channel A then B while A is still linking → only B’s player opens (no stacked players) | ⬜ |

---

## Summary

Opening a Forja Sports channel on a **Stalker** portal called `create_link` for **every** matched channel before `IptvPtPlayerScreen.open`. Each link can take seconds (up to ~20s timeout), so the UI looked dead; rapid re-taps queued multiple opens and stacked players when they finished.

**Root cause:** `_resolveIptvSportsPlayUrls` looped the full source list. The player already knows how to mint Stalker links on open/switch when it has a portal + `streamId`, but Forja Sports opens without `channelGuide`, so pre-resolving everything was used as a blunt workaround.

**Root fix:** mint only the picked channel before open; leave sibling rows with empty URL + `streamId`; cache the armed sports portal on the player for `_refreshStalkerPlayUrl` failover/reconnect; bump `_iptvSportsPlayGen` so a newer tap aborts stale opens.

**Related:** [Forja Sports](../../features/settings/forja-sports.md) · [IPTV Stalker](../../features/live/iptv-stalker.md)
