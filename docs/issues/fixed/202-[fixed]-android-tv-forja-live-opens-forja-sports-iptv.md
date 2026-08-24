# 202 — Android TV Forja Live opens Forja Sports IPTV panel

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Live Matches · Forja Live · `live_matches_playback.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I202-T01 | TV `_openStreamedMatch` / merged / PPV: Forja Live → `_openForjaLiveTvSources`, never `_openTvNativeSourcesOnly` | ✅ |
| 2 | I202-T02 | `_openForjaLiveTvSources`: resolve engine plugin streams into Sources panel (Forja Live badge) | ✅ |
| 3 | I202-T03 | Panel empty / searching copy supports Forja Live (“No streams available”) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I202-A01 | ATV Live Sports → Forja Live → open live card → Sources rows are Forja Live plugin streams (no Forja Sports / Teen Titans Xtream noise) | ⬜ |
| 2 | I202-A02 | ATV Forja Sports still opens Xtream channel panel as before | ⬜ |

---

## Summary

Leanback gated every non-Stremio open through `_openTvNativeSourcesOnly`, which only resolves **Forja Sports** Xtream (+ Stremio). Opening a **Forja Live** card therefore showed IPTV channels (fuzzy “Titans” → 24/7 Teen Titans).

**Root fix:** when server is Forja Live on TV, resolve catalog/plugin streams into the same Sources side panel with **Forja Live** labels and play via the live engine path.
