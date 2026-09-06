# 222 — Android TV Features empty after hub pack install

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** Settings → Features · `PluginNavRegistry` · Android TV

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I222-T01 | Features `_load` awaits `PluginNavRegistry.refresh` and unions `featureTabIds()` into order | ✅ |
| 2 | I222-T02 | `settingsNavigationProvider` invalidates on `EngineService.changeNotifier` (pack install) | ✅ |
| 3 | I222-T03 | `ensureNavIdsKnown` bumps `navbarChangeNotifier` when first-seen hubs change visible | ✅ |
| 4 | I222-T04 | `listNavHubs` accepts a valid `nav` block without requiring the `nav` capability string | ✅ |
| 5 | I222-T05 | Features refresh uses `notify: false` so navbar bumps cannot cancel the in-flight Features load | ✅ |
| 6 | I222-T06 | Stop Features↔MainScreen concurrent `refresh` storm (serialize refresh; Features only scans when dests empty) | ✅ |
| 7 | I222-T07 | Features paints host-core immediately; hub scan background; lean pack enable downloads scripts | ✅ |

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
4. Features `_load` watched `navbarRevisionProvider` while `refresh()` bumped that notifier (first-seen hubs / dest changes) — Riverpod cancelled the in-flight load so Features stayed Settings-only on ATV.
5. A follow-up `notify: false` + pack `invalidateSelf` still raced MainScreen’s concurrent `refresh` on static dest maps → endless navbar bumps and Features reload spam until the app died.

**After:** Features only scans hubs when destinations are empty; `PluginNavRegistry.refresh` is single-flight; stripped hub visibility is restored when no VOD hub is visible; host-core tabs always appear in the Features list.

**Related:** [221](221-[open]-features-home-toggle-reverts-after-cloud-sync.md) · [220](220-[open]-live-sports-addon-nav-without-hub-pack.md) · [RFC-081](../rfc/fixed/081-[fixed]-host-only-platform-nav-defaults.md)

## Verify

1. Android TV (or desktop): install ForjaHQ Home + Anime hubs.
2. Open **Settings → Features** — Home / Anime rows appear (on after first-seen).
3. Cold start with packs already installed — Features lists hubs; IPTV / Live Sports only if those Addons are on.
