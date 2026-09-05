# Archived features

Shell tabs and verticals **removed from navigation**. Code is kept for reference or future restore — not part of the in-scope product surface.

**Active features:** `account`, `iptv`, `live_matches`, `media`, `settings` + catalog hubs via `shared/catalog/` (My List is the `forjahq-my-list` hub pack + `shared/lists/` host services).

## Archived tabs

| Folder | Nav id |
|--------|--------|
| `search/` | `search` |
| `discover/` | `discover` |
| `similar/` | `similar` |
| `downloader/` | `media downloader` |
| `magnet/` | `magnet` |
| `audiobooks/` | `audiobooks` |
| `books/` | `books` |
| `music/` | `music` |
| `comics/` | `comics` |
| `manga/` | `manga` |
| `jellyfin/` | `jellyfin` |
| `anime_arabic/` | `anime_arabic` |
| *(plugin hub)* | `arabic` — catalog via `arabic-hub` pack; no app feature folder |

Restore: re-register in [`nav_config.dart`](../../shell/nav_config.dart) and move the folder back under `features/`.

User guide: [`docs/features/archive/README.md`](../../../../docs/features/archive/README.md) · Rust: [`crates/archive/`](../../archive/README.md)
