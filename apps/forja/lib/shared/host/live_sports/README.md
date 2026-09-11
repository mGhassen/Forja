# Host live sports (RFC-106 G11 evacuate)

**Status:** domain files moved here from `shared/foundation/` (G11 slice).

MatchEvent, schedule services, live-sports chrome, and related product code
live under this folder so `packages/forja_foundation` stays design-only.

## Layout

| Path | Notes |
|------|--------|
| `match_event.dart` | MatchEvent model |
| `match_team_parse.dart` | Team/title parse helpers |
| `schedule_sport_filter.dart` | Sport filter |
| `stremio_live_meta.dart` | Stremio live meta helpers |
| `embed_webview_proxy.dart` | Embed proxy (host-owned) |
| `live_surface_open.dart` | Live open surface |
| `kit_match_details_page.dart` | Match details page host |
| `kit_category_circle_meta.dart` | Sport category circle meta |
| `schedule/**` | Schedule prefs, window, filters, layout, live boot, merge upgrade |
| `chrome/kit_schedule_*.dart` | Schedule search / view / window chrome |

## Compatibility shims

Old import paths under `shared/foundation/` re-export from here until G14-E cutover.
Prefer `package:forja/shared/host/live_sports/...` for new code.

## Remaining kit.list entanglement

MatchEvent cards / viewers / grid metrics go through
[`KitListLiveCards`](kit_list_live_cards.dart) → [`KitListHostHooks`](../../foundation/services/registry/kit_list_host_hooks.dart).

| Still in kit | Why |
|--------------|-----|
| Dense list chrome (`KitEventDenseTile`) | Generic props-only row (host card via stub) — viewers via `entryViewers` hook |
| Poster grid / panel split | Generic kit |

Cards live under `host/live_sports/cards/`.

## Related evacuate targets

`host/packs/**`, `host/lists/**` — done this slice. Still open: `services/watch/**`,
torrent/Simkl UI, TMDB host fetch in details/hero — see RFC-106 / plan G11.
