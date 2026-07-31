import { createHash } from 'node:crypto'
import { extractPortals } from './extract'
import { decryptFromPasteResponse } from './pastesh'
import type { CatalogPortal, DeepRefPortalHit, DeepRefRecord } from './types'
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

/** Cap stored paste / decoded body for later re-extract (bytes as UTF-16 length). */
const PAYLOAD_TEXT_MAX = 64_000

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

function hostOf(url: string): string {
  try {
    return new URL(url).hostname.toLowerCase()
  } catch {
    return ''
  }
}

function hashPayload(s: string): string {
  return createHash('sha256').update(s).digest('hex').slice(0, 40)
}

function truncatePayload(text: string | null | undefined): string | null {
  if (!text) return null
  if (text.length <= PAYLOAD_TEXT_MAX) return text
  return text.slice(0, PAYLOAD_TEXT_MAX)
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
  postId?: string,
): DeepRefPortalHit[] {
  const hits: DeepRefPortalHit[] = []
  const seenHit = new Set<string>()
  for (const p of extractPortals(text, source)) {
    const withPost: CatalogPortal = postId ? { ...p, postId } : p
    const hitKey = `${withPost.url}|${withPost.username}`.toLowerCase()
    if (!seenHit.has(hitKey)) {
      seenHit.add(hitKey)
      hits.push({
        url: withPost.url,
        username: withPost.username,
        password: withPost.password,
      })
    }
    const key = portalKey(withPost)
    const prev = acc.get(key)
    if (!prev) {
      if (acc.size < maxResults) acc.set(key, withPost)
    } else if (!prev.postId && postId) {
      acc.set(key, { ...prev, postId })
    }
  }
  return hits
}

/** Collect paste / decoded payloads from post body. Persist every ref. */
async function extractDeepPortals(
  body: string,
  acc: Map<string, CatalogPortal>,
  maxResults: number,
  postId: string,
): Promise<{
  deepRefCount: number
  l2FetchOk: number
  l2FetchFail: number
  l2ExtractCount: number
  unparsedCount: number
  refs: DeepRefRecord[]
}> {
  const refs: DeepRefRecord[] = []
  const deepLinks: Array<{ url: string; fromB64: string | null }> = []

  for (const m of body.matchAll(B64_HTTP)) {
    const raw = m[0] ?? ''
    let decoded: string
    try {
      decoded = Buffer.from(raw, 'base64').toString('utf8')
    } catch {
      refs.push({
        postId,
        refType: 'b64_text',
        refHost: '',
        payloadHash: hashPayload(raw),
        rawRef: raw,
        payloadText: null,
        fetchOk: null,
        extractCount: 0,
        needsRecheck: true,
        portals: [],
      })
      continue
    }
    if (decoded.startsWith('http') && isPasteSite(decoded)) {
      deepLinks.push({ url: decoded, fromB64: raw })
    } else if (!decoded.startsWith('http') && decoded.includes(':')) {
      const hits = addExtracted(
        acc,
        decoded,
        'catalog-decoded',
        maxResults,
        postId,
      )
      refs.push({
        postId,
        refType: 'b64_text',
        refHost: '',
        payloadHash: hashPayload(raw),
        rawRef: raw,
        payloadText: truncatePayload(decoded),
        fetchOk: null,
        extractCount: hits.length,
        needsRecheck: hits.length === 0,
        portals: hits,
      })
    } else {
      refs.push({
        postId,
        refType: 'b64_text',
        refHost: '',
        payloadHash: hashPayload(raw),
        rawRef: raw,
        payloadText: truncatePayload(decoded),
        fetchOk: null,
        extractCount: 0,
        needsRecheck: true,
        portals: [],
      })
    }
  }

  for (const m of body.matchAll(RAW_PASTE)) {
    deepLinks.push({ url: m[0] ?? '', fromB64: null })
  }

  const seen = new Set<string>()
  const unique = deepLinks.filter((d) => {
    if (!d.url || seen.has(d.url)) return false
    seen.add(d.url)
    return true
  }).slice(0, 4)

  let l2FetchOk = 0
  let l2FetchFail = 0
  let l2ExtractCount = 0

  for (const dl of unique) {
    if (acc.size >= maxResults) break
    if (dl.fromB64) {
      refs.push({
        postId,
        refType: 'b64_url',
        refHost: hostOf(dl.url),
        payloadHash: hashPayload(dl.fromB64),
        rawRef: dl.fromB64,
        payloadText: truncatePayload(dl.url),
        fetchOk: null,
        extractCount: 0,
        needsRecheck: false,
        portals: [],
      })
    }
    const text = await fetchPasteBody(dl.url)
    if (text) {
      l2FetchOk++
      const hits = addExtracted(acc, text, 'catalog-deep', maxResults, postId)
      l2ExtractCount += hits.length
      refs.push({
        postId,
        refType: 'paste_url',
        refHost: hostOf(dl.url),
        payloadHash: hashPayload(dl.url),
        rawRef: dl.url,
        payloadText: truncatePayload(text),
        fetchOk: true,
        extractCount: hits.length,
        needsRecheck: hits.length === 0,
        portals: hits,
      })
    } else {
      l2FetchFail++
      refs.push({
        postId,
        refType: 'paste_url',
        refHost: hostOf(dl.url),
        payloadHash: hashPayload(dl.url),
        rawRef: dl.url,
        payloadText: null,
        fetchOk: false,
        extractCount: 0,
        needsRecheck: true,
        portals: [],
      })
    }
  }

  const unparsedCount = refs.filter((r) => r.needsRecheck).length
  return {
    deepRefCount: refs.length,
    l2FetchOk,
    l2FetchFail,
    l2ExtractCount,
    unparsedCount,
    refs,
  }
}

