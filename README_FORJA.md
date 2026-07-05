# Forja

Full-feature cinema app for macOS and beyond. Feature-first monorepo.

## Structure

```
apps/forja/
  lib/
    app/                 Bootstrap + lifecycle
    shell/               MainScreen nav (19 tabs)
    features/            One folder per nav tab
    shared/              Widgets, design, casting, sync stubs
  macos/ ios/ android/ windows/ linux/
packages/                Engine room only (7 packages)
  core/                  Models + utilities
  storage/               Settings + persistence + theme
  api/                   HTTP clients + app services
  streaming/             Torrent engine, local proxy, extractors
  webstreamr/            WebStreamr sources + extractors
  scrapers/              Torrent index scrapers
  rust/                  Dart FFI bindings to Rust engine
docs/rfc/               RFC index + v1.0–v3.0 release specs
docs/migration/         Global migration (Phases 1–5); start at README.md
```

## Run (macOS)

```bash
cd apps/forja
flutter pub get
flutter run -d macos
```

Or from repo root:

```bash
melos bootstrap
cd apps/forja && flutter run -d macos
```

## Build release

```bash
./scripts/build_macos.sh
```

## Nav tabs

All 19 nav tabs: Home, Discover, Similar, Search, My List, Downloader, Magnet, Live Matches, IPTV, Audiobooks, Books, Music, Comics, Manga, Jellyfin, Anime, Anime Arabic, Asian Drama, Arabic — plus Settings.

## License

GPL-2.0
