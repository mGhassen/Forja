# 038 — WebStreamr Resolver Engine drops country config

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** playback / webstreamr  
**Reported:** 2026-07-14

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I38-T01 | Pass `WebStreamrSettings` country/MFP config into ResolverEngine resolve request | ✅ |
| 2 | I38-T02 | Expand Rust `default_config` to all countries (parity with Dart defaults) | ✅ |
| 3 | I38-T03 | Reject relative / `demo-video` sniff URLs before host resolve success | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I38-A01 | Live probe: Witch Part 2 (`tt13721828`) returns KinoGer FSST when countries enabled | ✅ |
| 2 | I38-A02 | Unit: `buildRequest` includes `webstreamrConfig.de`; sniffer rejects `/demo-video.mp4` | ✅ |

---

## Summary

Play opened via ResolverEngine → `WebstreamrProvider` with hard-coded `"config": {}`. Rust treated empty config as **multi+en only**, so DE sources (KinoGer / MegaKino) never ran — Playtorrio showed those streams; Forja did not. Separately, WebView sniffs accepted `/demo-video.mp4` as a successful extract.

### Root fix

- `ResolveSettings.webstreamr_config` + TMDB token from Dart prefs on every resolve
- `webstreamr::default_config()` enables all countries like `WebStreamrSettings.defaultCountryCodes`
- `StreamExtractor` / `HostProviderAdapter` reject unplayable placeholder URLs
