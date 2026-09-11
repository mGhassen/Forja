# Archived Forja features (dead vault)

**Not a runnable app.** Code moved out of `apps/forja` so it is not compiled, analyzed, or shipped with Forja.

| Was | Now |
|-----|-----|
| `apps/forja/lib/features/archive/` | `apps/archive/lib/` |

Imports still say `package:forja/...` — historical snapshot only. Do not add a `pubspec.yaml` here (melos would treat it as a package).

## Tabs / folders

| Folder | Nav id |
|--------|--------|
| `search/` | `search` |
| `discover/` | `discover` |
| `similar/` | `similar` |
| `downloader/` | Media Downloader |
| `magnet/` | `magnet` |
| `audiobooks/` | `audiobooks` |
| `utils/` | EPUB helpers |
| `audio/` | music / audiobook players (not a tab) |
| `books/` | `books` |
| `music/` | `music` |
| `comics/` | `comics` |
| `manga/` | `manga` |
| `jellyfin/` | `jellyfin` |
| `anime_arabic/` | `anime_arabic` |

Restore: copy back under `apps/forja/lib/features/`, re-register builders in `nav_config.dart`, remove ids from `archivedNavIds`.

User guide: [`docs/features/archive/`](../../docs/features/archive/README.md) · Rust: [`crates/archive/`](../../crates/archive/README.md)
