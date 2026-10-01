# RFC-114: Debrid magnet-resolve packs

**Status:** open  
**Depends on:** [RFC-089](fixed/089-[fixed]-pack-addon-settings.md) · [RFC-109](109-[open]-forja-pack-product-host.md)  
**Area:** packs · playback · debrid

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** components · **12 / 12** acceptance |
| **Current slice** | Host magnet-resolve + `forjahq-debrid` pack shipped; `crates/debrid` deleted |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R114-C01 | SDK `kind: debrid` + resolve contract docs | ✅ |
| 2 | R114-C02 | Pack `forja-packs/debrid/` — RD / TorBox / AD / Premiumize / Debrid-Link | ✅ |
| 3 | R114-C03 | Host discovery + exclusive `magnet_resolve_plugin_id` + `runDebridResolve` | ✅ |
| 4 | R114-C04 | Rewrite `resolveMagnetForPlayback` + callers (no vendor names) | ✅ |
| 5 | R114-C05 | Addons Debrid shell + pack settings + SecureSettings migrate | ✅ |
| 6 | R114-C06 | Delete `crates/debrid` + FFI + `DebridApi` | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R114-A01 | Manifest `kind: debrid` validates in SDK + host `PluginContract` | ✅ |
| 2 | R114-A02 | `resolve` params `{ magnet, season?, episode?, fileIdx? }` → `{ url }` or `{ files[] }` | ✅ |
| 3 | R114-A03 | Exclusive active plugin; empty id → local torrent / LAN only | ✅ |
| 4 | R114-A04 | Selected plugin fail does not silent-fallback to local (auth fail-fast) | ✅ |
| 5 | R114-A05 | Host never hardcodes Real-Debrid / TorBox / … service switches | ✅ |
| 6 | R114-A06 | Pack settings `password` apiKey via RFC-089; keys migrate from SecureSettings once | ✅ |
| 7 | R114-A07 | Addons → Debrid lists discovered `kind: debrid` plugins only | ✅ |
| 8 | R114-A08 | Uninstall debrid pack → magnets still play via local/LAN | ✅ |
| 9 | R114-A09 | `crates/debrid` + `ffi_debrid_request_json` + `DebridApi` removed | ✅ |
| 10 | R114-A10 | Host tests use synthetic debrid plugin ids only | ✅ |
| 11 | R114-A11 | Feature doc + changelog describe pack-owned debrid | ✅ |
| 12 | R114-A12 | Pack product copy has no migration / formerly language | ✅ |

---

## Summary

Debrid vendors leave the Rust engine and first-party Settings key UI. One pack (`forjahq-debrid`) ships one JS plugin per service. Host keeps a thin magnet fork: if an exclusive active `kind: debrid` plugin is set, pack resolve runs; else librqbit / LAN.

### Contract

| | |
|--|--|
| **Kind** | `debrid` (URL tree `…/debrid/manifest.json`) |
| **Action** | `resolve` |
| **In** | `{ magnet, season?, episode?, fileIdx? }` |
| **Out** | `{ url, headers?, name? }` or `{ files: [{ name, url, size? }] }` |
| **Prefs** | `magnet_resolve_plugin_id` (empty = off) |

### Out of scope

Racing multiple debrid plugins; per-vendor packs; moving librqbit into a pack; RFC-110 `player.magnetResolve` slot (map later).
