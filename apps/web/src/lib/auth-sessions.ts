import { supabase } from '@/lib/supabase'

export type AuthSessionRow = {
  id: string
  created_at: string
  updated_at: string | null
  refreshed_at: string | null
  user_agent: string | null
  ip: string | null
  aal: string | null
}

export type SessionGeo = {
  countryCode: string
  country: string
  city: string | null
}

const GEO_CACHE_PREFIX = 'forja.session_geo.'

/** session_id claim from the current access token (JWT). */
export function currentSessionIdFromAccessToken(
  accessToken: string | null | undefined,
): string | null {
  if (!accessToken) return null
  try {
    const parts = accessToken.split('.')
    if (parts.length < 2 || !parts[1]) return null
    const json = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'))
    const payload = JSON.parse(json) as { session_id?: unknown }
    return typeof payload.session_id === 'string' ? payload.session_id : null
  } catch {
    return null
  }
}

export function describeSessionPlace(userAgent: string | null | undefined): {
  label: string
  detail: string | null
} {
  const ua = userAgent?.trim() ?? ''
  if (!ua) {
    return { label: 'Unknown device', detail: null }
  }
  if (/forja\s*desktop/i.test(ua)) {
    return { label: 'Forja desktop app', detail: 'Web login handoff' }
  }
  if (/forja\s*android\s*tv/i.test(ua)) {
    return { label: 'Forja Android TV', detail: 'Device link' }
  }
  if (/forja/i.test(ua)) {
    return { label: 'Forja app', detail: null }
  }
  // Flutter GoTrue default UA before a branded string is set.
  if (/^dart\//i.test(ua)) {
    return { label: 'Forja app', detail: null }
  }
  // Should not appear (RPC filters these); keep a clear label if one slips through.
  if (/supabaseedgeruntime|^deno\//i.test(ua)) {
    return { label: 'Forja app session', detail: 'Server mint' }
  }

  let browser = 'Browser'
  if (/Edg\//i.test(ua)) browser = 'Edge'
  else if (/Chrome\//i.test(ua) && !/Chromium/i.test(ua)) browser = 'Chrome'
  else if (/Firefox\//i.test(ua)) browser = 'Firefox'
  else if (/Safari\//i.test(ua) && !/Chrome/i.test(ua)) browser = 'Safari'

  let os = 'device'
  if (/Windows/i.test(ua)) os = 'Windows'
  else if (/Mac OS X|Macintosh/i.test(ua)) os = 'macOS'
  else if (/Android/i.test(ua)) os = 'Android'
  else if (/iPhone|iPad/i.test(ua)) os = 'iOS'
  else if (/Linux/i.test(ua)) os = 'Linux'

  return { label: `${browser} on ${os}`, detail: null }
}

export function formatSessionWhen(iso: string | null | undefined): string {
  if (!iso) return '—'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

/** Strip CIDR suffix from auth.sessions.ip (`1.2.3.4/32` → `1.2.3.4`). */
export function formatSessionIp(ip: string | null | undefined): string | null {
  if (!ip?.trim()) return null
  return ip.trim().replace(/\/\d+$/, '')
}

function isLookupableIp(ip: string): boolean {
  if (ip === '127.0.0.1' || ip === '::1' || ip === 'localhost') return false
  if (ip.startsWith('10.') || ip.startsWith('192.168.') || ip.startsWith('169.254.')) {
    return false
  }
  if (/^172\.(1[6-9]|2\d|3[0-1])\./.test(ip)) return false
  return true
}

/** Regional-indicator flag emoji from ISO 3166-1 alpha-2. */
export function countryCodeToFlagEmoji(code: string | null | undefined): string | null {
  const c = code?.trim().toUpperCase()
  if (!c || c.length !== 2 || !/^[A-Z]{2}$/.test(c)) return null
  return String.fromCodePoint(
    ...[...c].map((ch) => 0x1f1e6 - 65 + ch.charCodeAt(0)),
  )
}

function readGeoCache(ip: string): SessionGeo | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = sessionStorage.getItem(GEO_CACHE_PREFIX + ip)
    if (!raw) return null
    const parsed = JSON.parse(raw) as SessionGeo
    if (
      typeof parsed.countryCode === 'string' &&
      typeof parsed.country === 'string'
    ) {
      return {
        countryCode: parsed.countryCode,
        country: parsed.country,
        city: typeof parsed.city === 'string' ? parsed.city : null,
      }
    }
  } catch {
    // ignore
  }
  return null
}

function writeGeoCache(ip: string, geo: SessionGeo): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(GEO_CACHE_PREFIX + ip, JSON.stringify(geo))
  } catch {
    // ignore
  }
}

/**
 * Best-effort country for a public IP (ipwho.is). Cached per tab session.
 * Returns null for private IPs or lookup failures.
 */
export async function lookupSessionGeo(
  ip: string | null | undefined,
): Promise<SessionGeo | null> {
  const clean = formatSessionIp(ip)
  if (!clean || !isLookupableIp(clean)) return null
  const cached = readGeoCache(clean)
  if (cached) return cached
  try {
    const res = await fetch(
      `https://ipwho.is/${encodeURIComponent(clean)}?fields=success,country,country_code,city`,
      { signal: AbortSignal.timeout(5000) },
    )
    if (!res.ok) return null
    const body = (await res.json()) as {
      success?: boolean
      country?: string
      country_code?: string
      city?: string | null
    }
    if (!body.success || !body.country_code?.trim() || !body.country?.trim()) {
      return null
    }
    const geo: SessionGeo = {
      countryCode: body.country_code.trim().toUpperCase(),
      country: body.country.trim(),
      city: body.city?.trim() || null,
    }
    writeGeoCache(clean, geo)
    return geo
  } catch {
    return null
  }
}

export async function listMyAuthSessions(): Promise<{
  sessions: AuthSessionRow[]
  error: string | null
}> {
  const { data, error } = await supabase.rpc('list_my_auth_sessions')
  if (error) {
    return { sessions: [], error: error.message }
  }
  const rows = Array.isArray(data) ? (data as AuthSessionRow[]) : []
  return { sessions: rows, error: null }
}

export async function revokeMyAuthSession(
  sessionId: string,
): Promise<{ ok: boolean; error: string | null }> {
  const { data, error } = await supabase.rpc('revoke_my_auth_session', {
    p_session_id: sessionId,
  })
  if (error) {
    return { ok: false, error: error.message }
  }
  return { ok: data === true, error: data === true ? null : 'Session not found.' }
}