export type ScrapePageFunnel = {
  deepRefCount: number
  l2FetchOk: number
  l2FetchFail: number
  l2ExtractCount: number
  unparsedCount: number
  /** Portals from post body only (before deep). */
  l1OnlyCount: number
}

export type ScrapePageResult = {
  portals: CatalogPortal[]
  /** New Reddit t3_ ids processed this page. */
  postIds: string[]
  nextAfter: string | null
  subreddit: string
  /** New posts processed (not already in known set). */
  postsSeen: number
  /** Hit a post_id already in DB — stop paginating older listings. */
  hitWatermark: boolean
  deepRefs: DeepRefRecord[]
  funnel: ScrapePageFunnel
}

/** One Reddit /new page → extracted portals + pagination cursor. */
export async function scrapeCatalogPage(
  after: string | null | undefined,
  maxResults = 50,
  knownPostIds: ReadonlySet<string> = new Set(),
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

  const emptyFunnel: ScrapePageFunnel = {
    deepRefCount: 0,
    l2FetchOk: 0,
    l2FetchFail: 0,
    l2ExtractCount: 0,
    unparsedCount: 0,
    l1OnlyCount: 0,
  }

  if (!root?.data) {
    const nextAfter =
      subIdx + 1 < CATALOG_SUBS.length ? `reddit:${subIdx + 1}:` : null
    return {
      portals: [],
      postIds: [],
      nextAfter,
      subreddit: sub,
      postsSeen: 0,
      hitWatermark: false,
      deepRefs: [],
      funnel: emptyFunnel,
    }
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
  const postIds: string[] = []
  const deepRefs: DeepRefRecord[] = []
  const funnel: ScrapePageFunnel = { ...emptyFunnel }
  let hitWatermark = false

  for (const child of posts) {
    if (acc.size >= maxResults) break
    const d = child.data
    if (!d) continue
    const rawId = String(d.name ?? d.id ?? '').trim()
    const postId = !rawId
      ? undefined
      : rawId.startsWith('t3_')
        ? rawId
        : `t3_${rawId}`
    if (postId && knownPostIds.has(postId)) {
      hitWatermark = true
      break
    }
    if (postId) postIds.push(postId)
    const title = String(d.title ?? '')
    const selftext = String(d.selftext ?? '')
    // Extract in-memory only — never persist title/selftext.
    const body = `${title}\n${selftext}`
    const beforeL1 = acc.size
    addExtracted(acc, body, 'catalog', maxResults, postId)
    funnel.l1OnlyCount += Math.max(0, acc.size - beforeL1)
    if (acc.size >= maxResults) break
    if (!postId) continue
    const deep = await extractDeepPortals(body, acc, maxResults, postId)
    funnel.deepRefCount += deep.deepRefCount
    funnel.l2FetchOk += deep.l2FetchOk
    funnel.l2FetchFail += deep.l2FetchFail
    funnel.l2ExtractCount += deep.l2ExtractCount
    funnel.unparsedCount += deep.unparsedCount
    deepRefs.push(...deep.refs)
  }

  return {
    portals: [...acc.values()],
    postIds,
    nextAfter: hitWatermark ? null : nextAfter,
    subreddit: sub,
    postsSeen: postIds.length,
    hitWatermark,
    deepRefs,
    funnel,
  }
}
