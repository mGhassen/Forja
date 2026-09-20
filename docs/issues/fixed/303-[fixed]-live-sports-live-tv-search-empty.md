# Issue 303: Live Sports Live TV channel search empty

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Live Sports · Live TV · IPTV `searchChannels` · flutter_js nest

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 1** acceptance |
| **Current slice** | Host bridge + nested shelf match |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I303-T01 | Force `liveTv` onto flutter_js host-bridge allowlist (EngineJS empty envelope no longer wins) | ✅ |
| 2 | I303-T02 | Nested `plugin.run(searchChannels)` uses host portal shelf match (no second JSC fork / deadlock) | ✅ |
| 3 | I303-T03 | IPTV pack `searchChannels` pages through full `catalog_page` hits | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I303-A01 | Live Sports → match → Live TV shows portal channels for the fixture when Forja Sports + portal are set | ✅ |

---

## Summary

**Symptom:** Live TV tab stayed empty / stuck on **Matching Live TV…** after recent hub + catalog_page work.

**Root:**

1. `liveTv` was missing from `runCatalog` host-bridge actions — EngineJS ran without `ctx.host.plugin`, returned `hubOk({ sources: [] })`, and that empty envelope stuck (no flutter_js fallback).
2. When flutter_js did run Live Sports `liveTv` → `plugin.run(iptv, searchChannels)`, nested `runCatalog` waited on the same flutter_js mutex the outer extract held → deadlock until timeout → empty.

**Fix:** Allowlist `liveTv` for flutter_js; nested `searchChannels` matches on the host portal shelf (`PortalLiveTvSearch`); pack `searchChannels` paginates shelf hits.

**Symptom fix:** Live TV rows populate again.  
**Root fix:** Done (bridge allowlist + nest path).  
**Workaround:** No.
