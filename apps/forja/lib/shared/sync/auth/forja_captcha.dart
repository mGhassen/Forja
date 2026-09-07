/// Cloudflare Turnstile for Supabase Auth captcha (same project as `apps/web`).
///
/// Pass `--dart-define=TURNSTILE_SITE_KEY=…` (or via repo-root `.env`).
/// Empty = captcha UI off (only works when Auth captcha is disabled on Supabase).
class ForjaCaptcha {
  ForjaCaptcha._();

  static const String siteKey = String.fromEnvironment('TURNSTILE_SITE_KEY');

  static bool get isConfigured => siteKey.isNotEmpty;

  /// Local always-pass dummy (matches `apps/web/supabase/config.toml` + web
  /// `VITE_TURNSTILE_SITE_KEY`). Hosted projects need the real widget site key.
  static const String localAlwaysPassSiteKey = '1x00000000000000000000AA';
}
