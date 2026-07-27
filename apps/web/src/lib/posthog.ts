import posthog from 'posthog-js'

/**
 * PostHog product analytics for the web portal (RFC-043 web slice).
 *
 * Empty `VITE_POSTHOG_KEY` → SDK never starts (local / unconfigured deploys).
 * Never identify by email or display name — anonymous distinct id only.
 */

const apiKey = (
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

export const posthogConfigured = Boolean(apiKey)

let started = false

export function isPostHogActive(): boolean {
  return started
}

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

function scrubText(value: string): string {
  return value
    .replace(/magnet:\?[^\s"']+/gi, '[magnet]')
    .replace(
      /https?:\/\/[^\s"'<>]+/gi,
      (match) => scrubPageUrl(match),
    )
    .replace(
      /Bearer\s+[A-Za-z0-9._~+/=-]+/gi,
      'Bearer [redacted]',
    )
    .replace(
      /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,
      '[jwt]',
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

/** Client-only. Safe to call multiple times. */
export function initWebPostHog(): boolean {
  if (typeof window === 'undefined') return false
  if (!apiKey) return false
  if (started) return true

  posthog.init(apiKey, {
    api_host: posthogHost,
    person_profiles: 'identified_only',
    capture_pageview: false,
    capture_pageleave: true,
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
  })

  started = true
  return true
}

export function capturePageview(url: string): void {
  if (!started) return
  const cleaned = scrubPageUrl(url.trim())
  if (!cleaned || cleaned === '[url]') return
  posthog.capture('$pageview', { $current_url: cleaned })
}

export function track(
  name: string,
  properties?: Record<string, unknown>,
): void {
  if (!started) return
  posthog.capture(name, scrubProperties(properties))
}

export { posthog }
