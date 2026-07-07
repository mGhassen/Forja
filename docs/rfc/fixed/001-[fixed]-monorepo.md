# RFC-001: Monorepo + feature boundaries

**Version:** v1.0  
**Status:** fixed  
**Target version:** [0.0.1](../backlog/done/0.0.1-[done].md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** acceptance (v1.0) |
| **Backlog** | [0.0.1](../backlog/done/0.0.1-[done].md) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---


## Summary

Forja is a melos monorepo: one Flutter app, six engine packages, feature folders per nav tab.

## Layout

```
apps/forja/
  lib/app/           bootstrap, lifecycle
  lib/shell/         MainScreen, nav_config, AppRouter, ShellBus
  lib/features/      one folder per nav tab (19 + settings)
  lib/shared/        player, widgets, Phase 3 stubs
packages/
  core/              models, utils
  storage/           settings, theme, prefs repos
  api/               HTTP clients, services (MyListService, BookProgressService)
  streaming/         torrent, proxy, provider registry
  webstreamr/        webstreamr pipeline
  scrapers/          torrent index scrapers
  rust/              Dart FFI bindings to Rust engine
```

## Dependency rules

```
apps/forja → packages/* only
features/* → engines + shared + shell (AppRouter, ShellBus)
packages/* → never import apps/forja
api → storage → core
streaming → webstreamr, scrapers, core, api
```

No circular deps: `storage` must not depend on `api`.

## Navigation rules

- Cross-feature routes use `shell/app_router.dart` (`openMovie`, `openPlayer`, etc.)
- Tab switching uses `shell/shell_bus.dart` (`requestTab`, `stremioSearchNotifier`)
- Features must not import other features' screens directly

## Repository pattern

- Widgets call services/repos, not raw `http`
- Settings via `SettingsService`, `ProviderSettingsRepo`, `IptvSettingsRepo`
- Persistence in `storage`; network in `api`

