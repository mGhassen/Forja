# Cache & data

> Clear stream caches, images, provider scores, and local watch history from Settings — scoped to the **current profile** (or **Guest**).

## What it is

A category under **Settings → Data & backup** to free disk and reset local learned or viewing data for the active account/profile/Guest without wiping other profiles, My List (unless you clear elsewhere), or your provider drag order.

## How to open it

**Settings → Data & backup** (Cache section) — phone / desktop only (hidden on Android TV)

## What you can do

### Safe to clear

- **Stream cache** — saved webstreaming stream URLs and seek buffers for **this profile / Guest** (plus idle torrent downloads on phone/desktop; torrent temp is shared on the device). Next Play re-resolves. Settings and continue watching stay.
- **Images & WebView** — poster thumbnails and extractor WebView caches on **this device** (shared; not profile-split). Images re-download when needed.
- **IPTV portal cache** (when the IPTV tab is visible) — saved Live/Movies/Series catalogs, live-channel health checks, and channel scan results for **this profile / Guest**. Saved portals, favorites, and M3U playlists stay; next IPTV open re-fetches.
- **Downloaded updates** (desktop) — installer files saved by in-app update (`.dmg`, `.exe`, AppImage) on **this device**. Safe to remove after you install.

### Learned

- **Provider scores** — reliability totals used for Settings **Score** and Auto order for **this profile / Guest**. Drag preference order is kept; scores start from zero and re-learn on new checks.

### Watch data (destructive)

- **Continue watching** — empties Home, Anime, Asian Drama, and Anime Arabic resume rows for **this profile / Guest** only. Other profiles keep their history. Trakt / Simkl cloud history is not deleted.
- **Watched episode marks** — clears local episode checkmarks for **this profile / Guest**. Trakt / Simkl may restore TMDB marks after sync; Anime / Asian Drama marks are local-only.

Every action asks for confirmation and shows a toast when done. On **TV**, Cancel / Confirm are D-pad focusable (destructive actions land on Cancel).

## Tips

- Prefer **Stream cache** when Play opens a dead or stale URL.
- Prefer **IPTV portal cache** when Live “alive” marks, channel scan hits, or the channel list look stale after a provider change (or use shelf **Reload** for one section).
- Prefer **Provider scores** when Auto keeps favoring a flaky extractor after you fixed network / region.
- Tokens, Stremio/Nuvio addons, My List, and Backup keys are never cleared here — settings also auto-persist locally (see [Backup & restore](backup-restore.md)); use that for device-to-device copy.

## Related

- [IPTV — Xtream](../live/iptv-xtream.md)
- [Playback settings](playback-settings.md)
- [Watch history](../movies-tv/watch-history.md)
- [Stream providers](../sources/stream-providers.md)
- [Backup & restore](backup-restore.md)
- [RFC-082](../../rfc/082-[open]-account-profile-local-data-scope.md)
