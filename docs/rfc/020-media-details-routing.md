# RFC-020: Media details routing

**Version:** v1.1  
**Status:** Not started

## Summary

Move app-wide media detail routes out of `features/home/` into a dedicated `features/media/` module. Navigation stays centralized in [`AppRouter`](../../apps/forja/lib/shell/app_router.dart).

## Problem

[`details_screen.dart`](../../apps/forja/lib/features/home/details_screen.dart) and [`streaming_details_screen.dart`](../../apps/forja/lib/features/home/streaming_details_screen.dart) live under Home but are used from Discover, Search, My List, Similar, shared widgets, and Stremio catalog.

This violates RFC-001 intent: Home is a browse tab, not the owner of global routes.

**Current mitigations (shipped):**
- Cross-feature navigation goes through `AppRouter.openMovie` / `openDetails` / `openStreamingDetails`
- Features no longer import detail screens directly (except Home internals)

**Remaining issue:** file location and mental model — "edit details" means opening `features/home/`.

## Goals

- Clear module: `features/media/` owns detail + streaming detail screens
- `AppRouter` remains the only public entry for other features
- Home keeps browse-only code (hero, rails, Stremio blocks)

## Target layout

```
features/media/
  details_screen.dart
  streaming_details_screen.dart
  stremio_catalog_screen.dart   # optional move from home/
  widgets/
    loading_overlay.dart        # if only used by media (else stay shared)
```

Home retains:

```
features/home/
  home_screen.dart
  home_hero.dart
  home_rails.dart
  ...
```

## AppRouter (unchanged API)

```dart
class AppRouter {
  static Future<T?> openDetails(BuildContext context, { required Movie movie, ... });
  static Future<T?> openStreamingDetails(BuildContext context, { required Movie movie, ... });
  static Future<T?> openMovie(BuildContext context, { required Movie movie, ... });
  static Future<T?> openPlayer(...);
}
```

Implementation imports move from `features/home/` to `features/media/` — call sites unchanged.

## Migration steps

1. Create `features/media/` directory
2. Move `details_screen.dart`, `streaming_details_screen.dart` (git mv)
3. Update imports inside moved files (relative paths, shell, shared, engines)
4. Update `app_router.dart` imports only
5. Move `stremio_catalog_screen.dart` if it is route-like (optional same PR or follow-up)
6. Grep for `features/home/details` — should be zero outside home + media
7. `flutter analyze` + smoke: open details from Home, Discover, Search, My List

## Feature boundary rules (enforced)

| Layer | May import media screens? |
|-------|---------------------------|
| `shell/app_router.dart` | yes |
| `features/home/` | yes (same-app routes via router preferred) |
| Other features | **no** — use AppRouter only |
| `shared/widgets/` | **no** — use AppRouter only |

## Future: deep links

Optional v1.2 extension:

```
forja://movie/tmdb/12345
forja://tv/tmdb/67890/1/3
```

Handler in `app/bootstrap.dart` or `shell/deep_link_handler.dart` → `AppRouter.openDetails`. Not required for this RFC.

## Acceptance

- [ ] No `details_screen` or `streaming_details_screen` under `features/home/`
- [ ] `AppRouter` is sole importer of media screens from outside `features/media/`
- [ ] Discover, Search, My List, Similar still open details correctly
- [ ] Torrent + Stremio + streaming paths unchanged functionally

## Related

RFC-001, RFC-019 (split details sub-files after move), RFC-016/017/018 (independent)
