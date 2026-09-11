# Host lists / follow (RFC-106 G11 evacuate)

My List product (Simkl sync, catalog source, follow writes) lives here.

## Layout

| Path | Notes |
|------|--------|
| `list_follow.dart` / `list_follow_from_watched.dart` | Follow write path |
| `list_providers.dart` / `external_list_providers.dart` | Riverpod + Simkl providers |
| `my_list_*.dart` | Hub catalog source / merge / open / boot |
| `kit_list_status_button.dart` | Wired status pin (data + Simkl) |

## Stays in foundation (presentational)

`components/chrome/kit_list_status_pin.dart` — ListStatus chrome only (RFC-095).
`components/hero/kit_list_status_hero.dart` — still imports host follow via shim;
evacuate later if needed.

## Compatibility shims

Old `shared/foundation/services/follow/**` paths re-export from here until G14-E.
Prefer `package:forja/shared/host/lists/...` for new code.
