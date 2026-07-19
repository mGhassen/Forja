# Forja web — Supabase

Local stack uses **project_id `forja-dev`** and ports **55321–55326** (Dose / other projects keep 64321+ and default 54321+ free).

| Service | Port |
|---------|------|
| API (Kong) | 55321 |
| Postgres | 55322 |
| Studio | 55323 |
| Inbucket UI | 55324 |
| Inbucket SMTP | 55325 |
| Inbucket POP3 | 55326 |

## Local reset + test users

From the repo root (Docker + [Supabase CLI](https://supabase.com/docs/guides/cli) required):

```bash
node scripts/reset-forja-supabase.js
```

That will:

1. Start or resume `forja-dev` containers if needed
2. `supabase db reset` (migrations + `seed.sql`)
3. Create test users via Auth Admin API

**Test logins**

| Email | Password | Notes |
|-------|----------|-------|
| `user@forja.local` | `password123` | `accounts.is_admin` — open `/admin` |
| `demo@forja.local` | `password123` | Non-admin |

The script seeds lean `profile_settings` + shared `iptv_portals` / `user_iptv_portals` (no `user_settings`, no M3U in cloud).
Signup creates an `accounts` row only — test users get named profiles from the seed script, not an auto `Profile 1`.

Then put the printed `VITE_SUPABASE_*` values into `apps/web/.env` (or run `supabase status` from `apps/web`).
Keep `VITE_TURNSTILE_SITE_KEY=1x00000000000000000000AA` for local Auth captcha
(matches `[auth.captcha]` in `config.toml`).

## Auth captcha (Turnstile)

Local `config.toml` enables Cloudflare Turnstile with Cloudflare’s always-pass
test secret. Hosted projects: Dashboard → Authentication → Bot and Abuse
Protection → enable Turnstile and paste your **secret** key; set
`VITE_TURNSTILE_SITE_KEY` (site key) in `apps/web` / Vercel.

### Prod widget fails with `400020`

Cloudflare maps **400020 → invalid sitekey**. Ignore unrelated console noise
(Gmail, password managers, `background-redux-new.js`).

1. Cloudflare Dashboard → **Turnstile** → open the widget → copy the **Site Key**
   (not the Secret Key) into Vercel env `VITE_TURNSTILE_SITE_KEY`
2. Under the same widget → **Hostname management** — allow every prod host
   (`forjahq.vercel.app`, custom domain, `www` if used). Missing host is usually
   `110200`; a deleted/wrong key is `400020`
3. Supabase → Auth → Bot protection → paste that widget’s **Secret** key
4. Redeploy the web app so Vite picks up the env (site key is build-time)

Local always-pass dummy (`1x00000000000000000000AA`) must never be set on Vercel.

## Auth email templates

Branded Forja HTML lives in [`templates/`](./templates/) and is wired in
`config.toml` under `[auth.email.template.*]` (`content_path` is relative to
`apps/web`, e.g. `./supabase/templates/confirmation.html`). Subjects and body
copy match the Forja dark brand (green CTA, paper text on near-black).

| Template | File | Subject |
|----------|------|---------|
| Confirm signup | `confirmation.html` | Confirm your Forja account |
| Reset password | `recovery.html` | Reset your Forja password |
| Magic link / OTP | `magic_link.html` | Your Forja sign-in code |
| Invite | `invite.html` | You're invited to Forja |
| Change email | `email_change.html` | Confirm your new email |
| Reauthentication | `reauthentication.html` | Your Forja verification code |

**Auth model:** email + password and passkeys (no magic-link login in the app).
Signup confirmation emails are **OTP codes** typed in the web UI. Password reset
uses a **clickable recovery link** (`{{ .ConfirmationURL }}`) that opens
`/reset-password` so the user sets a new password, then signs in.

### Session inactivity (30 days)

Local GoTrue: `[auth.sessions] inactivity_timeout = "720h"` in `config.toml`
(restart `supabase stop && supabase start` after changing). Access JWTs stay
at 1h (`jwt_expiry`); clients refresh on resume/focus so the inactivity clock
resets while the app/web is used. After **30 days with no refresh**, the next
refresh fails and the session ends.

**Hosted (required separately):** Dashboard → **Authentication** → **Sessions**
→ set **Inactivity timeout** to **720 hours** (30 days). `config.toml` does not
apply this to a linked remote project unless you run `supabase config push`
(ask before pushing).

### Passkeys (WebAuthn)

Enable in Dashboard → **Authentication** → **Passkeys**. Production RP:

| Field | Value |
|-------|-------|
| Relying Party Display Name | `Forja` |
| Relying Party ID | `www.forjahq.xyz` |
| Relying Party Origins | `https://www.forjahq.xyz` |

Use **www** as RP ID so Apple’s AASA fetch hits the live host (apex may 308
to www; Apple rejects redirects on the RP ID host).

macOS Associated Domains: `webcredentials:www.forjahq.xyz`. The portal serves:

`https://www.forjahq.xyz/.well-known/apple-app-site-association`

from [`public/.well-known/apple-app-site-association`](../public/.well-known/apple-app-site-association)
(`7U77CJ4Q8T.com.forjahq.app` — macOS bundle id). JSON content-type
via `vercel.json`. Verify:

```bash
curl -sI https://www.forjahq.xyz/.well-known/apple-app-site-association
# Expect: HTTP 200, content-type: application/json — NOT 308
```

**macOS native passkeys** also need the Associated Domains entitlement
(`webcredentials:www.forjahq.xyz`). That capability is **not available on an
Apple Personal Team** — only on a paid Apple Developer Program membership.
Until then, keep Associated Domains out of the macOS entitlements so local
signing works; use password or **Web login** for passkeys on Mac. Windows
Hello and the web portal do not need Associated Domains.
Logo URL in every template: `{{ .SiteURL }}/brand/logo-email.png`
(served from `apps/web/public/brand/logo-email.png`). Hosted Site URL must be
your public web origin so the logo loads in real inboxes.

### Local preview (Mailpit / Inbucket)

1. Set `enable_confirmations = true` in `config.toml`
2. Restart: `supabase stop && supabase start` (from `apps/web`)
3. Run the web app (`pnpm dev`) so `/brand/logo-email.png` is reachable
4. Sign up (or open `/forgot-password` to trigger recovery) → open Mailpit UI at **http://127.0.0.1:55324**
5. For recovery: click the **reset link** in the email → `/reset-password` → choose
   a new password → sign in at `/login`
6. For signup confirm: enter the **code** on the sign-up page after register
7. Set `enable_confirmations = false` again if you want click-free test users

### Hosted (production Dashboard)

`config.toml` does **not** push templates to a linked remote project. After
editing files in `templates/`:

1. Dashboard → **Authentication** → **Email Templates**
2. For each template above, paste the HTML and matching subject
3. Confirm **URL Configuration → Site URL** is the public web origin (not
   `localhost`) so `{{ .SiteURL }}/brand/logo-email.png` resolves
4. Redirect URLs must include `/login`, `/signup`, `/forgot-password`,
   `/reset-password`, and `/account`. Recovery emails redirect to
   `/reset-password`. Daily sign-in stays email/password or passkey (no magic-link login).

From `apps/web` only:

```bash
supabase start
supabase db reset
node ../../scripts/create-forja-test-users.js
```

## Release installers (Cloudflare R2)

Public R2 bucket **`forja-releases`** holds DMG / EXE / AppImage / APK objects at
`v{version}/{filename}`. Supabase Storage is **not** used for installers
(Free plan caps objects at 50 MiB).

- **Upload:** Release CI runs `scripts/upload_release_to_r2.py` with GitHub
  secrets `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`
  (never ship access keys to clients).
- **Retention:** after each upload the script keeps only the **newest 3**
  version prefixes (`RELEASE_STORAGE_KEEP`, default `3`) and deletes older
  objects so storage stays within the R2 free tier.
- **Download URL (site + in-app updater):** `{RELEASE_CDN_URL}/latest/{filename}`
- **Download URL (versioned archive):** `{RELEASE_CDN_URL}/v{version}/{filename}`
  (custom domain preferred; `pub-*.r2.dev` only for testing).
- **Clients:** Flutter `--dart-define=RELEASE_CDN_URL=…` and web
  `VITE_RELEASE_CDN_URL` / root `RELEASE_CDN_URL`.
- **Upload:** each release also mirrors into `latest/` and removes stale
  `latest/` objects so the site and updater always hit current installers.

## Remote (production / shared project)

```bash
cd apps/web
supabase link --project-ref <ref>
supabase db push
supabase functions deploy sync-github-releases
supabase functions deploy delete-account
supabase functions deploy mint-desktop-session
```

Secrets for the Edge Function (optional):

```bash
supabase secrets set GITHUB_TOKEN=ghp_...
# GITHUB_REPO defaults to mGhassen/Forja
```

`delete-account` and `mint-desktop-session` use the project’s built-in
`SUPABASE_SERVICE_ROLE_KEY` (set automatically for Edge Functions). Call them
only with a signed-in user JWT (`delete-account` from Account settings;
`mint-desktop-session` from desktop Web login handoff).
Invoke after a release:

```bash
supabase functions invoke sync-github-releases --no-verify-jwt
```

Or schedule via Supabase Dashboard → Edge Functions → Cron.
