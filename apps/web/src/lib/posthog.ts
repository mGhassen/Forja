import type { PostHogConfig } from 'posthog-js'

/**
 * PostHog web portal config (RFC-043 web slice).
 *
 * Empty `VITE_POSTHOG_KEY` → provider is not mounted (no SDK traffic).
 * Never identify by email / display name — anonymous distinct id only.
 */

const apiKeyRaw = (
  import.meta.env.VITE_POSTHOG_KEY as string | undefined
)?.trim()

const hostDefine = (
  import.meta.env.VITE_POSTHOG_HOST as string | undefined
)?.trim()

/** US cloud by default; set `VITE_POSTHOG_HOST=https://eu.i.posthog.com` for EU. */
export const posthogHost =
  hostDefine && hostDefine.length > 0
    ? hostDefine
    : 'https://us.i.posthog.com'

export const posthogApiKey = apiKeyRaw ?? ''

export const posthogConfigured = posthogApiKey.length > 0

function sensitivePropertyKey(key: string): boolean {
  const k = key.toLowerCase()
  return (
    k.includes('token') ||
    k.includes('password') ||
    k.includes('secret') ||
    k.includes('cookie') ||
    k.includes('magnet') ||
    k.includes('email') ||
    k.includes('stream')
  )
}

/** Keep origin + path; strip query/hash that may hold auth codes. */
export function scrubPageUrl(url: string): string {
  try {
    const u = new URL(
      url,
      typeof window !== 'undefined'
        ? window.location.origin
        : 'https://forjahq.xyz',
    )
    u.search = ''
    u.hash = ''
    return u.toString()
  } catch {
    return '[url]'
  }
}

function scrubText(value: string): string {
  return value
    .replace(/magnet:\?[^\s"']+/gi, '[magnet]')
    .replace(/https?:\/\/[^\s"'<>]+/gi, (match) => scrubPageUrl(match))
    .replace(/Bearer\s+[A-Za-z0-9._~+/=-]+/gi, 'Bearer [redacted]')
    .replace(
      /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,
      '[jwt]',
    )
}

function scrubProperties(
  properties: Record<string, unknown> | undefined,
): Record<string, unknown> | undefined {
  if (!properties) return properties
  const out: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(properties)) {
    if (sensitivePropertyKey(key)) continue
    if (typeof value === 'string') {
      if (key === '$current_url' || key.toLowerCase().includes('url')) {
        out[key] = scrubPageUrl(value)
      } else {
        out[key] = scrubText(value)
      }
    } else {
      out[key] = value
    }
  }
  return out
}

/** Options for `@posthog/react` PostHogProvider (TanStack Start docs). */
export const posthogBrowserOptions: Partial<PostHogConfig> = {
  api_host: posthogHost,
  // Enables modern SPA pageview / history tracking.
  defaults: '2026-05-30',
  person_profiles: 'identified_only',
  capture_exceptions: true,
  // Loud in local DEV so Network/console make it obvious the SDK started.
  debug: Boolean(import.meta.env.DEV),
  persistence: 'localStorage+cookie',
  session_recording: {
    maskAllInputs: true,
    maskTextSelector: '*',
  },
  before_send: (event) => {
    if (!event) return event
    if (event.properties) {
      event.properties = scrubProperties(
        event.properties as Record<string, unknown>,
      ) as typeof event.properties
    }
    return event
  },
}

if (import.meta.env.DEV) {
  // eslint-disable-next-line no-console
  console.info(
    `[PostHog] web key ${posthogConfigured ? 'present' : 'MISSING'} · host ${posthogHost}`,
  )
}

