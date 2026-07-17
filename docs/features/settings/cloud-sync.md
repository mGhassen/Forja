# Cloud sync

> Optional Forja account to back up settings across devices via Supabase.

## What it is

Cloud sync stores settings domain blobs in Supabase under your Forja account. The same account works on the web portal and in the desktop/mobile app. The app stays offline-first — you do not need an account to use Forja.

Each account can have multiple profiles with their own avatar. Every profile
has an independent set of synced settings. The active profile is selected
separately on each browser or app device, so changing profiles does not switch
another screen.

## How to open it

- **Desktop startup:** sign in with email/password, use **Web login** (browser
  handoff), or choose **Continue without an account**. New accounts are created
  only on the web (**Create an account on the web**).
- **App:** select the profile avatar at the bottom of the desktop rail (opens
  **Who’s watching?** when signed in), or open **Settings → Profile & account**
  and use **Who’s watching?** / **Manage profiles**
- **Web:** sign in at `/login` or create an account at `/signup` (Turnstile captcha
  when configured), choose a profile on **Who's watching?**, then open **Remote
  settings**. The sidebar splits **Profile** (synced IPTV / playback / navigation /
  providers / Stremio) from **Account** (email, log out, delete). Back returns to
  Who's watching. Switch profiles from the header menu. **Log out** is under
  Account in the left nav.

## What syncs (remote settings)

Per profile:

| Store | What it includes |
|---------|------------------|
| **`user_iptv_portals`** | Assigned portals: `portal_id` + your **portal name** + favorite. Credentials live on shared `iptv_portals` (passwords encrypted at rest). |
| **`profile_settings` → Playback** | Full prefs: torrent / Stremio / webstreaming play sources, auto next/skip intro, IPTV EPG, preferred audio, max quality |
| **`profile_settings` → Navigation** | Visible shell tabs and default tab — editable on web under **Profile → Navigation** |
| **`profile_settings` → Provider order** | Film/series, Anime, Asian drama host order — stored only when different from built-in defaults |
| **`profile_settings` → Stremio** | Installed addon manifest URLs |
| **`profile_settings` → IPTV** | Reserved for device sync (M3U URLs). Not edited on the web portal. |

## What stays local

Not synced — device-specific or sensitive:

- My List / film lists (TMDB ids stay on the device)
- M3U playlists uploaded from a file, and all M3U **channel** rows (URL playlists re-fetch channels on device)
- Live IPTV connection counts (probed in-app; not stored in cloud)
- Torrent cache size, connections, and learned provider scores
- Debrid and indexer API keys (for now)
- Cache clears, downloaded updates, WebView data
- Trakt / Simkl / MDBList account linking

## What you can do

- Sign in with email and password in the desktop app, or use **Web login** to
  authenticate in the browser (the app opens the portal and finishes when you
  sign in there). If the browser does not open or you change your mind, tap
  **Cancel web login** (or **Continue without an account**) to unlock the
  screen. Create accounts only on the web (`/signup`); the app does not
  offer in-app signup. Web signup and sign-in show a Cloudflare Turnstile check
  when captcha is configured.
- Continue as a guest; the current local-only app behavior remains available
- Select the active profile from the desktop rail avatar, **Who’s watching?**, or
  **Manage profiles** under **Settings → Profile & account** (same Netflix-style
  grid as the web). Choosing a profile shows a dedicated splash while settings
  sync — not an in-settings dropdown. After the splash, the app opens that
  profile’s **default menu** tab (the starred tab under **Settings → Navigation**),
  not the screen you were on before switching.
- On desktop, a restored session goes straight to the splash. A new interactive
  sign-in opens **Who’s watching?** so you can choose the device profile first.
  Tapping a profile shows the profile-switch splash, then the boot splash.
- **Sign out** from Profile & account (or the profile chooser) returns to the
  desktop sign-in screen and unloads the main app. You must sign in again or
  choose **Continue without an account**. Device-local settings stay on disk for
  guest / offline use; cloud sync stops until you sign in again
- Open **Account** after sign-in on the web: pick a profile on **Who’s watching?**,
  then land in **Remote settings**. Use the **Account** sidebar item for log out
  or permanent account delete (confirm by typing your email)
- Create, rename, and delete profiles on desktop or the web, with 30 avatars
  organized into Characters, Creatures, Space, and Retro categories
- The desktop chooser, rail, and Profile & account page use the same avatar
  artwork selected on the web
- Add, edit, search, favorite, share, or remove IPTV portals from
  the web (share codes match the app peer-code flow). On the web IPTV page,
  portals are a compact list (expiry, name, URL, seats). Lists paginate every 10 items.
  **Export CSV** downloads portals (plain-text passwords in the file; on-device they use Keychain).
  Then **Save** to sync.
- Change playback prefs and provider order from the web
- Manage Stremio addon URLs from the web
- Delete the cloud account from **Account** settings (removes synced profiles
  and settings; the app still works without an account)

After saving on the web, select the same profile in Forja to pull its changes.

## Setup

Builds need the shared Supabase project:

```text
--dart-define=SUPABASE_URL=...
--dart-define=SUPABASE_PUBLISHABLE_KEY=...
```

Optional portal origin for **Web login** / signup links (defaults to local Vite):

```text
--dart-define=FORJA_WEB_URL=https://your-portal.example
```

Web uses `VITE_SUPABASE_URL` / `VITE_SUPABASE_PUBLISHABLE_KEY` in `apps/web/.env`.
For signup/sign-in captcha, also set `VITE_TURNSTILE_SITE_KEY` (Cloudflare Turnstile
site key). Local dummy keys are documented in `apps/web/.env.example`.
Local Flutter development can load the repo-root `.env` directly:

```text
flutter run -d macos --dart-define-from-file=../../.env
```

When testing **Web login** locally, run the portal (`pnpm --filter web dev` on
`http://127.0.0.1:3000`) and keep `FORJA_WEB_URL` at that default. Restart the
web dev server after pulling Vite host changes so it binds IPv4 (not only
`[::1]`).

GitHub build/release workflows use repository secrets `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY` (or legacy `SUPABASE_ANON_KEY`). The publishable key is a public client credential; never put a
Supabase `service_role` / `sb_secret_…` key in a desktop build. Set
`FORJA_WEB_URL` in release builds to the deployed portal origin so **Web login**
does not point at localhost.

## Tips

- IPTV credentials live on shared `iptv_portals` rows with passwords encrypted at rest. Your per-profile **portal name** is only on `user_iptv_portals`.
- Cloud settings omit default provider orders and never store M3U channel lists or My List — those stay on each device. Playback prefs (including play sources) sync in full.
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
