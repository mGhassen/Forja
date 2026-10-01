# Issue 364: Live Sports Live TV misses portal channels

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · Live TV · `sport_match_streams` · portal match

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 1** acceptance |
| **Current slice** | Restore Rust matcher on host nest path |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I364-T01 | Nested `searchChannels` calls Rust `sport_match_streams` (fast + EPG batches) instead of catalog_page `q` | ✅ |
| 2 | I364-T02 | Live Sports row shape keeps `broadcastChannels` on `sportMatchGame` / paint props | ✅ |
| 3 | I364-T03 | Host unit tests for fixture key + broadcast token overlap | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I364-A01 | Match with guide channel names shows those IPTV portal channels on Live TV (Forja Sports + portal set) | ✅ |

---

## Summary

**Symptom:** Live Sports → match → **Live TV** often empty or missing channels that the portal clearly has (regression after last release).

**Root:** Issue [303](fixed/303-[fixed]-live-sports-live-tv-search-empty.md) fixed the nest deadlock by matching on the host shelf with catalog `q` + simple name contains. That skipped the engine matcher (`sport_match_streams`: strong broadcast hints, EPG confirmation, team aliases). Team-name catalog searches rarely hit IPTV channel titles (`beIN Sports 1`), so hits depended on brittle exact `q` substrings.

**Fix:** `PortalLiveTvSearch` calls Rust `sport_match_streams` again (same path as the former `IptvChannelSearch`). Pack feed keeps `broadcastChannels` on the game map for the nest call.

**Symptom fix:** Live TV rows populate for guide / EPG matches again.  
**Root fix:** Done (engine matcher on nest path).  
**Workaround:** No.

**Related:** [303](303-[fixed]-live-sports-live-tv-search-empty.md) · [RFC-096](../../rfc/fixed/096-[fixed]-iptv-channel-search-only.md) · [RFC-062](../../rfc/fixed/062-[fixed]-native-iptv-sports-matching.md)
