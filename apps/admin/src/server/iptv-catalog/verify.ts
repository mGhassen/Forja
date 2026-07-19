import type { CatalogPortal, PortalStatus } from './types'

function enc(s: string): string {
  return encodeURIComponent(s)
}

/**
 * Probe Xtream `player_api.php` — the Inngest "test portal status" step.
 */
export async function verifyPortalStatus(
  portal: CatalogPortal,
  opts?: { timeoutMs?: number },
): Promise<PortalStatus> {
  const timeoutMs = opts?.timeoutMs ?? 12_000
  const base = portal.url.replace(/\/+$/, '')
  const url = `${base}/player_api.php?username=${enc(portal.username)}&password=${enc(portal.password)}`

  try {
    const ctrl = new AbortController()
    const timer = setTimeout(() => ctrl.abort(), timeoutMs)
    const resp = await fetch(url, {
      signal: ctrl.signal,
      headers: { 'User-Agent': 'ForjaCatalog/1.0' },
    })
    clearTimeout(timer)
    const body = await resp.text()
    let root: Record<string, unknown> = {}
    try {
      root = JSON.parse(body) as Record<string, unknown>
    } catch {
      return {
        alive: false,
        status: 'invalid_json',
        expiry: null,
        maxConnections: null,
        timezone: null,
        categoryNames: [],
        error: `HTTP ${resp.status}`,
      }
    }

    const info = (root.user_info as Record<string, unknown> | undefined) ?? root
    const server = (root.server_info as Record<string, unknown> | undefined) ?? {}
    const auth = String(info.auth ?? '')
    const status = String(info.status ?? '').toLowerCase()
    const alive =
      auth === '1' || status === 'active' || root.user_info != null

    const categoryNames: string[] = []
    if (alive) {
      try {
        const catUrl = `${base}/player_api.php?username=${enc(portal.username)}&password=${enc(portal.password)}&action=get_live_categories`
        const catCtrl = new AbortController()
        const catTimer = setTimeout(() => catCtrl.abort(), timeoutMs)
        const catResp = await fetch(catUrl, {
          signal: catCtrl.signal,
          headers: { 'User-Agent': 'ForjaCatalog/1.0' },
        })
        clearTimeout(catTimer)
        const catJson = (await catResp.json()) as unknown
        if (Array.isArray(catJson)) {
          for (const c of catJson.slice(0, 80)) {
            const name = (c as { category_name?: string }).category_name
            if (name) categoryNames.push(name)
          }
        }
      } catch {
        // categories optional
      }
    }

    return {
      alive,
      status: status || (alive ? 'active' : 'dead'),
      expiry:
        info.exp_date != null ? String(info.exp_date) : null,
      maxConnections:
        info.max_connections != null
          ? String(info.max_connections).replaceAll('"', '')
          : null,
      timezone: typeof server.timezone === 'string' ? server.timezone : null,
      categoryNames,
    }
  } catch (e) {
    return {
      alive: false,
      status: 'error',
      expiry: null,
      maxConnections: null,
      timezone: null,
      categoryNames: [],
      error: e instanceof Error ? e.message : 'verify failed',
    }
  }
}
