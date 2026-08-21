# RFC-062: Native IPTV sports matching in Live Matches

**Status:** open  
**Depends on:** [051](051-[open]-iptv-multi-protocol-portals.md) (Xtream portals)  
**Area:** Live Matches / IPTV

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **13 / 13** acceptance (Xtream incl. ESPN∪All merge + 30m match cache) · **0 / 3** acceptance (M3U deferred) |
| **Current slice** | Forja Sports = All catalog ∪ ESPN scoreboard + Xtream match on play (30m channel cache) — M3U/XMLTV deferred |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R62-C01 | ESPN scoreboard fetch + game model in `crates/live-matches` | ✅ |
| 2 | R62-C02 | Sportio 4-tier name/EPG matcher + foreign-team exclusion (Rust) | ✅ |
| 3 | R62-C03 | Xtream candidate pipeline (live streams + short EPG) | ✅ |
| 4 | R62-C04 | Settings: portal, timezone, leagues, per-league category map | ✅ |
| 5 | R62-C05 | Live Matches **My IPTV** server + native HLS playback | ✅ |

---

## Acceptance (Xtream slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R62-A01 | Configure portal + leagues + categories in Settings | ✅ |
| 2 | R62-A02 | Live Matches Servers lists **My IPTV**; loads today's ESPN games | ✅ |
| 3 | R62-A03 | Play match → ranked Xtream HLS via native IPTV player | ✅ |
| 4 | R62-A04 | Tier matcher: 4K+both, both-in-name+desc, both-combined, nickname+foreign exclude | ✅ |
| 5 | R62-A05 | Word-boundary match avoids Red vs Reds false positive (unit test) | ✅ |
| 6 | R62-A06 | Kickoff from ESPN `date`; grid/timeline chronological | ✅ |
| 7 | R62-A07 | Not merged into **All** (own server only) | ✅ |
| 8 | R62-A08 | Feature doc + changelog | ✅ |
| 9 | R62-A12 | Live Matches **My IPTV** top-bar Portals picker (same config as Settings) | ✅ |
| 10 | R62-A13 | My IPTV uses All catalog (PPV/Streamed/CDN); play matches Xtream channels | ✅ |
| 11 | R62-A14 | Play match → sheet lists matched IPTV channels; pick one then native player | ✅ |
| 12 | R62-A15 | My IPTV catalog = All ∪ ESPN; enrich teams from ESPN; ESPN-only cards playable | ✅ |
| 13 | R62-A16 | Matched IPTV channels cached 30 min per match+portal (no re-search on re-open) | ✅ |

---

## Acceptance (M3U / XMLTV — deferred)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R62-A09 | M3U playlist + XMLTV programme index for candidate EPG | ⏭️ |
| 2 | R62-A10 | `extractRealDate` + closest-programme pick per Sportio | ⏭️ |
| 3 | R62-A11 | Background EPG cache (no UI-thread / per-tap parse) | ⏭️ |

---

## Summary

Port [Sportio Live](https://github.com/Sportio-Live/sportio-live)'s ESPN ↔ IPTV channel matcher **on-device** into Forja. No Docker, no Stremio addon URL, no Forja-hosted Sportio.

Sportio does not provide streams — it bridges ESPN's public scoreboard with the user's own Xtream/M3U live channels via a 4-tier name/EPG matcher. Forja already stores IPTV portals and plays HLS natively; this RFC wires that into Live Matches as **Forja Sports** (shipped UI name; earlier docs said My IPTV).

### Goals

- ESPN schedule for configured leagues (timezone-aware "today")
- Reuse saved Xtream portal + live category mapping
- Port Sportio tier logic faithfully (word-boundary, nicknames, foreign-team exclusion)
- Play matched `.m3u8` in `IptvPtPlayerScreen`

### Non-goals (Xtream slice)

- Self-hosted Sportio / Stremio `sports` type fix
- SVG matchup art generator
- M3U XMLTV programme parse (R62-A09–A11)
- Multi-portal cascade
- Cloud sync of sport-match settings

### Contracts

**Engine actions** (`liveMatchesFetchJson`):

| Action | Input | Output |
|--------|-------|--------|
| `sport_match_games` | `leagues[]`, `date` (YYYYMMDD) | `{ items: [game…] }` |
| `sport_match_streams` | game fields + `xtream` + `category_ids[]` | `{ items: [stream…] }` ranked by tier |

**Settings key:** `live_matches_iptv_sports_v1` — `{ enabled, portalKey, timezone, leagues, sportCategories }`.

**Settings hub:** own category **Forja Sports** (not under Data & backup).
