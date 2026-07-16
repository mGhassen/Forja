# Cloud sync

> Optional Forja account to back up settings across devices via Supabase.

## What it is

Cloud sync stores settings domain blobs in Supabase under your Forja account. The same account works on the web portal and in the desktop/mobile app. The app stays offline-first — you do not need an account to use Forja.

## How to open it

- **App:** Settings → Accounts → **Forja account**
- **Web:** sign in at `/login`, then **Account → Remote settings**

## What syncs (remote settings)

These domains can be edited on the web or in the app; the app pulls them on sign-in:

| Domain | What it includes |
|--------|------------------|
| **IPTV** | Xtream portals (URL, user, pass, favorites) and M3U playlist URLs |
| **Playback** | Play source toggles, auto next/skip intro, IPTV EPG, preferred audio, max quality |
| **Provider order** | Web stream, anime mirror, and Asian drama try-order |
| **Stremio** | Installed addon manifest URLs |

## What stays local

Not synced — device-specific or sensitive:

- Shell navigation layout and default tab
- Torrent cache size, connections, and learned provider scores
- Debrid and indexer API keys (for now)
- Cache clears, downloaded updates, WebView data
- Trakt / Simkl / MDBList account linking
- M3U playlists uploaded from a file (URL-based M3U syncs)

## What you can do

- Create an account or sign in with email and password (app or web)
- Add, edit, or remove IPTV portals and M3U URLs from the web
- Change playback prefs and provider order from the web
- Manage Stremio addon URLs from the web
- Sign out (local settings stay on the device)

After saving on the web, open Forja and sign in (or stay signed in) to pull changes.

## Setup

Builds need the shared Supabase project:

```text
--dart-define=SUPABASE_URL=...
--dart-define=SUPABASE_ANON_KEY=...
```

Web uses `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` in `apps/web/.env`.

## Tips

- IPTV credentials are stored in your account row (HTTPS + per-user RLS). Treat your account password like any cloud secret.
- Per-domain merge by timestamp is still evolving — sign in after web edits to refresh the app.
- Local **Backup & restore** still works for a full JSON export including device-only keys.

## Related

- [IPTV — Xtream](../live/iptv-xtream.md)
- [IPTV — M3U](../live/iptv-m3u.md)
- [Backup & restore](backup-restore.md)
- [Stream providers](../sources/stream-providers.md)
- [Stremio addons](../sources/stremio-addons.md)
