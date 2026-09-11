# Host packs (RFC-106 G11 evacuate)

Pack install UI, settings store, connected auth, and `PackAssets` live here so
`packages/forja_foundation` stays design-only.

## Layout

| Path | Notes |
|------|--------|
| `pack_assets.dart` | Resolve pack-relative logos / nav icons |
| `components/forja_pack_choice_cards.dart` | Official + community install cards |
| `components/plugin_install_progress_banner.dart` | Toast-stack install progress |
| `services/pack_*.dart` | Addon settings spec, prefs store, connected auth |

App update dialog / Keychain consent live in `host/update/` and `host/account/`.

## Compatibility shims

Old paths under `shared/foundation/components/packs/`, `services/pack/`, and
`lib/pack_assets.dart` re-export from here until G14-E cutover.
Prefer `package:forja/shared/host/packs/...` for new code.
