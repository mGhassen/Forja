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

The script seeds lean `profile_settings` + shared `iptv_portals` (no `user_settings`, no M3U channel lists).
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
| Reset password | `recovery.html` | Your Forja password reset code |
| Magic link / OTP | `magic_link.html` | Your Forja sign-in code |
| Invite | `invite.html` | You're invited to Forja |
| Change email | `email_change.html` | Confirm your new email |
| Reauthentication | `reauthentication.html` | Your Forja verification code |

**Auth model:** email + password sign-in (no magic-link login in the app).
Auth emails are **OTP codes** you type in the web UI — not clickable login links
(keeps Resend free-tier usage predictable: one mail per signup/reset, zero on
daily sign-in).

Logo URL in every template: `{{ .SiteURL }}/brand/logo-email.png`
(served from `apps/web/public/brand/logo-email.png`). Hosted Site URL must be
your public web origin so the logo loads in real inboxes.

### Local preview (Mailpit / Inbucket)

1. Set `enable_confirmations = true` in `config.toml`
2. Restart: `supabase stop && supabase start` (from `apps/web`)
3. Run the web app (`pnpm dev`) so `/brand/logo-email.png` is reachable
4. Sign up (or open `/forgot-password` to trigger recovery) → open Mailpit UI at **http://127.0.0.1:55324**
5. For recovery: copy the **code** from the email → `/reset-password` → enter
   email + code + new password
6. For signup confirm: enter the **code** on the sign-up page after register
7. Set `enable_confirmations = false` again if you want click-free test users

### Hosted (production Dashboard)

`config.toml` does **not** push templates to a linked remote project. After
editing files in `templates/`:

1. Dashboard → **Authentication** → **Email Templates**
2. For each template above, paste the HTML and matching subject
3. Confirm **URL Configuration → Site URL** is the public web origin (not
   `localhost`) so `{{ .SiteURL }}/brand/logo-email.png` resolves
4. Redirect URLs still need `/login`, `/signup`, `/forgot-password`,
   `/reset-password`, and `/account` for any rare link fallbacks — day-to-day
   auth is password + OTP codes

From `apps/web` only:

```bash
supabase start
supabase db reset
node ../../scripts/create-forja-test-users.js
```

## Remote (production / shared project)

```bash
cd apps/web
supabase link --project-ref <ref>
supabase db push
supabase functions deploy sync-github-releases
supabase functions deploy delete-account
```

Secrets for the Edge Function (optional):

```bash
supabase secrets set GITHUB_TOKEN=ghp_...
# GITHUB_REPO defaults to mGhassen/Forja
```

`delete-account` uses the project’s built-in `SUPABASE_SERVICE_ROLE_KEY` (set
automatically for Edge Functions). Call it only with a signed-in user JWT from
the web Account settings page.
Invoke after a release:

```bash
supabase functions invoke sync-github-releases --no-verify-jwt
```

Or schedule via Supabase Dashboard → Edge Functions → Cron.
