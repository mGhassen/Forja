/**
 * Hands a Supabase session back to the Forja desktop app via a localhost
 * callback started by DesktopBrowserAuth.
 *
 * Uses fetch() so the portal tab stays put — never navigate to 127.0.0.1
 * (that opened a second browser page).
 *
 * Only http(s) loopback hosts are accepted.
 *
 * Query params are also mirrored to sessionStorage so a header click or
 * client navigation that drops `?desktop_callback=` still completes handoff.
 *
 * After a successful handoff the portal drops its local copy of the session
 * (storage + reload) so only the app keeps the refresh token. Do not call
 * signOut() — that revokes the RT on the server and kills the app session.
 */

import { supabase } from '@/lib/supabase'

const STORAGE_KEY = 'forja.desktop_auth'
const HANDOFF_DONE_KEY = 'forja.desktop_auth_done'
/** Blocks portal refreshSession while we hand the RT to the app / reload. */
const HANDOFF_LOCK_KEY = 'forja.desktop_auth_lock'

export type DesktopAuthParams = {
  callback: string | null
  state: string | null
}

export function isSafeDesktopCallback(raw: string | null | undefined): boolean {
  if (!raw) return false
  try {
    const url = new URL(raw)
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return false
    if (url.hostname !== '127.0.0.1' && url.hostname !== 'localhost') {
      return false
    }
    return true
  } catch {
    return false
  }
}

export function buildDesktopCallbackUrl(options: {
  callback: string
  state: string | null
  accessToken: string
  refreshToken: string
}): string | null {
  if (!isSafeDesktopCallback(options.callback)) return null
  const url = new URL(options.callback)
  url.searchParams.set('access_token', options.accessToken)
  url.searchParams.set('refresh_token', options.refreshToken)
  if (options.state) {
    url.searchParams.set('state', options.state)
  }
  return url.toString()
}

export function readDesktopAuthSearchParams(
  search: string | URLSearchParams = typeof window !== 'undefined'
    ? window.location.search
    : '',
): DesktopAuthParams {
  const params =
    typeof search === 'string' ? new URLSearchParams(search) : search
  return {
    callback: params.get('desktop_callback'),
    state: params.get('desktop_state'),
  }
}

/** Persist loopback handoff params from the current URL (no-op if unsafe). */
export function rememberDesktopAuthParams(
  params: DesktopAuthParams = readDesktopAuthSearchParams(),
): void {
  if (typeof window === 'undefined') return
  if (!params.callback || !isSafeDesktopCallback(params.callback)) return
  try {
    sessionStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({
        callback: params.callback,
        state: params.state,
      }),
    )
  } catch {
    // private mode / quota
  }
}

export function clearDesktopAuthParams(): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.removeItem(STORAGE_KEY)
  } catch {
    // ignore
  }
}

function hasHandoffLock(): boolean {
  if (typeof window === 'undefined') return false
  try {
    return (
      sessionStorage.getItem(HANDOFF_LOCK_KEY) === '1' ||
      sessionStorage.getItem(HANDOFF_DONE_KEY) === '1'
    )
  } catch {
    return false
  }
}

/** Stop portal token rotation for the rest of this handoff / reload. */
export function lockDesktopHandoff(): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(HANDOFF_LOCK_KEY, '1')
  } catch {
    // ignore
  }
  try {
    supabase.auth.stopAutoRefresh()
  } catch {
    // ignore
  }
}

/** True while a desktop Web-login loopback handoff is in progress. */
export function isDesktopHandoffPending(
  search?: string | URLSearchParams,
): boolean {
  if (hasHandoffLock()) return true
  const params = resolveDesktopAuthParams(search)
  return !!params.callback && isSafeDesktopCallback(params.callback)
}

/**
 * Prefer live query params; fall back to sessionStorage so handoff survives
 * navigations that strip the URL.
 */
