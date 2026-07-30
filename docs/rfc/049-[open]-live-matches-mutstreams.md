# RFC-049: Live Matches — MutStreams catalog

**Status:** open  
**Depends on:** —  
**Area:** live / Live Matches catalog

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** components · **4 / 5** acceptance |
| **Current slice** | MutStreams server + mirror failover + Streamed-family embed playback |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R49-C01 | Rust `mut_matches` — `/api/streams` flatten + official mirror failover | ✅ |
| 2 | R49-C02 | Host `_LiveMatchesServer.mutStreams` + inline embed open path | ✅ |
| 3 | R49-C03 | Feature docs + changelog | ✅ |

---

## Acceptance (catalog slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R49-A01 | Servers sheet lists MutStreams (`mut.st`) | ✅ |
| 2 | R49-A02 | Engine tries mirrors (`mut.st` → `mutstreams.st` → `.ch` → `.pk`) until JSON parses | ✅ |
| 3 | R49-A03 | Matches with sources open via embed.st using Mut catalog wrapper | ✅ |
| 4 | R49-A04 | Unit tests: time parse + flatten + HTML reject | ✅ |
| 5 | R49-A05 | Manual smoke: MutStreams list + play one live embed (desktop or Android) | ⬜ |

---

## Summary

Add [MutStreams](https://mut.st/) as a fourth Live Matches catalog server. Schedule comes from `GET /api/streams` (category groups with inline `sources[].embedUrl`). Official mirrors are listed on [mutgo.link](https://mutgo.link/); Forja hardcodes the mirrors that currently return JSON (skips HTML-only hosts).

Playback reuses the Streamed-family embed path (`embed.st` → `strmd` CDN) with `mut.st` as the catalog iframe wrapper / Referer. Mut is **not** merged into **All** in this slice (heavy overlap with Streamed/PPV).

### Goals

- Browse MutStreams sports schedule inside Live Matches
- Survive domain churn via sequential mirror try
- Play embeds with the existing Live Matches WebView / Android handoff

### Non-goals (this slice)

- Scraping mutgo.link at runtime for mirror discovery
- Merging Mut into All / PPV–Streamed dedupe
- Multi-stream / watch-page HTML scrape (API already returns embeds)
