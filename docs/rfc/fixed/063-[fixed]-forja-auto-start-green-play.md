# RFC-063: Forja auto start (green Play)

**Status:** fixed  
**Depends on:** [RFC-060](060-[fixed]-enginejs-sources-forja-tab.md)  
**Area:** Settings Playback, media details hero Play, Forja engine plugins

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** components · **7 / 7** acceptance |
| **Current slice** | Setting + green Play race; probe before open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R63-C01 | Pref `play_source_engine_auto_start` + Settings → Playback toggle under Forja | ✅ |
| 2 | R63-C02 | Green Play when Forja auto on and Webstreaming off; WS wins when both on | ✅ |
| 3 | R63-C03 | Loading overlay races all enabled Forja HTTP plugins; first playable stream opens | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R63-A01 | Forja auto start default off — Sources-only Forja when unchecked | ✅ |
| 2 | R63-A02 | Auto races every enabled Forja HTTP plugin (same set as Select-all enabled) | ✅ |
| 3 | R63-A03 | First playable stream from any plugin opens ASAP; remaining extracts cancel | ✅ |
| 4 | R63-A04 | Webstreaming on → green Play stays webstreaming; Forja auto ignored | ✅ |
| 5 | R63-A05 | Webstreaming off + Forja + auto → green Play runs Forja race | ✅ |
| 6 | R63-A06 | Feature docs + changelog | ✅ |
| 7 | R63-A07 | Auto probes each stream URL before open; dead first CDN does not cancel other plugins | ✅ |

---

## Summary

With Webstreaming off, green Play disappeared because it was gated on that play source. Users who rely on Forja plugins need the same one-tap path: loading overlay, scrape, play first hit — without opening Sources.

### Goals

- Nested **Forja auto start** under the Forja play-source toggle
- Green Play back when auto is on (and Webstreaming is off)
- Parallel race of enabled plugins (batch limit same as Sources Forja)

### Non-goals

- Replacing Sources manual pick when auto is off
- Changing Webstreaming Tries / Simple resolve
- Caching Forja auto extracts like webstreaming disk cache (later if needed)