export function resolveDesktopAuthParams(
  search?: string | URLSearchParams,
): DesktopAuthParams {
  const fromUrl = readDesktopAuthSearchParams(search)
  if (fromUrl.callback && isSafeDesktopCallback(fromUrl.callback)) {
    rememberDesktopAuthParams(fromUrl)
    return fromUrl
  }
  if (typeof window === 'undefined') {
    return { callback: null, state: null }
  }
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY)
    if (!raw) return { callback: null, state: null }
    const parsed = JSON.parse(raw) as DesktopAuthParams
    if (parsed.callback && isSafeDesktopCallback(parsed.callback)) {
      return {
        callback: parsed.callback,
        state: parsed.state ?? null,
      }
    }
  } catch {
    // ignore
  }
  return { callback: null, state: null }
}

export type DesktopHandoffResult =
  | { status: 'ok' }
  /** fetch failed (app not listening / Chrome local-network block). */
  | { status: 'unreachable' }
  /** Loopback answered but refused or failed to apply the session. */
  | { status: 'rejected'; title?: string; body?: string }

/** Notify the desktop loopback listener without leaving the portal tab. */
export async function handoffSessionToDesktop(options: {
  callback: string
  state: string | null
  accessToken: string
  refreshToken: string
}): Promise<DesktopHandoffResult> {
  const target = buildDesktopCallbackUrl(options)
  if (!target) return { status: 'unreachable' }
  try {
    const res = await fetch(target, {
      method: 'GET',
      mode: 'cors',
      cache: 'no-store',
      headers: { Accept: 'application/json' },
    })
    if (!res.ok) return { status: 'unreachable' }
    const contentType = res.headers.get('content-type') ?? ''
    if (contentType.includes('application/json')) {
      const body = (await res.json()) as {
        ok?: boolean
        title?: string
        body?: string
      }
      if (body.ok === true) return { status: 'ok' }
      return {
        status: 'rejected',
        title: typeof body.title === 'string' ? body.title : undefined,
        body: typeof body.body === 'string' ? body.body : undefined,
      }
    }
    // Older desktop builds may return HTML. Only treat as success when the
    // page title says so — never assume any HTML means the app got tokens.
    const html = await res.text()
    if (/<title>\s*Signed in\b/i.test(html)) return { status: 'ok' }
    return { status: 'rejected' }
  } catch {
    return { status: 'unreachable' }
  }
}

/**
 * After the app has the tokens: drop the portal's local copy without revoking
 * the server session, then reload so in-memory auth is gone too.
 *
 * Keep the handoff lock until after reload so refreshSession cannot race.
 */
export function releasePortalSessionToDesktop(): void {
  if (typeof window === 'undefined') return
  lockDesktopHandoff()
  try {
    sessionStorage.setItem(HANDOFF_DONE_KEY, '1')
  } catch {
    // ignore
  }
  try {
    const remove: string[] = []
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)
      if (key && /^sb-.*-auth-token$/.test(key)) remove.push(key)
    }
    for (const key of remove) localStorage.removeItem(key)
  } catch {
    // ignore
  }
  // Keep STORAGE_KEY / lock until the done page mounts — clearing them here
  // re-enables refreshIfVisible against a burned RT.
  const url = new URL(window.location.href)
  url.searchParams.delete('desktop_callback')
  url.searchParams.delete('desktop_state')
  url.searchParams.delete('access_token')
  url.searchParams.delete('refresh_token')
  window.location.replace(url.pathname + url.search + url.hash)
}

/**
 * Call from useEffect only (not during render) — avoids SSR hydration mismatch.
 * Clears the done + lock flags after reading.
 */
export function consumeDesktopHandoffDone(): boolean {
  if (typeof window === 'undefined') return false
  try {
    const done = sessionStorage.getItem(HANDOFF_DONE_KEY) === '1'
    sessionStorage.removeItem(HANDOFF_DONE_KEY)
    sessionStorage.removeItem(HANDOFF_LOCK_KEY)
    clearDesktopAuthParams()
    return done
  } catch {
    return false
  }
}

/**
 * Best-effort close after desktop handoff. Browsers only allow this for
 * script-opened windows; tabs opened by the OS often stay open — the
 * DesktopAuthDone page asks the user to close manually in that case.
 */
export function closeDesktopHandoffWindow(): void {
  if (typeof window === 'undefined') return
  try {
    window.open('', '_self')
    window.close()
  } catch {
    // ignore
  }
}
