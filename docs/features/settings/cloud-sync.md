# Cloud sync

> Optional Forja account to back up settings across devices via Supabase.

## What it is

Cloud sync stores settings domain blobs in Supabase under your Forja account. The same account works on the web portal and in the desktop/mobile app. The app stays offline-first — you do not need an account to use Forja.

Each account can have up to **5 profiles**, each with their own avatar. Every
profile has an independent set of synced settings. The active profile is
selected separately on each browser or app device, so changing profiles does
not switch another screen. Opening Profile settings waits until the active
profile is known — another profile’s settings are never shown first.

## How to open it

- **Desktop startup:** if a newer build is available, the update prompt appears
  first; then the same welcome as Android TV (logo, **Sign in** / **Continue as
  guest**). Sign in shows a code + QR — approve on the portal at `/connect`.
  See [Link Android TV](../accounts/tv-connect.md). Email/password, passkey, and
  **Web login** are not on that screen; on **mobile**, they remain in **Settings →
  Profile & account** if you continue as guest. On **macOS / Windows**, guest
  **Settings → Profile & account** uses the same **Sign in** → code + QR flow.
- **Android TV startup:** after the update check, choose **Sign in** (then code or
  QR) or **Continue as guest**. After a successful link, pick a profile on
  **Who’s watching?** See [Link Android TV](../accounts/tv-connect.md). The TV
  rail uses the same **profile avatar** entry for Settings as desktop.
- **App:** select the profile avatar at the bottom of the desktop or TV rail (opens
  **Settings → Profile & account**), or open that page from Settings —
  the page shows the active profile (**Watching now** — tap to switch), cloud
  sync status, passkeys (macOS / Windows), and **Sign out**. From Who’s watching,
  **Account settings** opens Settings and dismisses any open TMDB details so the
  hub is visible.
- **Web:** sign in at `/login` with email/password or **Sign in with passkey**, or
  create an account at `/signup` (Turnstile captcha when configured) — check your
  email and open the **Confirm email** link to finish signup. Use
  **Forgot password?** on `/login` (or open `/forgot-password`) to email a reset
  link; open the link to choose a new password on `/reset-password`, then sign in.
  Link an Android TV at `/connect` (code from the TV or QR). Under **Account**,
  enroll and remove passkeys. New accounts have no profiles yet —
  create your
  first one (name + avatar); default synced settings are attached then. After
  that, choose a profile on **Who's watching?**, then open **Remote settings**.
  The sidebar splits **Profile** (**Addons** / **Forja Packs** / **Features** —
  same as the app) from **Account** (email, passkeys, delete) and **Connections** (every
  active session — where, since, last active — revoke one or sign out all). Back
  returns to Who's watching. Switch profiles from the header menu. **Log out**
  is under Account in the left nav.

## What syncs (remote settings)

Per profile:

| Store | What it includes |
|---------|------------------|
| **`accounts.features`** | Lean account flags (default `{}` = all off). Enabled boolean keys only — e.g. `iptvScrape` (Find Portals) and `dealPortal` (Deal from catalog pool). Numeric `maxIptvPortals` when raised above the default **5** (omit when 5). Admins (`is_admin`) are unlimited for portals. The app re-pulls flags/credits on IPTV open and when the app resumes. |
| **`user_iptv_portals`** | Assigned portals: `portal_id` + your **portal name** + favorite. Credentials live on shared `iptv_portals` (passwords encrypted at rest). |
| **`profile_settings` → Playback** | Full prefs: torrent / Stremio / Nuvio / webstreaming play sources, Simple resolve, auto next/skip intro, IPTV EPG, preferred audio / subtitle, max quality, anime title language, **Addons IPTV / Live Sports unlock** (`addon_feature_iptv` / `addon_feature_live_matches`). Devices only push those unlock keys on intentional Addons toggles. Web **Profile → Addons** (hub + Playback detail). |
| **`profile_settings` → Navigation** | Features rail `visibleIds` + `tabOrder` among **available** tabs only (unlocked Addons + hub packs on the profile). Written by **Addons** / pack enable (default-on) and by **Features** (hide/reorder). Web **Profile → Features** (and Addons when unlocking IPTV / Live). |
| **`profile_settings` → Features** | Visible shell tabs and default tab — editable on web under **Profile → Features**. Empty list means no feature tabs (Settings only). The portal lists **IPTV** / **Live Sports** (host) plus hub tab ids from packs **on this profile** — it does not invent Home/Anime/…. |
| **`profile_settings` → Stremio** | Installed addon manifest URLs — web **Addons → Stremio** |
| **`profile_settings` → Forja** | Forja plugin pack **membership** (manifest URLs) plus **`onboarded`**. Cloud/web only records which packs are **on the profile**. The **app** downloads and installs scripts (and asks mid-session before download/uninstall). Synced with web **Profile → Forja Packs** / Community Packs. Web **Addons → Live Sports** / **Direct torrent** also manage live+catalog / torrent packs on that list. |
| **`profile_settings` → Nuvio** | Installed Nuvio scraper manifest URLs — web **Addons → Nuvio** |

