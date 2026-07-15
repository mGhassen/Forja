# Backup & restore

> Export and import Forja configuration as one JSON file. Local settings also persist automatically on this device.

## What it is

Two layers:

1. **Automatic local persistence** — non-secret settings (playback, provider order, Stremio/Nuvio addons, WebStreamr countries/filters, navbar, …) live in `forja_engine_store.json` under app support. Credentials (Trakt, Simkl, Debrid keys, Jackett/Prowlarr API keys, WebStreamr MFP password / TMDB token, …) live in the platform Keychain/Keystore. Change a setting, quit the app, reopen — values stay.
2. **Manual Export / Import** — copy configuration between devices or keep a backup JSON. Export is a snapshot; it does not replace the live stores while you use the app.

## How to open it

**Settings → Data & backup** (Backup)

## What you can do

- **Export** — save a JSON file to disk (includes settings map + secure keys when present)
- **Import** — load a previously exported file (replaces current settings after confirm)

## Tips

- Treat export files as sensitive — they contain API keys and tokens
- Import is destructive to current settings — confirm before proceeding
- Clearing **Stream cache** / **IPTV portal cache** does **not** clear settings or tokens
- IPTV channel catalogs, My List, and continue-watching rows are not part of this settings file
- Complements (does not replace) future [cloud sync](../coming-soon/cloud-sync.md)

## Related

- [Cache & data](cache-data.md)
- [Playback settings](playback-settings.md)
- [Trakt](../accounts/trakt.md)
- [Stremio addons](../sources/stremio-addons.md)
- [Navigation bar](navigation-bar.md)
