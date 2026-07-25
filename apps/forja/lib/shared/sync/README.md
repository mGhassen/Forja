# Sync module

Supabase Auth + `user_settings` blob sync. See [RFC-006](../../../docs/rfc/006-[partial]-supabase-sync.md) and [RFC-034](../../../docs/rfc/034-[partial]-web-portal-landing.md).

Dart-defines: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` (same project as `apps/web`).
Optional: `FORJA_WEB_URL` for desktop **Web login** / signup links (local
`http://127.0.0.1:3000` in root `.env`; **required** GitHub secret for release -
must be the deployed portal, not localhost).
Optional: `TURNSTILE_SITE_KEY` for in-app Turnstile when Auth captcha is enabled
(same public key as `VITE_TURNSTILE_SITE_KEY`; local dummy in `.env.example`).

Browser handoff: `DesktopBrowserAuth` opens `{FORJA_WEB_URL}/login?desktop_callback=…`;
the portal `fetch()`es the loopback callback (CORS + Private Network Access) and
`SyncService.signInWithBrowser` applies the tokens - one browser tab only.

Android TV device link: `TvDeviceLinkAuth` creates a code via Edge
`create-device-link`, shows `{FORJA_WEB_URL}/connect` (+ QR), polls
`poll-device-link`, and applies tokens with `signInWithBrowserTokens`. Portal
approves with `approve-device-link` (signed-in JWT). See [RFC-046](../../../docs/rfc/046-[open]-android-tv-device-link.md).
