# Forja

Full-feature cinema app for macOS and beyond. Modular monorepo.

## Structure

```
apps/forja/              Main Flutter app
packages/
  forja_shell/           Bootstrap + app lifecycle
  forja_ui/              All feature screens + MainScreen nav (19 tabs)
  forja_api/             API clients + app services
  forja_core/            Models + utilities
  forja_storage/         Settings + persistence + theme
  forja_iptv/            Xtream + M3U IPTV
  forja_streaming/       Torrent engine, local proxy, stream extractors
  forja_webstreamr/      WebStreamr sources + extractors
  forja_scrapers/        Torrent index scrapers
  forja_player/          Video player screens
  forja_design/          Design system (Phase 3)
  forja_casting/         AirPlay / Chromecast stubs (Phase 3)
  forja_sync/            Supabase sync stubs (Phase 3)
docs/rfc/
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
