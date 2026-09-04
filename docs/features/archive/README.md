# Archived features

Guides for tabs and verticals that are **not** in the default Forja product surface. Matching code:

- **Flutter:** [`apps/forja/lib/features/archive/`](../../../apps/forja/lib/features/archive/README.md)
- **Rust:** [`crates/archive/`](../../../crates/archive/README.md)

**Active user guide:** [features README](../README.md)

---

## Hidden tabs

Withheld from the shell and **Settings → Features** via `archivedNavIds` in [`nav_config.dart`](../../../apps/forja/lib/shell/nav_config.dart) — code lives under `features/archive/`, tabs are not offered in the navbar list.

| Guide | Tab |
|-------|-----|
| [Search](movies-tv/search.md) | Search |
| [Discover](movies-tv/discover.md) | Discover |
| [Similar](movies-tv/similar.md) | Similar |
| [Magnet player](utilities/magnet-player.md) | Magnet |
| [Media Downloader](utilities/media-downloader.md) | Media Downloader |

---

## Out-of-scope verticals

Not part of the in-scope tab set (Home, Anime, Asian Drama, IPTV, Live Matches, Lists, Settings). Same archival treatment — not “legacy deleted”; docs and code moved here intentionally.

### Hubs

| Guide | Tab |
|-------|-----|
| [Anime Arabic](hubs/anime-arabic.md) | Anime Arabic |

Arabic cinema is active again when the ForjaHQ Arabic pack is installed — see [Arabic](../hubs/arabic.md).

### Media libraries

| Guide | |
|-------|---|
| [Jellyfin](jellyfin/jellyfin.md) | Home server library |

### Music & reading

| Guide | |
|-------|---|
| [Music](music/music.md) | Music tab |
| [Music downloads](music/music-downloads.md) | Offline music |
| [Manga](reading/manga.md) | Manga |
| [Comics](reading/comics.md) | Comics |
| [Books](reading/books.md) | Books |
| [Audiobooks](reading/audiobooks.md) | Audiobooks |
| [Generate audiobook](reading/generate-audiobook.md) | EPUB → TTS |

### Stremio

Out of scope for active product docs. Stremio may still appear in app UI (e.g. TMDB Sources tab, Live Matches server chip) — setup and catalog browsing guides live here only.

| Guide | |
|-------|---|
| [Stremio addons](sources/stremio-addons.md) | Install manifests, VOD streams, Live assignment |
| [Stremio catalog](movies-tv/stremio-catalog.md) | Full addon catalog browser |
