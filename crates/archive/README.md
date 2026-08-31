# Archived Rust crates

Vertical catalog engines **removed from the active `ffi` link graph**. Code is kept for reference or restore — not part of the in-scope product build.

**Active engine:** everything else under [`crates/`](../) linked from [`ffi`](../ffi/Cargo.toml).

**Matching Flutter archive:** [`apps/forja/lib/features/archive/`](../../apps/forja/lib/features/archive/README.md)

## Archived crates

| Folder | Was used for |
|--------|----------------|
| `jellyfin/` | Jellyfin tab catalog API |
| `music/` | Music tab |
| `books/` | Books tab |
| `manga/` | Manga tab |
| `catalog/` | Similar tab (`bestsimilar.com`) |
| `anilist/` | Legacy AniList GraphQL (hub browse is `plugins/hubs/anime`) |
| `anime/` | Legacy Rust anime extractors/resolve (`anime_extractors`) — JS providers own extract now |
| `host-http/` | Rich HTTP (retries, binary) via `hostHttp()` |
| `media-extra/` | Lyrics + paper2audio via `mediaExtraRequest()` |
| `trakt/` | Trakt.tv API client (Simkl is the active tracker) |

## Still active (not here)

| Crate | Why |
|-------|-----|
| `stremio` | Generic HTTP GET/POST for Simkl, hubcloud, probes |
| `subtitles` | Player subtitle search (Wyzie, Levrx, SubtitleCat, Mysubs) |
| `media-metadata` | mdblist + introdb |
| `proxy` `/jellyfin-stream` | Loopback route for any Jellyfin-style stream URL — not the `jellyfin` catalog crate |
| `engine-js` | Provider JS host — includes KissKh `kkey` (`__native_kisskh_kkey`) |

## Restore

1. `git mv crates/archive/<name> crates/<name>`
2. Re-add workspace member path in [`crates/Cargo.toml`](../Cargo.toml)
3. Re-add `path` dep + FFI exports in [`ffi`](../ffi/)
4. Regenerate / restore Dart bindings in [`packages/rust`](../../packages/rust/)

User guide: [`docs/features/archive/README.md`](../../docs/features/archive/README.md)
