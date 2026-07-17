# Cloud sync

> Optional Forja account to back up settings across devices via Supabase.

## What it is

Cloud sync stores settings domain blobs in Supabase under your Forja account. The same account works on the web portal and in the desktop/mobile app. The app stays offline-first — you do not need an account to use Forja.

Each account can have multiple profiles with their own avatar. Every profile
has an independent set of synced settings. The active profile is selected
separately on each browser or app device, so changing profiles does not switch
another screen.

## How to open it

- **Desktop startup:** sign in or create an account before the splash, or choose
  **Continue without an account** to keep using Forja locally
- **App:** select the profile avatar at the bottom of the desktop rail, then
  open **Profile & account**
- **Web:** sign in at `/login`, choose a profile on **Who's watching?**, then
  manage **Remote settings**. Switch profiles from the settings header menu.

## What syncs (remote settings)

These domains can be edited on the web or in the app; the app pulls them on sign-in:

| Domain | What it includes |
|--------|------------------|
| **IPTV** | Xtream portals (URL, user, pass, favorites) and M3U playlist URLs |
| **Playback** | Play source toggles, auto next/skip intro, IPTV EPG, preferred audio, max quality |
| **Provider order** | Film and series, Anime, and Asian drama host order (tabs on the web settings page) |
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
- Continue as a guest; the current local-only app behavior remains available
- On desktop, a restored session goes straight to the splash. A new interactive
  sign-in opens **Who’s watching?** so you can choose the device profile first.
- Open **Account** after sign-in: pick a profile on **Who’s watching?**, then
  land in **Remote settings**. Switch or manage profiles from the settings
  profile menu — not as a peer of settings.
- Create, rename, and delete profiles on the web, with 30 avatars organized
  into Characters, Creatures, Space, and Retro categories
- Select the active profile from **Settings → Profile & account** or the web
  settings header
- Add, edit, search, favorite, share, or remove IPTV portals and M3U URLs from
  the web (share codes match the app peer-code flow). Portal rows match the app
  panel (expiry, name, URL, seats); lists paginate every 10 items. **Import CSV** /
  **Export CSV** move portals (plain-text passwords in the file; on-device they use Keychain) as a spreadsheet-friendly file —
  import adds only portals that are not already in your list (shown in an import log);
  then **Save** to sync.
- Change playback prefs and provider order from the web
- Manage Stremio addon URLs from the web
- Sign out (local settings stay on the device)

After saving on the web, select the same profile in Forja to pull its changes.

## Setup

Builds need the shared Supabase project:

```text
--dart-define=SUPABASE_URL=...
--dart-define=SUPABASE_ANON_KEY=...
```

Web uses `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` in `apps/web/.env`.
Local Flutter development can load the repo-root `.env` directly:

```text
flutter run -d macos --dart-define-from-file=../../.env
```

GitHub build/release workflows use repository secrets `SUPABASE_URL` and
`SUPABASE_ANON_KEY`. The anon key is a public client credential; never put a
Supabase `service_role` key in a desktop build.

## Tips

- IPTV credentials are stored in your account row (HTTPS + per-user RLS). Treat your account password like any cloud secret.
- Portal **share codes** are a separate peer handoff (encrypted ciphertext on
  rentry) — they are not stored in your sync payload.
- Each account always keeps at least one profile. Deleting a profile also deletes its remote settings.
- Profile selection is local to each device; profile settings remain remote and account-owned.
- Per-domain merge by timestamp is still evolving — sign in after web edits to refresh the app.
- Local **Backup & restore** still works for a full JSON export including device-only keys.

## Related

- [IPTV — Xtream](../live/iptv-xtream.md)
- [IPTV — M3U](../live/iptv-m3u.md)
- [Backup & restore](backup-restore.md)
- [Stream providers](../sources/stream-providers.md)
- [Stremio addons](../sources/stremio-addons.md)
