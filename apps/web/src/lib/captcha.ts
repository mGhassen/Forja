/** Cloudflare Turnstile site key (public). Empty = captcha UI off. */
export const turnstileSiteKey = (
  import.meta.env.VITE_TURNSTILE_SITE_KEY as string | undefined
)?.trim()

export const captchaConfigured = Boolean(turnstileSiteKey)

/** Local / CI always-pass Turnstile keys (Cloudflare dummy widgets). */
export const TURNSTILE_TEST_SITE_KEY = '1x00000000000000000000AA'
export const TURNSTILE_TEST_SECRET_KEY = '1x0000000000000000000000000000000AA'
