import { formatPortalExpiry } from '@/lib/iptv-portal-expiry'
import type { CatalogPortal, PortalStatus } from './types'

function enc(s: string): string {
  return encodeURIComponent(s)
}

const STALKER_UA =
  'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3'
const STALKER_X_UA = 'Model: MAG250; Link: WiFi'

function dead(status: string, error?: string): PortalStatus {
  return {
    alive: false,
    status,
    expiry: null,
    maxConnections: null,
    timezone: null,
    categoryNames: [],
    error,
  }
}

function isMacUsername(raw: string): boolean {
  return /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(raw.trim())
}

/** Resolve product protocol — DB platform, else MAC / stalker URL heuristics. */
export function resolvePortalPlatform(
  portal: CatalogPortal,
): 'xtream' | 'm3u' | 'stalker' {
  if (
    portal.platform === 'stalker' ||
    portal.platform === 'm3u' ||
    portal.platform === 'xtream'
  ) {
    return portal.platform
  }
  if (isMacUsername(portal.username)) return 'stalker'
  const u = portal.url
  if (/\/c\/?$/i.test(u) || /portal\.php|stalker_portal/i.test(u)) {
    return 'stalker'
  }
  return 'xtream'
}

function splitOriginAndPath(raw: string): { origin: string; path: string } {
  let s = raw.trim()
  if (!s) throw new Error('empty url')
  if (!s.includes('://')) s = `http://${s}`
  const schemeEnd = s.indexOf('://')
  if (schemeEnd < 0) throw new Error('invalid_url')
  const scheme = s.slice(0, schemeEnd)
  const after = s.slice(schemeEnd + 3)
  let pathStart = after.length
  for (let i = 0; i < after.length; i++) {
    const c = after[i]
    if (c === '/' || c === '?' || c === '#') {
      pathStart = i
      break
    }
  }
  const hostPort = after.slice(0, pathStart).replace(/\/+$/, '')
  if (!hostPort) throw new Error('invalid_url')
  const rest = after.slice(pathStart)
  const pathOnly = rest.split(/[?#]/)[0] ?? ''
  return { origin: `${scheme}://${hostPort}`, path: pathOnly }
}

/** Candidate middleware paths — mirrors crates/iptv stalker_client::candidate_paths. */
export function stalkerCandidatePaths(pastedPath: string): string[] {
  const lower = pastedPath.toLowerCase()
  const out: string[] = []
  if (
    pastedPath &&
    (lower.endsWith('portal.php') || lower.endsWith('load.php'))
  ) {
    out.push(pastedPath)
  }
  const defaults = lower.includes('stalker_portal')
    ? [
        '/stalker_portal/server/load.php',
        '/portal.php',
        '/server/load.php',
      ]
    : [
        '/portal.php',
        '/server/load.php',
        '/stalker_portal/server/load.php',
      ]
  for (const p of defaults) {
    if (!out.includes(p)) out.push(p)
  }
  return out
}

function normalizeMac(mac: string): string {
  const cleaned = [...mac]
    .filter((c) => /[0-9A-Fa-f]/.test(c))
    .join('')
    .toUpperCase()
  if (cleaned.length === 12) {
    return cleaned.match(/.{2}/g)!.join(':')
  }
  const withColons = mac.trim().toUpperCase().replace(/-/g, ':')
  if (isMacUsername(withColons)) return withColons
  throw new Error('invalid_mac')
}

function deriveSerial(mac: string): string {
  const hex = [...mac].filter((c) => /[0-9A-Fa-f]/.test(c)).join('')
  return `012${hex}N`
}

function looksLikeExpiry(raw: string): boolean {
  const s = raw.trim()
  if (!s) return false
  if (/^\d+$/.test(s)) return s.length >= 9
  const lower = s.toLowerCase()
  if (lower.includes('/') || lower.includes('-')) return true
  return /jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec/i.test(lower)
}

function scalarString(v: unknown): string | null {
  if (typeof v === 'string') return v
  if (typeof v === 'number' && Number.isFinite(v)) return String(v)
  return null
}

function profileExpiryRaw(js: Record<string, unknown>): string {
  for (const key of ['exp_date', 'expire_date'] as const) {
    const s = scalarString(js[key])
    if (s?.trim()) return s
  }
  const phone = scalarString(js.phone)
  if (phone && looksLikeExpiry(phone)) return phone
  return ''
}

function unwrapJs(root: unknown): Record<string, unknown> {
  if (!root || typeof root !== 'object') return {}
  const o = root as Record<string, unknown>
  const js = o.js
  if (js && typeof js === 'object' && !Array.isArray(js)) {
    return js as Record<string, unknown>
  }
  return o
}

async function stalkerGetJs(
  endpointUrl: string,
  query: string,
  opts: {
    referer: string
    mac: string
    token?: string
    timeoutMs: number
  },
): Promise<Record<string, unknown>> {
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), opts.timeoutMs)
  try {
    const headers: Record<string, string> = {
      'User-Agent': STALKER_UA,
      'X-User-Agent': STALKER_X_UA,
      Referer: opts.referer,
      Cookie: `mac=${enc(opts.mac)}; stb_lang=en; timezone=Europe/London`,
    }
    if (opts.token) {
      headers.Authorization = `Bearer ${opts.token}`
    }
    const resp = await fetch(`${endpointUrl}?${query}`, {
      signal: ctrl.signal,
      headers,
      redirect: 'follow',
    })
    if (resp.status === 401 || resp.status === 403) {
      throw new Error('auth_failed')
    }
    if (resp.status < 200 || resp.status >= 300) {
      throw new Error(`HTTP ${resp.status}`)
    }
    const body = await resp.text()
    let parsed: unknown
    try {
      parsed = JSON.parse(body)
    } catch {
      throw new Error('invalid_json')
    }
    return unwrapJs(parsed)
  } finally {
    clearTimeout(timer)
  }
}

