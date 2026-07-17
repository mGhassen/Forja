# Sync module

Supabase Auth + `user_settings` blob sync. See [RFC-006](../../../docs/rfc/006-[partial]-supabase-sync.md) and [RFC-034](../../../docs/rfc/034-[partial]-web-portal-landing.md).

Dart-defines: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` (same project as `apps/web`).
Optional: `FORJA_WEB_URL` for desktop **Web login** / signup links (local
`http://127.0.0.1:3000` in root `.env`; **required** GitHub secret for release —
must be the deployed portal, not localhost).

Browser handoff: `DesktopBrowserAuth` opens `{FORJA_WEB_URL}/login?desktop_callback=…` and applies tokens via `SyncService.signInWithBrowser`.
