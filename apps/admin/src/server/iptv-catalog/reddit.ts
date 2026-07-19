import { extractPortals } from './extract'
import type { CatalogPortal } from './types'
import { portalKey } from './types'

const OAUTH_UA = 'Forja/1.3.6 (by /u/ForjaApp)'
const OAUTH_CLIENT_IDS = ['ohXpoqrZYub1kg', 'NOe2iKrPPzwscA', 'JrPdG8Z6dkWNxA']
const CATALOG_SUBS = ['IPTV_ZONENEW', 'FreeIPTV', 'iptvguru', 'IPTVfree']

type Cursor = { subIdx: number; after: string | null }

export function parseCursor(after: string | null | undefined): Cursor {
  if (!after || after === 'null') return { subIdx: 0, after: null }
  // reddit:{subIdx}:{fullnameAfter}
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
    for (const p of extractPortals(body, 'catalog')) {
      if (acc.size >= maxResults) break
      acc.set(portalKey(p), p)
    }
  }

  return {
    portals: [...acc.values()],
    nextAfter,
    subreddit: sub,
    postsSeen: posts.length,
  }
}
