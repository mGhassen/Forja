# 222 — Android TV Features empty after hub pack install

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** Settings → Features · `PluginNavRegistry` · Android TV

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I222-T01 | Features `_load` awaits `PluginNavRegistry.refresh` and unions `featureTabIds()` into order | ✅ |
| 2 | I222-T02 | `settingsNavigationProvider` invalidates on `EngineService.changeNotifier` (pack install) | ✅ |
| 3 | I222-T03 | `ensureNavIdsKnown` bumps `navbarChangeNotifier` when first-seen hubs change visible | ✅ |
| 4 | I222-T04 | `listNavHubs` accepts a valid `nav` block without requiring the `nav` capability string | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I222-A01 | ATV: install Home / Anime / Asian Drama / My List packs → Settings → Features lists those tabs (plus IPTV / Live Sports) | ⬜ |
| 2 | I222-A02 | Fresh Features open with no packs still lists IPTV + Live Sports (off), not Settings-only | ⬜ |

---

## Summary

**Symptom:** After installing hub packs under **Forja Packs** on Android TV, **Settings → Features** showed only the locked **Settings** row — no Home / Anime / Asian Drama / My List (and no IPTV / Live Sports toggles).

**Root cause:**

1. Features built its list from prefs/`allNavIds` filtered by `isContributed` **without** awaiting hub `nav` refresh when the page opened.
2. Pack install could update destinations / first-seen visibility without notifying Features (`ensureNavIdsKnown` wrote KV but did not bump the navbar notifier when destinations were unchanged vs cache).
3. Hub contribution required `capabilities` to include `"nav"` — stored packs with a valid `nav` object but empty/missing capability were skipped.

**After:** Features refreshes pack nav on load, always unions host-core + contributed hub tab ids, reloads when packs change, and notifies when first-seen hubs are auto-shown.

**Related:** [221](221-[open]-features-home-toggle-reverts-after-cloud-sync.md) · [220](220-[open]-live-sports-addon-nav-without-hub-pack.md) · [RFC-081](../rfc/fixed/081-[fixed]-host-only-platform-nav-defaults.md)

## Verify

1. Android TV (or desktop): install ForjaHQ Home + Anime hubs.
2. Open **Settings → Features** — Home / Anime rows appear (on after first-seen).
3. Cold start with packs already installed — Features still lists hubs + IPTV + Live Sports.
