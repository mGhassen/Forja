# Cache & data

> Clear stream caches, images, provider scores, and local watch history from Settings.

## What it is

A category under **Settings → Data & backup** to free disk and reset local learned or viewing data without wiping accounts, My List, or your provider drag order.

## How to open it

**Settings → Data & backup** (Cache section)

## What you can do

### Safe to clear

- **Stream cache** — saved webstreaming and anime stream URLs, torrent temp files, and seek buffers. Next Play re-resolves. Settings and continue watching stay.
- **Images & WebView** — poster thumbnails and extractor WebView caches. Images re-download when needed.
- **Downloaded updates** (desktop) — installer files saved by in-app update (`.dmg`, `.exe`, AppImage). Safe to remove after you install.

### Learned

- **Provider scores** — reliability totals used for Settings **Score** and Auto order. Drag preference order is kept; scores start from zero and re-learn on new checks.

### Watch data (destructive)

- **Continue watching** — empties Home, Anime, Asian Drama, and Anime Arabic resume rows on this device. Trakt / Simkl cloud history is not deleted.
- **Watched episode marks** — clears local episode checkmarks only. Cloud trackers may restore marks after sync.

Every action asks for confirmation and shows a toast when done.

## Tips

- Prefer **Stream cache** when Play opens a dead or stale URL.
- Prefer **Provider scores** when Auto keeps favoring a flaky extractor after you fixed network / region.
- Tokens, Stremio addons, My List, and Backup keys are never cleared here — use [Backup & restore](backup-restore.md) or account panels instead.

## Related

- [Playback settings](playback-settings.md)
- [Watch history](../movies-tv/watch-history.md)
- [Stream providers](../sources/stream-providers.md)
- [Backup & restore](backup-restore.md)
