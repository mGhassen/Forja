# Cloud sync

> Optional Forja account to back up settings across devices via Supabase.

## What it is

Cloud sync stores settings domain blobs in Supabase under your Forja account. The same account works on the web portal and in the desktop/mobile app. The app stays offline-first — you do not need an account to use Forja.

Each account can have multiple profiles with their own avatar. Every profile
has an independent set of synced settings. The active profile is selected
separately on each browser or app device, so changing profiles does not switch
another screen.

## How to open it

- **Desktop startup:** sign in with email/password, **Sign in with passkey** (macOS /
  Windows), use **Web login** (browser handoff), or choose **Continue without an
  account**. New accounts are created only on the web (**Create an account on the
  web**). Linux, phones, and TV keep password and/or web login only.
- **App:** select the profile avatar at the bottom of the desktop rail (opens
  **Who’s watching?** when signed in), or open **Settings → Profile & account** —
  the page shows the active profile (**Watching now** — tap to switch), cloud
  sync status, passkeys (macOS / Windows), and **Sign out**
- **Web:** sign in at `/login` with email/password or **Sign in with passkey**, or
  create an account at `/signup` (Turnstile captcha when configured). Use
  **Forgot password?** on `/login` (or open `/forgot-password`) to email a reset
  link; open the link to choose a new password on `/reset-password`, then sign in.
  Under **Account**, enroll and remove passkeys. New accounts have no profiles yet —
  create your
  first one (name + avatar); default synced settings are attached then. After
  that, choose a profile on **Who's watching?**, then open **Remote settings**.
  The sidebar splits **Profile** (synced IPTV / playback / navigation / Stremio)
  from **Account** (email, passkeys, log out, delete). Back returns to Who's
  watching. Switch profiles from the header menu. **Log out** is under Account in
  the left nav.

## What syncs (remote settings)

Per profile:

| Store | What it includes |
|---------|------------------|
| **`accounts.features`** | Lean account flags (default `{}` = all off). Enabled keys only — e.g. `iptvScrape` for Reddit portal discovery in the app. |
| **`user_iptv_portals`** | Assigned portals: `portal_id` + your **portal name** + favorite. Credentials live on shared `iptv_portals` (passwords encrypted at rest). |
| **`profile_settings` → Playback** | Full prefs: torrent / Stremio / webstreaming play sources, auto next/skip intro, IPTV EPG, preferred audio, max quality |
| **`profile_settings` → Navigation** | Visible shell tabs and default tab — editable on web under **Profile → Navigation** |
| **`profile_settings` → Stremio** | Installed addon manifest URLs |
| **`profile_settings` → IPTV** | Reserved for device sync (M3U URLs). Not edited on the web portal. |

## What stays local

Not synced — device-specific or sensitive:

- Stream / anime / Asian drama **provider order** (Settings in the app only — not on the web portal)
- My List / film lists (TMDB ids stay on the device)
- M3U playlists uploaded from a file, and all M3U **channel** rows (URL playlists re-fetch channels on device)
- Live IPTV connection counts (probed in-app; not stored in cloud)
- Torrent cache size, connections, and learned provider scores
- Debrid and indexer API keys (for now)
- Cache clears, downloaded updates, WebView data
- Trakt / Simkl / MDBList account linking

## What you can do

- Sign in with email and password in the desktop app (Cloudflare Turnstile appears
  when Auth captcha is configured), **Sign in with passkey** on macOS and Windows
  (Touch ID / Windows Hello), or use **Web login** to authenticate in the
  browser (one portal tab; the app finishes when you sign in there — no second
  localhost page). If the browser does not open or you change your mind, tap
  **Cancel web login** (or **Continue without an account**) to unlock the
  screen. Create accounts only on the web (`/signup`); the app does not offer
  in-app signup. Web signup and sign-in show a Cloudflare Turnstile check when
  captcha is configured. Web login also offers passkeys. Forgot password is
  web-only: `/forgot-password` emails a reset link that opens `/reset-password`.
- Continue as a guest; the current local-only app behavior remains available
- Select the active profile from the desktop rail avatar, or tap **Watching now**
  under **Settings → Profile & account** to open **Who’s watching?** / **Manage
  profiles** (same Netflix-style grid as the web). Choosing a profile shows a
  dedicated splash while settings sync — not an in-settings dropdown. After the
  splash, the app opens that profile’s **default menu** tab (the starred tab
  under **Settings → Navigation**), not the screen you were on before switching.
- On desktop, a restored session goes straight to the splash. A new interactive
  sign-in opens **Who’s watching?** so you can choose the device profile first.
  If the account has no profiles yet, you create one before continuing. Tapping a
  profile shows the profile-switch splash, then the boot splash.
- **Sign out** from Profile & account (or the profile chooser) returns to the
  desktop sign-in screen and unloads the main app. You must sign in again or
  choose **Continue without an account**. Device-local settings stay on disk for
  guest / offline use; cloud sync stops until you sign in again
- Open **Account** after sign-in on the web: create a profile if needed, pick one
  on **Who’s watching?**, then land in **Remote settings**. Use the **Account**
  sidebar item for passkeys, log out, or permanent account delete (confirm by
  typing your email). On macOS / Windows, **Settings → Profile & account** also
  lists Add / remove passkey.
- Create, rename, and delete profiles on desktop or the web, with 30 avatars
  organized into Characters, Creatures, Space, and Retro categories. Signup does
  not invent a default profile — the first one is yours, with default settings
  applied when you create it
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

Optional portal origin for **Web login** / signup links:

```text
--dart-define=FORJA_WEB_URL=https://your-portal.example
```

When Supabase Auth captcha is enabled, also pass the public Turnstile site key
(same value as `VITE_TURNSTILE_SITE_KEY` on the web portal):

```text
--dart-define=TURNSTILE_SITE_KEY=…
```

Local always-pass dummy: `1x00000000000000000000AA` (matches
`apps/web/supabase/config.toml`). Hosted projects need the real widget site key
that matches the Auth captcha secret.

Put the same keys in repo-root `.env` (see `.env.example`) so local
`flutter run --dart-define-from-file=../../.env` picks them up. Local default
portal is `http://127.0.0.1:3000`. **Release / CI** must set GitHub secret
`FORJA_WEB_URL` to the deployed portal (Vercel URL, custom domain, etc.) —
builds fail if it is missing or still localhost. Set optional secret
`TURNSTILE_SITE_KEY` so in-app password login works when Auth captcha is on.
This does **not** go in `apps/web/.env` alone (that file configures the portal;
the desktop app needs its own dart-defines).

Web uses `VITE_SUPABASE_URL` / `VITE_SUPABASE_PUBLISHABLE_KEY` in `apps/web/.env`.
For signup/sign-in captcha, also set `VITE_TURNSTILE_SITE_KEY` (Cloudflare Turnstile
site key) on the web and the matching `TURNSTILE_SITE_KEY` for Flutter.
Local dummy keys are documented in `apps/web/.env.example` and root `.env.example`.
Local Flutter development can load the repo-root `.env` directly:

```text
flutter run -d macos --dart-define-from-file=../../.env
```

When testing **Web login** locally, run the portal (`pnpm --filter web dev` on
`http://127.0.0.1:3000`) and keep `FORJA_WEB_URL` at that default. Restart the
web dev server after pulling Vite host changes so it binds IPv4 (not only
`[::1]`).

GitHub build/release workflows use repository secrets `SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY` (or legacy `SUPABASE_ANON_KEY`), and **`FORJA_WEB_URL`**.
The publishable key is a public client credential; never put a
Supabase `service_role` / `sb_secret_…` key in a desktop build.

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
