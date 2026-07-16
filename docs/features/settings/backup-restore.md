# Backup & restore

> Export and import Forja configuration as one JSON file. Settings also persist automatically on this device in a single store. IPTV portals can also be moved as a CSV file.

## What it is

**One settings store** on this device:

| Layer | Holds |
|-------|--------|
| `forja_engine_store.json` (app support) | Non-secret settings: playback, provider order, Stremio/Nuvio addons, WebStreamr countries/filters, navbar, … |
| Keychain / Keystore | Credentials: Trakt, Simkl, Debrid, Jackett/Prowlarr API keys, WebStreamr MFP password / TMDB token, … |

Older SharedPreferences copies of those settings are imported once into that file and then removed — they are not a second source of truth.

**Manual Export / Import** is a snapshot for backup or another device. It does not replace the live store while you use the app.

**IPTV portals CSV** is a separate spreadsheet export of Xtream credentials (same format as the web remote settings page).

## How to open it

**Settings → Data & backup** (Backup / IPTV portals)

## What you can do

- **Export** — save a JSON file to disk (includes settings map + secure keys when present)
- **Import** — load a previously exported file (replaces current settings after confirm)
- **Export CSV** / **Import CSV** — move Xtream portals only (includes passwords). Import adds portals that are not already saved and shows an import log; existing portals are left unchanged

## Tips

- Treat export files as sensitive — they contain API keys and tokens
- CSV portal files also contain passwords — keep them private
- Import is destructive to current settings — confirm before proceeding
- Clearing **Stream cache** / **IPTV portal cache** does **not** clear settings or tokens
- IPTV channel catalogs, My List, and continue-watching rows are not part of this settings file
- Complements (does not replace) [cloud sync](cloud-sync.md)

## Related

- [Cache & data](cache-data.md)
- [Playback settings](playback-settings.md)
- [IPTV — Xtream](../live/iptv-xtream.md)
- [Trakt](../accounts/trakt.md)
- [Stremio addons](../sources/stremio-addons.md)
- [Navigation bar](navigation-bar.md)