## What stays local

Not synced — device-specific or sensitive:

- Stream / anime / Asian drama **provider order** (Settings in the app only — not on the web portal)
- My List / film lists (TMDB ids stay on the device)
- **All M3U playlists** (URL and file) and their channel rows — re-fetch URL playlists on each device
- Live IPTV connection counts (probed in-app; not stored in cloud)
- Torrent cache size, connections, and learned provider scores
- Debrid and indexer API keys (for now)
- Cache clears, downloaded updates, WebView data
- Trakt / Simkl / MDBList account linking

## What you can do

- Cold start on desktop and Android TV: **Sign in** (code or QR → portal
  `/connect`) or **Continue as guest**. After approve, pick a profile on
  **Who’s watching?** When the profile is not yet onboarded, a packs step
  offers the official ForjaHQ bundle, Community Packs, or Skip (see
  [Forja Packs](forja-packs.md)). Guest gets the same packs step once per
  device (local flag). Device-link sessions show as **Forja Android TV** under
  Account → Connections. From **Settings → Profile & account** (guest), you can
  still sign in with email and password (Cloudflare Turnstile when Auth captcha
  is configured), **Sign in with passkey** on macOS and Windows (Touch ID /
  Windows Hello), or **Web login** in the browser (one portal tab; the app
  finishes when you sign in there — no second localhost page). After Web login
  handoff the portal mints a **separate** session for the desktop app and
  **stays signed in** in the browser. Optional **Google OAuth** appears on web
  login when configured. Optional **authenticator (TOTP)** is under web
  **Account** — after you enable it, sign-in asks for a 6-digit code (Web login
  completes MFA in the browser before minting the desktop session; in-app
  password sign-in shows the same challenge). Portal **Sign out** clears this
  browser only; **Account → Connections** lists every active session (device,
  location with flag, IP, signed-in / last active) and can revoke one or
  **Sign out all devices** (including the desktop app). Already signed in on the
  portal? Web login skips the credentials form and finishes the handoff (or use
  **Return to Forja**). Create accounts only on the web (`/signup`). Forgot
  password is web-only: `/forgot-password` → `/reset-password`.
- Continue as a guest; the current local-only app behavior remains available
- Tap **Watching now** under **Settings → Profile & account** (desktop rail
  avatar opens that page) to open **Who’s watching?** / **Manage profiles**
  (same Netflix-style grid as the web). Choosing a profile shows a short splash
  where that avatar scales from its tile into the center while settings sync —
  same dismiss timing idea as the boot intro (it does not wait forever for home
  feed / engines). Not the logo intro splash, and not an in-settings dropdown.
  After it finishes, the app opens that profile’s **default menu** tab (the
  starred tab under **Settings → Features**), not the screen you were on before
  switching. IPTV portals sync only when that profile has IPTV in the menu.
  On switch the device portal list is cleared first so another profile’s portals
  cannot show while sync is slow or fails; this profile’s assignments load from
  cloud when the pull succeeds.
- On desktop **and Android TV**, a restored session goes straight to the boot splash (the session
  is kept across quit: local app-file vault by default on macOS; Keychain/Keystore
  when you enable Keychain under Settings → About → Privacy, or Keystore on
  Android).
  Boot renews the access token before profile/features sync so a overnight-expired
  JWT cannot leave you “signed in” with failed cloud pulls.
  A new interactive sign-in opens **Who’s watching?** so you can
  choose the device profile first. If the account has no profiles yet, you
  create one before continuing. Tapping a profile there uses the same
  avatar profile splash as mid-session switches (settings sync, then warm like
  the intro splash), then opens the app — not a second logo boot splash.
- **Sign out** from Profile & account (or the profile chooser) returns to the
  code/QR welcome screen and unloads the main app. You must sign in again or
  choose **Continue as guest**. Account-bound local data on this
  device is cleared (IPTV portals and passwords, synced playback/nav prefs reset
  to platform defaults); cloud sync stops until you sign in again
- Cloud sessions expire after **30 days without a refresh** (Auth inactivity
  timeout). Opening the app, focusing the desktop window, or leaving the app
  open refreshes the session on a timer so normal daily use stays signed in. If
  profiles fail to load (timeout / network), **Who’s watching** and
  **Settings → Profile & account** show an error with **Retry** and **Sign out**
  — they do not pretend you have no profiles, keep a stale “Synced” hero, or
  trap you without a way to clear the session when the network is down. If the session is
  lost while you are already using the app (for example after a failed token
  refresh), Forja returns to the code/QR welcome screen and clears the same
  account-bound local data — it does **not** stay open as Guest with your prior
  portals still loaded. Sign in again (or continue as guest with a clean local
  slate) to keep using the app. Web portal and desktop can stay signed in
  together — each has its own Auth session after Web login.
