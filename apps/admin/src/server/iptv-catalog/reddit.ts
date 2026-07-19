import { extractPortals } from './extract'
import { decryptFromPasteResponse } from './pastesh'
import type { CatalogPortal } from './types'
import { portalKey } from './types'

const OAUTH_UA = 'Forja/1.3.6 (by /u/ForjaApp)'
const SCRAPE_UA =
  'Mozilla/5.0 (Linux; Android 11; Forja) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36'
const OAUTH_CLIENT_IDS = ['ohXpoqrZYub1kg', 'NOe2iKrPPzwscA', 'JrPdG8Z6dkWNxA']

/** Banned / 404 subs dropped — only live listing source for catalog scrape. */
const CATALOG_SUBS = ['IPTV_ZONENEW']

const PASTE_DOMAINS = [
  'paste.sh',
  'pastebin.com',
  'justpaste.it',
  'controlc.com',
  'pastes.dev',
  'text.is',
  'rentry.co',
]

const B64_HTTP = /aHR0c[a-zA-Z0-9+/=]{10,}/g
const RAW_PASTE =
  /https?:\/\/(?:paste\.sh|pastebin\.com|justpaste\.it|controlc\.com|pastes\.dev|text\.is|rentry\.co)\/[a-zA-Z0-9#_=-]+/gi

type Cursor = { subIdx: number; after: string | null }

export function parseCursor(after: string | null | undefined): Cursor {
  if (!after || after === 'null') return { subIdx: 0, after: null }
  const m = /^reddit:(\d+):(.*)$/.exec(after)
  if (!m) return { subIdx: 0, after: after || null }
  return {
    subIdx: Math.min(Number(m[1]) || 0, CATALOG_SUBS.length - 1),
    after: m[2] || null,
  }
}

let cachedToken: { token: string; expiry: number; idx: number } | null = null

async function getOauthToken(): Promise<string | null> {
  if (cachedToken && Date.now() < cachedToken.expiry) return cachedToken.token

  const start = cachedToken?.idx ?? 0
  for (let i = 0; i < OAUTH_CLIENT_IDS.length; i++) {
    const idx = (start + i) % OAUTH_CLIENT_IDS.length
    const clientId = OAUTH_CLIENT_IDS[idx]!
    const auth = btoa(`${clientId}:`)
    try {
      const resp = await fetch('https://www.reddit.com/api/v1/access_token', {
        method: 'POST',
        headers: {
          'User-Agent': OAUTH_UA,
          Authorization: `Basic ${auth}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=https%3A%2F%2Foauth.reddit.com%2Fgrants%2Finstalled_client&device_id=DO_NOT_TRACK_THIS_DEVICE',
      })
      if (!resp.ok) continue
      const json = (await resp.json()) as {
        access_token?: string
        expires_in?: number
      }
      if (!json.access_token) continue
      cachedToken = {
        token: json.access_token,
        expiry: Date.now() + ((json.expires_in ?? 3600) - 60) * 1000,
        idx,
      }
      return json.access_token
    } catch {
      // try next client
    }
  }
  cachedToken = null
  return null
}

async function fetchOauthListing(
  sub: string,
  after: string | null,
): Promise<unknown | null> {
  const token = await getOauthToken()
  if (!token) return null
  let url = `https://oauth.reddit.com/r/${sub}/new?limit=100&sort=new&raw_json=1`
  if (after) url += `&after=${encodeURIComponent(after)}`
  const resp = await fetch(url, {
    headers: {
      'User-Agent': OAUTH_UA,
      Authorization: `Bearer ${token}`,
    },
  })
  if (!resp.ok) {
    cachedToken = null
    return null
  }
  const text = await resp.text()
  const trimmed = text.trimStart()
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
    cachedToken = null
    return null
  }
  try {
    return JSON.parse(text)
  } catch {
    cachedToken = null
    return null
  }
}

function isPasteSite(url: string): boolean {
  const lower = url.toLowerCase()
  return PASTE_DOMAINS.some((d) => lower.includes(d))
}

function lastPathSegment(url: string): string | null {
  let s = url
  const h = s.indexOf('#')
  if (h >= 0) s = s.slice(0, h)
  const q = s.indexOf('?')
  if (q >= 0) s = s.slice(0, q)
  const slash = s.lastIndexOf('/')
  if (slash < 0) return null
  const seg = s.slice(slash + 1).trim()
  return seg || null
}

function rewritePasteUrl(url: string): string {
  if (url.includes('pastebin.com/') && !url.includes('/raw/')) {
    const id = lastPathSegment(url)
    if (id) return `https://pastebin.com/raw/${id}`
  }
  if (url.includes('pastes.dev/')) {
    const id = lastPathSegment(url)
    if (id) return `https://api.pastes.dev/${id}`
  }
  if (url.includes('rentry.co/') && !url.includes('/raw')) {
    const id = lastPathSegment(url)
    if (id) return `https://rentry.co/${id}/raw`
  }
  return url
}

async function fetchPasteBody(url: string): Promise<string | null> {
  try {
    if (url.includes('paste.sh/') && url.includes('#')) {
      const hashIdx = url.indexOf('#')
      const baseUrl = url.slice(0, hashIdx)
      const fetchUrl = `${baseUrl}.txt`
      const resp = await fetch(fetchUrl, {
        headers: { 'User-Agent': SCRAPE_UA },
      })
      if (!resp.ok) return null
      const raw = await resp.text()
      const decrypted = decryptFromPasteResponse(url, raw)
      return decrypted && decrypted.length > 0 ? decrypted : null
    }

    const fetchUrl = rewritePasteUrl(url)
    const resp = await fetch(fetchUrl, {
      headers: {
        'User-Agent': SCRAPE_UA,
        Accept: 'text/html,application/json,*/*',
      },
    })
    if (!resp.ok) return null
    const body = await resp.text()
    return body.length > 0 ? body : null
  } catch {
    return null
  }
}

function addExtracted(
  acc: Map<string, CatalogPortal>,
  text: string,
  source: string,
  maxResults: number,
) {
  for (const p of extractPortals(text, source)) {
    if (acc.size >= maxResults) break
    acc.set(portalKey(p), p)
  }
}

/** Collect paste / decoded payloads from post body (Rust process_oauth_deep_links). */
async function extractDeepPortals(
  body: string,
  acc: Map<string, CatalogPortal>,
  maxResults: number,
) {
  const deepLinks: string[] = []

  for (const m of body.matchAll(B64_HTTP)) {
    const raw = m[0] ?? ''
    let decoded: string
    try {
      decoded = Buffer.from(raw, 'base64').toString('utf8')
    } catch {
      continue
    }
    if (decoded.startsWith('http') && isPasteSite(decoded)) {
      deepLinks.push(decoded)
    } else if (!decoded.startsWith('http') && decoded.includes(':')) {
      addExtracted(acc, decoded, 'catalog-decoded', maxResults)
    }
  }

  for (const m of body.matchAll(RAW_PASTE)) {
    deepLinks.push(m[0] ?? '')
  }

  const seen = new Set<string>()
  const unique = deepLinks.filter((u) => {
    if (!u || seen.has(u)) return false
    seen.add(u)
    return true
  }).slice(0, 4)

  for (const dl of unique) {
    if (acc.size >= maxResults) break
    const text = await fetchPasteBody(dl)
    if (text) addExtracted(acc, text, 'catalog-deep', maxResults)
  }
}

export type ScrapePageResult = {
  portals: CatalogPortal[]
  nextAfter: string | null
  subreddit: string
  postsSeen: number
}

/** One Reddit /new page → extracted portals + pagination cursor. */
export async function scrapeCatalogPage(
  after: string | null | undefined,
  maxResults = 50,
): Promise<ScrapePageResult> {
  const cursor = parseCursor(after)
  let subIdx = cursor.subIdx
  if (subIdx >= CATALOG_SUBS.length) subIdx = 0
  const sub = CATALOG_SUBS[subIdx]!
  const redditAfter = cursor.after

  const root = (await fetchOauthListing(sub, redditAfter)) as {
    data?: {
      children?: Array<{ data?: Record<string, unknown> }>
      after?: string | null
    }
  } | null

  if (!root?.data) {
    const nextAfter =
      subIdx + 1 < CATALOG_SUBS.length ? `reddit:${subIdx + 1}:` : null
    return { portals: [], nextAfter, subreddit: sub, postsSeen: 0 }
  }

  const posts = root.data.children ?? []
  const nextRaw = root.data.after
  const hasMore = Boolean(nextRaw && nextRaw !== 'null')
  const nextAfter = hasMore
    ? `reddit:${subIdx}:${nextRaw}`
    : subIdx + 1 < CATALOG_SUBS.length
      ? `reddit:${subIdx + 1}:`
      : null

  const acc = new Map<string, CatalogPortal>()
  for (const child of posts) {
    if (acc.size >= maxResults) break
    const d = child.data
    if (!d) continue
    const title = String(d.title ?? '')
    const selftext = String(d.selftext ?? '')
    const body = `${title}\n${selftext}`
    addExtracted(acc, body, 'catalog', maxResults)
    if (acc.size >= maxResults) break
    await extractDeepPortals(body, acc, maxResults)
  }

  return {
    portals: [...acc.values()],
    nextAfter,
    subreddit: sub,
    postsSeen: posts.length,
  }
}
