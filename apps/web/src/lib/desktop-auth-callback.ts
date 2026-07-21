/**
 * Hands a *new* Supabase session to the Forja desktop app via a localhost
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
 * Flow: edge `mint-desktop-session` creates session B from the portal JWT;
 * only B goes to the app. The portal keeps session A (no storage wipe).
 */

import { supabase } from '@/lib/supabase'

const STORAGE_KEY = 'forja.desktop_auth'
const HANDOFF_DONE_KEY = 'forja.desktop_auth_done'
/** Brief pause while minting B / posting to loopback (portal keeps session A). */
const HANDOFF_LOCK_KEY = 'forja.desktop_auth_lock'
/** Loopback `/focus` URL — bring Forja forward when the handoff tab closes. */
const FOCUS_KEY = 'forja.desktop_auth_focus'

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

/** Pause portal auto-refresh for the mint + loopback window. */
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

export function unlockDesktopHandoff(): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.removeItem(HANDOFF_LOCK_KEY)
  } catch {
    // ignore
  }
  try {
    void supabase.auth.startAutoRefresh()
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
  /** Edge mint failed before loopback. */
  | { status: 'mint_failed'; body?: string }

type MintDesktopSessionResponse = {
  access_token?: string
  refresh_token?: string
  error?: string
}

/**
 * Ask the edge function for a fresh session B (portal JWT = session A).
 */
export async function mintDesktopSession(): Promise<
  | { ok: true; accessToken: string; refreshToken: string }
  | { ok: false; error: string }
> {
  const { data, error } = await supabase.functions.invoke<MintDesktopSessionResponse>(
    'mint-desktop-session',
    { method: 'POST', body: {} },
  )

  if (error) {
    let message = error.message || 'Could not create a desktop session.'
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

  const accessToken = data?.access_token?.trim()
  const refreshToken = data?.refresh_token?.trim()
  if (!accessToken || !refreshToken) {
    return {
      ok: false,
      error: data?.error?.trim() || 'Could not create a desktop session.',
    }
  }
  return { ok: true, accessToken, refreshToken }
}

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
 * Mint session B, post it to the desktop loopback, keep portal session A.
 */
export async function mintAndHandoffToDesktop(options: {
  callback: string
  state: string | null
}): Promise<DesktopHandoffResult> {
  lockDesktopHandoff()
  try {
    const minted = await mintDesktopSession()
    if (!minted.ok) {
      return { status: 'mint_failed', body: minted.error }
    }
    return await handoffSessionToDesktop({
      callback: options.callback,
      state: options.state,
      accessToken: minted.accessToken,
      refreshToken: minted.refreshToken,
    })
  } finally {
    unlockDesktopHandoff()
  }
}

/** Persist loopback `/focus` so Close tab can raise the desktop app. */
export function rememberDesktopFocusTarget(
  callback: string,
  state: string | null,
): void {
  if (typeof window === 'undefined') return
  if (!isSafeDesktopCallback(callback)) return
  try {
    const url = new URL(callback)
    url.pathname = '/focus'
    url.search = ''
    if (state) url.searchParams.set('state', state)
    sessionStorage.setItem(FOCUS_KEY, url.toString())
  } catch {
    // ignore
  }
}

/** Ask the desktop loopback to show + focus the Forja window (best-effort). */
export async function focusDesktopApp(): Promise<void> {
  if (typeof window === 'undefined') return
  let raw: string | null = null
  try {
    raw = sessionStorage.getItem(FOCUS_KEY)
  } catch {
    return
  }
  if (!raw) return
  try {
    const url = new URL(raw)
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return
    if (url.hostname !== '127.0.0.1' && url.hostname !== 'localhost') return
    if (url.pathname !== '/focus') return
    await fetch(url.toString(), {
      method: 'GET',
      mode: 'cors',
      cache: 'no-store',
      keepalive: true,
      headers: { Accept: 'application/json' },
    })
  } catch {
    // App not listening / already closed the focus grace window.
  }
}

/**
 * After the app has session B: clear handoff params, keep portal Auth storage,
 * show the done UI (no reload / no localStorage wipe).
 */
export function completeDesktopHandoffKeepingPortal(): void {
  if (typeof window === 'undefined') return
  const params = resolveDesktopAuthParams()
  if (params.callback) {
    rememberDesktopFocusTarget(params.callback, params.state)
  }
  unlockDesktopHandoff()
  clearDesktopAuthParams()
  try {
    sessionStorage.removeItem(HANDOFF_DONE_KEY)
  } catch {
    // ignore
  }
  const url = new URL(window.location.href)
  url.searchParams.delete('desktop_callback')
  url.searchParams.delete('desktop_state')
  url.searchParams.delete('access_token')
  url.searchParams.delete('refresh_token')
  const next = url.pathname + url.search + url.hash
  window.history.replaceState(null, '', next)
}

/**
 * Call from useEffect only (not during render) — avoids SSR hydration mismatch.
 * Legacy reload path after the old “move RT” handoff.
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
 * Best-effort close after desktop handoff. Must call window.close()
 * synchronously (same turn as the click) — awaiting focus first drops the
 * user-gesture context and browsers ignore the close (feels like a 2nd click
 * is required). Focus runs only if the tab is still open; successful close
 * uses pagehide → focusDesktopApp in DesktopAuthDone.
 */
export function closeDesktopHandoffWindow(): void {
  if (typeof window === 'undefined') return
  try {
    window.open('', '_self')
    window.close()
  } catch {
    // ignore
  }
  if (!window.closed) {
    void focusDesktopApp()
  }
}
