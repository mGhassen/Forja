import { supabase } from '@/lib/supabase'
import { readPluginInstallIntent } from '@/lib/forja-plugin-install'

export type ApproveDeviceLinkResult =
  | { ok: true }
  | { ok: false; error: string }

const POST_LOGIN_NEXT_KEY = 'forja.auth.next'

/**
 * Safe post-login destinations for `?next=` (relative path only).
 * Today: `/connect` for Android TV device link.
 */
export function isSafeAuthNextPath(raw: string | null | undefined): boolean {
  if (!raw) return false
  if (!raw.startsWith('/') || raw.startsWith('//')) return false
  if (raw.includes('://') || raw.includes('\\')) return false
  return (
    raw === '/connect' ||
    raw.startsWith('/connect?') ||
    raw === '/plugins' ||
    raw.startsWith('/plugins?') ||
    raw === '/account/settings/forja' ||
    raw.startsWith('/account/settings/forja?')
  )
}

/** Normalize a typed TV code (uppercase, strip separators). */
export function normalizeDeviceUserCode(raw: string): string {
  return raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, '')
}

export function rememberPostLoginNextFromSearch(
  search: string = typeof window !== 'undefined' ? window.location.search : '',
): void {
  if (typeof window === 'undefined') return
  const params = new URLSearchParams(search)
  const next = params.get('next')
  if (!isSafeAuthNextPath(next)) return
  try {
    const payload: { next: string; code?: string } = { next: next! }
    const code = params.get('code')?.trim()
    if (code) payload.code = code
    sessionStorage.setItem(POST_LOGIN_NEXT_KEY, JSON.stringify(payload))
  } catch {
    // ignore
  }
}

export function clearPostLoginNext(): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.removeItem(POST_LOGIN_NEXT_KEY)
  } catch {
    // ignore
  }
}

export function readPostLoginNext(): {
  to: '/connect' | '/plugins' | '/account/settings/forja'
  search?: { code?: string; manifest?: string; name?: string; version?: string }
} | null {
  if (typeof window === 'undefined') return null
  const params = new URLSearchParams(window.location.search)
  let next = params.get('next')
  let code = params.get('code')?.trim() || undefined
  if (!isSafeAuthNextPath(next)) {
    try {
      const stored = sessionStorage.getItem(POST_LOGIN_NEXT_KEY)
      if (stored) {
        const parsed = JSON.parse(stored) as { next?: string; code?: string }
        next = parsed.next ?? null
        code = parsed.code?.trim() || undefined
      }
    } catch {
      // ignore
    }
  }
  if (!isSafeAuthNextPath(next)) return null
  if (next === '/plugins' || next?.startsWith('/plugins?')) {
    return { to: '/plugins' }
  }
  if (
    next === '/account/settings/forja' ||
    next?.startsWith('/account/settings/forja?')
  ) {
    const intent = readPluginInstallIntent()
    return {
      to: '/account/settings/forja',
      ...(intent
        ? {
            search: {
              manifest: intent.manifestUrl,
              ...(intent.name ? { name: intent.name } : {}),
              ...(intent.version ? { version: intent.version } : {}),
            },
          }
        : {}),
    }
  }
  return {
    to: '/connect',
    ...(code ? { search: { code } } : {}),
  }
}

export async function approveDeviceLink(
  userCode: string,
): Promise<ApproveDeviceLinkResult> {
  const code = normalizeDeviceUserCode(userCode)
  if (code.length < 6 || code.length > 12) {
    return { ok: false, error: 'Enter the code shown on your TV.' }
  }

  const { data, error } = await supabase.functions.invoke<{
    ok?: boolean
    error?: string
  }>('approve-device-link', {
    method: 'POST',
    body: { user_code: code },
  })

  if (error) {
    let message = error.message || 'Could not link your TV.'
    try {
      const ctx = (error as { context?: Response }).context
      if (ctx) {
        const body = (await ctx.json()) as { error?: string }
        if (body.error?.trim()) message = body.error.trim()
      }
    } catch {
      // keep message
    }
    return { ok: false, error: message }
  }

  if (data?.error?.trim()) {
    return { ok: false, error: data.error.trim() }
  }

  return { ok: true }
}
