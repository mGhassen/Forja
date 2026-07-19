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
  if (/forja/i.test(ua)) {
    return { label: 'Forja app', detail: null }
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
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
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
