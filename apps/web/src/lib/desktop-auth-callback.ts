/**
 * Hands a Supabase session back to the Forja desktop app via a localhost
 * callback started by DesktopBrowserAuth.
 *
 * Uses fetch() so the portal tab stays put — never navigate to 127.0.0.1
 * (that opened a second browser page).
 *
 * Only http(s) loopback hosts are accepted.
 */

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

/** Notify the desktop loopback listener without leaving the portal tab. */
export async function handoffSessionToDesktop(options: {
  callback: string
  state: string | null
  accessToken: string
  refreshToken: string
}): Promise<boolean> {
  const target = buildDesktopCallbackUrl(options)
  if (!target) return false
  try {
    const res = await fetch(target, {
      method: 'GET',
      mode: 'cors',
      cache: 'no-store',
      headers: { Accept: 'application/json' },
    })
    return res.ok
  } catch {
    return false
  }
}

export function readDesktopAuthSearchParams(
  search: string | URLSearchParams = typeof window !== 'undefined'
    ? window.location.search
    : '',
): { callback: string | null; state: string | null } {
  const params =
    typeof search === 'string' ? new URLSearchParams(search) : search
  return {
    callback: params.get('desktop_callback'),
    state: params.get('desktop_state'),
  }
}
