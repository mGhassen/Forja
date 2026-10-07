# RFC-120: Pack plugin platform gating

**Status:** open  
**Depends on:** [RFC-117](117-[open]-vod-offline-downloads.md)  
**Area:** `apps/forja` engine models · nav registry · Settings → Forja Packs · `forja-sdk` manifest schema · `forja-packs/hubs/downloads`

## Status at a glance

| | |
|--|--|
| **Progress** | **11 / 11** components · **2 / 7** acceptance |
| **Current slice** | Host gate, manifest contract, admin / web / app catalog in code — migration not applied, device QA open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R120-C01 | Manifest `platforms` (pack root + plugin) parsed into `EnginePlugin` / `EnginePack`, kept across the stored round trip | ✅ |
| 2 | R120-C02 | One host gate: `PlatformInfo.supportsPlugin` maps profile → `desktop` / `phone` / `tv` and checks the allow-list | ✅ |
| 3 | R120-C03 | `EnginePack.isPluginActive` includes the device gate, so VM load, Sources walk, search, kit open, hop / debrid / torrent paths all skip gated plugins | ✅ |
| 4 | R120-C04 | Nav registry: rail destinations and the cached nav snapshot apply the gate; the installed-hub set (`requireEnabled: false`) does not, so Features `visibleIds` are never stripped on the gated device | ✅ |
| 5 | R120-C05 | Settings → Forja Packs: gated plugin rows show **Not available on this device** with the switch locked; pack title shows **not on this device** when every plugin is gated | ✅ |
| 6 | R120-C06 | SDK: `manifest.schema.json` declares both fields; `DEVELOPING.md` has a Platform gating section | ✅ |
| 7 | R120-C07 | Downloads hub manifest declares `platforms: [desktop, phone]` (legacy `nav.hostRequires` kept for older hosts) | ✅ |
| 8 | R120-C08 | Admin validation reads root + plugin `platforms` (errors on bad values), derives the pack device set, persists it to `plugin_packs.platforms` | ✅ |
| 9 | R120-C09 | Migration adds `plugin_packs.platforms text[]` (empty = all, checked against desktop / phone / tv); DB types updated in admin and web | ✅ |
| 10 | R120-C10 | Admin Plugins table: **Devices** column + device filter | ✅ |
| 11 | R120-C11 | Web Community Packs and app Official / batch pickers carry `platforms`: web shows the device list, app picker tags packs **Not on this device** | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R120-A01 | Unit: platforms allow-list, aliases, pack → plugin inheritance, TV off / desktop + phone on, stored round trip | ✅ |
| 2 | R120-A02 | `flutter analyze` clean in `apps/forja` | ✅ |
| 3 | R120-A03 | Android TV: Downloads pack installed and on → no rail tab, no Features entry, no script load; Settings → Forja Packs row tagged, plugin switch locked | ⬜ |
| 4 | R120-A04 | Profile toggled on TV then opened on desktop keeps Downloads on (gate never writes `enabled`) | ⬜ |
| 5 | R120-A05 | A pack with `platforms: ["desktop"]` is off on phone and on on desktop with the same profile | ⬜ |
| 6 | R120-A06 | Migration applied to hosted Supabase; admin **Validate** on the Downloads pack stores `{desktop, phone}` | ⬜ |
| 7 | R120-A07 | Web catalog shows **Desktop · Phone only** on Downloads; Android TV Official picker shows **Not on this device** | ⬜ |

---

## Summary

### Problem

Some plugins only make sense on some devices. Downloads needs local storage and a file picker, which Android TV does not have. The only gate was `nav.hostRequires`, a single hard-coded string that hid the rail tab. On TV the plugin still counted as active: its script loaded, `isKitPluginEnabled` said yes, and Settings → Forja Packs showed a working toggle that did nothing. Pack authors had no way to say “desktop only” for anything else.

### Goals

1. Packs declare which devices a plugin runs on. The host evaluates it; packs never branch on device.
2. One runtime gate feeds every active-plugin path, not just the rail.
3. The gate is per device and never written into the synced `enabled` flags. A profile that has Downloads on stays on when the same account opens on desktop.
4. Settings shows the state instead of hiding the row.

### Contracts

- `platforms`: array of `desktop` · `phone` · `tv`. Pack root sets the default; a plugin list overrides it. Empty means every platform.
- `nav.hostRequires` is not read by this host. Older builds still read it to hide the tab, so the Downloads manifest keeps it for now.
- Gated plugin: installed, listed, not active. `isPluginActive` is false. `isPluginAvailable` is the gate on its own. Stored `enabled` is untouched.
- The installed-hub set used to decide “pack uninstalled → strip tab” ignores the gate. Only rail destinations and the nav cache apply it.
- Catalog: `plugin_packs.platforms` is the pack-level device set derived at admin validation (union of each plugin's effective list; any ungated plugin → empty = all). The app still gates per plugin from the installed manifest; the catalog column is display only.

### Non-goals

- Gating the JS `h.downloads` bridge itself. The Downloads plugin does not load on TV, so nothing calls it there.
- Web catalog badges for platform support.

### Related

- [RFC-117](117-[open]-vod-offline-downloads.md) — Downloads hub, R117-C09 (no Downloads UI on Android TV)
- [RFC-109](109-[open]-forja-pack-product-host.md) — host validates and paints; it never branches on pack ids
- [Forja Packs guide](../features/settings/forja-packs.md)