/**
 * Probe Stalker/Ministra — handshake → get_profile (parity with
 * crates/iptv stalker_client login).
 */
async function verifyStalkerPortal(
  portal: CatalogPortal,
  timeoutMs: number,
): Promise<PortalStatus> {
  let mac: string
  try {
    mac = normalizeMac(portal.username)
  } catch {
    return dead('invalid_mac', 'invalid_mac')
  }

  let origin: string
  let pastedPath: string
  try {
    ;({ origin, path: pastedPath } = splitOriginAndPath(portal.url))
  } catch (e) {
    return dead('error', e instanceof Error ? e.message : 'invalid_url')
  }

  const referer = `${origin}/c/`
  const serial = portal.password.trim()
    ? portal.password.trim()
    : deriveSerial(mac)
  const paths = stalkerCandidatePaths(pastedPath)
  let lastErr = 'handshake_failed'

  for (const path of paths) {
    const endpointUrl = `${origin}${path}`
    try {
      const hs = await stalkerGetJs(
        endpointUrl,
        'type=stb&action=handshake&token=&JsHttpRequest=1-xml',
        { referer, mac, timeoutMs },
      )
      const token = scalarString(hs.token)?.trim() ?? ''
      if (!token) {
        lastErr = 'handshake_failed'
        continue
      }

      // Login-shaped get_profile for expiry. Handshake success alone is
      // enough for alive — MAC was accepted even if profile is sparse.
      let expiry: string | null = null
      let timezone: string | null = null
      try {
        const sn = enc(serial)
        const profile = await stalkerGetJs(
          endpointUrl,
          `type=stb&action=get_profile&hd=1&ver=ImageDescription:%200.2.18-250;\
ImageDate:%20Fri%20Feb%2015%2015:32:44%20EET%202018;\
PORTAL%20version:%205.1.0;API%20Version:%20JS%20API%20version:%20328;\
STB%20API%20version:%20134;Player%20Engine%20version:%200x566&\
num_banks=2&sn=${sn}&stb_type=MAG250&client_type=STB&\
image_version=218&video_out=hdmi&device_id=&device_id2=&auth_second_step=0&\
hw_version=1.7-BD-00&not_valid_token=0`,
          { referer, mac, token, timeoutMs },
        )
        const expiryRaw = profileExpiryRaw(profile)
        expiry = expiryRaw ? formatPortalExpiry(expiryRaw) : null
        timezone =
          typeof profile.timezone === 'string' ? profile.timezone : null
      } catch {
        // profile optional after handshake
      }

      return {
        alive: true,
        status: 'active',
        expiry,
        maxConnections: '1',
        timezone,
        categoryNames: [],
      }
    } catch (e) {
      lastErr = e instanceof Error ? e.message : 'verify failed'
    }
  }

  return dead(
    lastErr === 'auth_failed' ? 'auth_failed' : 'dead',
    lastErr,
  )
}

/**
 * Probe Xtream `player_api.php` — the Inngest "test portal status" step.
 */
async function verifyXtreamPortal(
  portal: CatalogPortal,
  timeoutMs: number,
): Promise<PortalStatus> {
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
      return dead('invalid_json', `HTTP ${resp.status}`)
    }

    const info =
      (root.user_info as Record<string, unknown> | undefined) ?? root
    const server =
      (root.server_info as Record<string, unknown> | undefined) ?? {}
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
        info.exp_date != null
          ? formatPortalExpiry(String(info.exp_date))
          : null,
      maxConnections:
        info.max_connections != null
          ? String(info.max_connections).replaceAll('"', '')
          : null,
      timezone: typeof server.timezone === 'string' ? server.timezone : null,
      categoryNames,
    }
  } catch (e) {
    return dead('error', e instanceof Error ? e.message : 'verify failed')
  }
}

/** Probe M3U playlist URL — 200 + `#EXTM3U` / playlist-ish body. */
async function verifyM3uPortal(
  portal: CatalogPortal,
  timeoutMs: number,
): Promise<PortalStatus> {
  const url = portal.url.trim()
  if (!url) return dead('error', 'empty url')
  try {
    const ctrl = new AbortController()
    const timer = setTimeout(() => ctrl.abort(), timeoutMs)
    const resp = await fetch(url, {
      signal: ctrl.signal,
      headers: { 'User-Agent': 'ForjaCatalog/1.0' },
      redirect: 'follow',
    })
    clearTimeout(timer)
    if (resp.status < 200 || resp.status >= 300) {
      return dead('dead', `HTTP ${resp.status}`)
    }
    const body = (await resp.text()).slice(0, 4096)
    const alive =
      /#EXTM3U/i.test(body) ||
      /#EXTINF/i.test(body) ||
      /^https?:\/\//im.test(body)
    return {
      alive,
      status: alive ? 'active' : 'invalid_playlist',
      expiry: null,
      maxConnections: null,
      timezone: null,
      categoryNames: [],
      error: alive ? undefined : 'not an m3u playlist',
    }
  } catch (e) {
    return dead('error', e instanceof Error ? e.message : 'verify failed')
  }
}

/**
 * Probe portal alive status by product platform (Xtream / Stalker / M3U).
 */
export async function verifyPortalStatus(
  portal: CatalogPortal,
  opts?: { timeoutMs?: number },
): Promise<PortalStatus> {
  const timeoutMs = opts?.timeoutMs ?? 12_000
  const platform = resolvePortalPlatform(portal)
  if (platform === 'stalker') return verifyStalkerPortal(portal, timeoutMs)
  if (platform === 'm3u') return verifyM3uPortal(portal, timeoutMs)
  return verifyXtreamPortal(portal, timeoutMs)
}
