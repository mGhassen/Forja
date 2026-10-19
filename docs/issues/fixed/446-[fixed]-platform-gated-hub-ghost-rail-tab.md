# 446 — Platform-gated hub still paints a nav tab

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Shell nav · RFC-120 · Android TV  
**Related:** [RFC-120](../../rfc/120-[open]-pack-plugin-platform-gating.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I446-T01 | Track installed hub tab ids gated by manifest `platforms` in `PluginNavRegistry` | ✅ |
| 2 | I446-T02 | MainScreen rail paint skips those ids without rewriting Features KV | ✅ |
| 3 | I446-T03 | Unit test for paint-only gated set + changelog / feature guide | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I446-A01 | Android TV: Downloads pack installed and on, tagged **not on this device** → no Downloads (or blank grid) tab on the nav rail | ⬜ |

---

## Summary

Downloads (and any hub with `platforms` excluding `tv`) correctly left rail destinations, but Features `visibleIds` still listed the tab for cross-device sync. MainScreen painted the rail from that list and refused a blanket `isContributed` filter (issue 224), so Android TV kept a ghost tab (often a Material grid glyph).

**Root:** destination gate without a paint-path filter for platform-gated hubs.

**Fix:** resolve gated hub tab ids from the installed pack index; filter them out of rail paint only. Synced Features KV is unchanged so desktop/phone keep the tab.
