# RFC-089: Pack-contributed Addon settings

**Status:** fixed  
**Depends on:** [RFC-086](fixed/086-[fixed]-addons-packs-feature-vs-navbar.md) · [RFC-087](fixed/087-[fixed]-live-sports-pack-only.md)  
**Area:** plugin manifests, Settings → Addons, `shared/foundation/services/`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** components · **8 / 8** acceptance |
| **Current slice** | **Complete** — manifest `settings` + host renderer + Live Sports merge toggle |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R89-C01 | Parse plugin `settings` on `EnginePlugin` + `PackAddonSettingsSpec` | ✅ |
| 2 | R89-C02 | `PackSettingsStore` (prefs keyed by pluginId + fieldId) | ✅ |
| 3 | R89-C03 | `PackAddonSettingsSection` appended in Addon detail bodies | ✅ |
| 4 | R89-C04 | Live Sports hub declares `mergeMatchingEvents`; host toggle removed | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R89-A01 | Manifest `settings.addon` + `fields[]` round-trip on `EnginePlugin` | ✅ |
| 2 | R89-A02 | Enabled plugin with `settings.addon: live_sports` shows fields under Addons → Live Sports | ✅ |
| 3 | R89-A03 | Field types `toggle` / `select` / `text` persist via `PackSettingsStore` | ✅ |
| 4 | R89-A04 | Live Sports hub pack declares `mergeMatchingEvents` (default false) | ✅ |
| 5 | R89-A05 | Host no longer renders Merge matching events toggle; config reads pack store (+ legacy migrate) | ✅ |
| 6 | R89-A06 | Capability `settings` present when block declared | ✅ |
| 7 | R89-A07 | Feature docs + changelog describe pack Addon settings | ✅ |
| 8 | R89-A08 | Host tests use synthetic plugin fixtures only | ✅ |

---

## Summary

Plugins declare typed settings that appear **inside** an existing Addons detail. Addon rows stay a fixed host list. Packs do not invent top-level Addon rows in this slice.

### Manifest (v1)

```json
"settings": {
  "addon": "live_sports",
  "group": "Live Sports",
  "order": 20,
  "fields": [
    {
      "id": "mergeMatchingEvents",
      "type": "toggle",
      "label": "Merge matching events",
      "subtitle": "…",
      "default": false
    }
  ]
}
```

Field types: `toggle` · `select` · `text`. Prefs: `pack_setting_v1_<pluginId>_<fieldId>`.

### Shipped

- `EnginePlugin.settings` parse/serialize
- `PackAddonSettingsSpec` / `PackSettingsStore`
- `PackAddonSettingsSection` appended from `buildAddonDetailBody`
- `plugins/hubs/live_sports` v1.0.4 — `mergeMatchingEvents` + capability `settings`
- `LiveMatchesIptvSportsConfig.load` migrates legacy JSON merge flag into pack store

### Related

- [RFC-087](087-[fixed]-live-sports-pack-only.md) — Live Sports pack-only
- [Addons overview](../../features/settings/overview.md)
- [Forja Sports](../../features/settings/forja-sports.md)
