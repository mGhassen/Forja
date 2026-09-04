# RFC-077: Brstej hub + Laroza-only Arabic

**Status:** fixed  
**Depends on:** RFC-070 (catalog hub protocol), RFC-076 (كرتون / DimaToon hub)  
**Area:** `plugins/hubs/brstej/`, `plugins/hubs/arabic/`, host nav asset map

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** components · **7 / 7** acceptance |
| **Current slice** | Shipped — Arabic pack Larozaa-only (no legacy Brstej/DimaToon details) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R77-C01 | ForjaHQ Brstej hub pack (`brstej-hub`, tab Brstej) | ✅ |
| 2 | R77-C02 | Arabic hub: Larozaa-only browse/search/feed (no Brstej rails/search) | ✅ |
| 3 | R77-C03 | Host `forja://asset/nav/brstej` Material fallback | ✅ |

---

## Acceptance (hub split)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R77-A01 | Nav tab **Brstej** (`tabId: brstej`) from pack `nav`, default off | ✅ |
| 2 | R77-A02 | Brstej feed/rails browse `uo.brstej.com` series; search groups episodes → shows | ✅ |
| 3 | R77-A03 | Brstej details list episodes with `brstej:watch:` playable ids | ✅ |
| 4 | R77-A04 | Play uses **brstej** provider only (no Larozaa race on Brstej meta) | ✅ |
| 5 | R77-A05 | Arabic hub layout/feed/search call **Larozaa only** | ✅ |
| 6 | R77-A06 | كرتون remains DimaToon-only; Arabic keeps legacy `dimatoon:` / `brstej:` details for old history ids | ✅ |
| 7 | R77-A07 | Arabic pack drops legacy `dimatoon:` / `brstej:` details/stream — foreign ids fail; use Brstej / كرتون packs | ✅ |

---

## Summary

Arabic cinema was one hub scraping **Larozaa** + **Brstej** (+ formerly DimaToon). كرتون already owns DimaToon (RFC-076). Split Brstej into its own hub so each tab maps 1:1 to one upstream + one provider:

| Hub tab | Pack | Provider |
|---------|------|----------|
| Arabic | `arabic-hub` | `larozaa` |
| Brstej | `brstej-hub` | `brstej` |
| كرتون | `dimatoon-hub` | `dimatoon` |

### Goals

- One Brstej catalog tab (label **Brstej**)
- Arabic rows/search/play path only Larozaa
- Reuse host `open.surface: arabic` + `resolveType: arabic` (no new host surface)

### Out of scope

- TMDB enrich for Brstej
- New host `surface` name
- Embedding / WebView playback