- Open **Account** after sign-in on the web: create a profile if needed, pick one
  on **Who’s watching?**, then land in **Remote settings**. Use the **Account**
  sidebar item for passkeys, log out, or permanent account delete (confirm by
  typing your email). On macOS / Windows, **Settings → Profile & account** also
  lists Add / remove passkey.
- Create, rename, and delete profiles on desktop or the web (max **5** per
  account), with 30 avatars organized into Characters, Creatures, Space, and
  Retro categories. Signup does not invent a default profile — the first one is
  yours. Each new profile starts from platform defaults (playback, tabs, Stremio,
  IPTV portals) — it never copies the profile you were using. Add profile is
  hidden once you hit the limit.
- The desktop chooser, rail, and Profile & account page use the same avatar
  artwork selected on the web
- Add, edit, search, favorite, share, or remove IPTV portals from
  the web (share codes match the app peer-code flow). On the web IPTV page,
  portals are a compact list (expiry, name, URL, seats). Lists paginate every 10 items.
  Checkboxes support **Select all** (matching search results) and batch **Export** /
  **Remove** (with confirm). Remove drops the portal from this profile only — the shared
  catalog row stays. You can clear the whole list. When your account has **Find Portals**
  (`iptvScrape`) enabled, the page shows a VIP **Activated** banner above the portal list
  (read-only — unlock is account-side). **Export CSV** downloads all portals, or only the
  selection when any are checked (plain-text passwords in the file; on-device they use Keychain).
  Changes save automatically to the cloud.
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
`[::1]`). After a successful handoff the portal stays signed in and shows a
confirmation in the same login card (loading → signed-in, short countdown
or **Close tab**). Story panel and header stay. Forja comes back to the front
only when that tab closes (manual or countdown) — not at the moment of
handoff. Deploy `mint-desktop-session` on the linked Supabase project for Web
login to mint the desktop session.

GitHub build/release workflows use repository secrets `SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY` (or legacy `SUPABASE_ANON_KEY`), and **`FORJA_WEB_URL`**.
The publishable key is a public client credential; never put a
Supabase `service_role` / `sb_secret_…` key in a desktop build.

## Tips

- IPTV credentials live on shared `iptv_portals` rows with passwords encrypted at rest. Your per-profile **portal name** is only on `user_iptv_portals`.
- **Cloud is master for portal assignments.** The device IPTV list is a cache. An empty local cache never deletes cloud portals (profile switch / sign-out wipe). Only deleting portals in the UI (or an intentional clear-all) updates cloud. On **profile switch**, the device cache is wiped **before** pull (fail-closed): a stalled or failed pull must not leave the previous profile’s portals on screen.
- **Cloud is master for `profile_settings` too.** The device settings file is a cache of the active profile’s cloud row. Edits write the cache and push; wipe / pull / defaults never upload an empty or partial cache over Stremio, Nuvio, or navigation already in cloud. A **failed** lean settings pull (network / expired token) keeps the local lean cache and does **not** seed platform defaults or push — only a confirmed missing cloud row seeds a new profile. **IPTV is separate:** profile-switch wipe clears portals first (see above). Debounced edits push only that domain (a playback toggle does not rewrite Features / default tab). Soft-pull lands cloud edits when you reopen Settings / Addons, resume the app, or refocus the web Profile tab — Features editing itself does not soft-pull mid-toggle.
- Cloud settings never store M3U playlists, M3U channel lists, or My List — those stay on each device. Playback prefs (including play sources and preferred subtitle language) sync in full.
- Portal **share codes** are a peer handoff: copy gives an 8-character `XXXX-XXXX` code that expires after **7 days**. Credentials are encrypted on the device; the short code is a lookup (not stored in your sync payload).
- Each account always keeps at least one profile. Deleting a profile also deletes its remote settings.
- Profile selection is local to each device; profile settings remain remote and account-owned.
- Per-domain merge by timestamp is still evolving — web Profile edits land on the app when you reopen Settings / Addons or resume.
- Local **Backup & restore** still works for a full JSON export including device-only keys.
- macOS passkeys on the **website** work with RP ID `www.forjahq.xyz`. Native
  in-app passkeys on Mac need **macOS 13.5+** and a paid Apple Developer team
  (Associated Domains); older macOS still runs Forja — use password or **Web
  login**. On a Personal Team use password or **Web login**. Windows can use
  passkeys in-app via Windows Hello.

## Related

- [IPTV — Xtream](../live/iptv-xtream.md)
- [IPTV — M3U](../live/iptv-m3u.md)
- [Backup & restore](backup-restore.md)
- [Stream providers](../sources/stream-providers.md)
