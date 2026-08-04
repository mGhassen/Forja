import { createHash } from 'node:crypto'
import { extractPortals } from './extract'
import { decryptFromPasteResponse } from './pastesh'
import type {
  CatalogPortal,
  DeepRefPortalHit,
  DeepRefRecord,
  PendingDeepRefRow,
} from './types'
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

const PASTE_FETCH_TIMEOUT_MS = 12_000
/** Reddit OAuth / listing — no timeout hung the whole Vercel invoke until 300s kill. */
const REDDIT_FETCH_TIMEOUT_MS = 15_000

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), timeoutMs)
  try {
    return await fetch(url, { ...init, signal: ctrl.signal })
  } finally {
    clearTimeout(timer)
  }
}

type Cursor = { subIdx: number; after: string | null }

/** Posts per Reddit /new request = one Inngest step. */
export const SCRAPE_PAGE_SIZE = 10

/** `reddit:<subIdx>:<redditAfter>` — one listing page at a time. */
export function parseCursor(after: string | null | undefined): Cursor {
  if (!after || after === 'null') return { subIdx: 0, after: null }
  // Mid-skip format from earlier batching: reddit:0:12:t3_xxx → treat as page start at after
  const withSkip = /^reddit:(\d+):(\d+):(.*)$/.exec(after)
  if (withSkip) {
    return {
      subIdx: Math.min(Number(withSkip[1]) || 0, CATALOG_SUBS.length - 1),
      after: withSkip[3] || null,
    }
  }
  const m = /^reddit:(\d+):(.*)$/.exec(after)
  if (!m) return { subIdx: 0, after: after || null }
  return {
    subIdx: Math.min(Number(m[1]) || 0, CATALOG_SUBS.length - 1),
    after: m[2] || null,
  }
}

function encodeCursor(subIdx: number, redditAfter: string | null): string {
  return `reddit:${subIdx}:${redditAfter ?? ''}`
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
      const resp = await fetchWithTimeout(
        'https://www.reddit.com/api/v1/access_token',
        {
          method: 'POST',
          headers: {
            'User-Agent': OAUTH_UA,
            Authorization: `Basic ${auth}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: 'grant_type=https%3A%2F%2Foauth.reddit.com%2Fgrants%2Finstalled_client&device_id=DO_NOT_TRACK_THIS_DEVICE',
        },
        REDDIT_FETCH_TIMEOUT_MS,
      )
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
  limit = SCRAPE_PAGE_SIZE,
): Promise<unknown | null> {
  const token = await getOauthToken()
  if (!token) return null
  const pageSize = Math.max(1, Math.min(limit, 100))
  let url = `https://oauth.reddit.com/r/${sub}/new?limit=${pageSize}&sort=new&raw_json=1`
  if (after) url += `&after=${encodeURIComponent(after)}`
  let resp: Response
  try {
    resp = await fetchWithTimeout(
      url,
      {
        headers: {
          'User-Agent': OAUTH_UA,
          Authorization: `Bearer ${token}`,
        },
      },
      REDDIT_FETCH_TIMEOUT_MS,
    )
  } catch {
    cachedToken = null
    return null
  }
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
      const resp = await fetchWithTimeout(
        fetchUrl,
        { headers: { 'User-Agent': SCRAPE_UA } },
        PASTE_FETCH_TIMEOUT_MS,
      )
      if (!resp.ok) return null
      const raw = await resp.text()
      const decrypted = decryptFromPasteResponse(url, raw)
      return decrypted && decrypted.length > 0 ? decrypted : null
    }

    const fetchUrl = rewritePasteUrl(url)
    const resp = await fetchWithTimeout(
      fetchUrl,
      {
        headers: {
          'User-Agent': SCRAPE_UA,
          Accept: 'text/html,application/json,*/*',
        },
      },
      PASTE_FETCH_TIMEOUT_MS,
    )
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
    const hitKey =
      `${p.platform}|${p.url}|${p.username}|${p.type}|${p.output}`.toLowerCase()
    if (!seenHit.has(hitKey)) {
      seenHit.add(hitKey)
      hits.push({
        platform: p.platform,
        type: p.type,
        output: p.output,
        url: p.url,
        username: p.username,
        password: p.password,
        expiry: p.expiry ?? null,
        maxConnections: p.maxConnections ?? null,
        timezone: p.timezone ?? null,
        regionPrimary: p.regionPrimary,
        regionTags: p.regionTags,
        regionConfidence: p.regionConfidence,
        allowedOutputs: p.allowedOutputs ?? null,
      })
    }
    // Pool map: every platform with creds (xtream / m3u / stalker).
    if (!p.username) continue
    if (!p.password && p.platform !== 'stalker') continue
    const withPost: CatalogPortal = {
      url: p.url,
      username: p.username,
      password: p.password,
      source: p.source,
      ...(postId ? { postId } : {}),
      expiry: p.expiry ?? null,
      maxConnections: p.maxConnections ?? null,
      timezone: p.timezone ?? null,
      regionPrimary: p.regionPrimary,
      regionTags: p.regionTags,
      regionConfidence: p.regionConfidence,
      allowedOutputs: p.allowedOutputs ?? null,
    }
    const key = portalKey(withPost)
    const prev = acc.get(key)
    if (!prev) {
      if (acc.size < maxResults) acc.set(key, withPost)
    } else {
      acc.set(key, {
        ...prev,
        postId: prev.postId || postId,
        expiry: prev.expiry ?? withPost.expiry,
        maxConnections: prev.maxConnections ?? withPost.maxConnections,
        timezone: prev.timezone ?? withPost.timezone,
        regionPrimary: prev.regionPrimary ?? withPost.regionPrimary,
        regionTags: prev.regionTags?.length
          ? prev.regionTags
          : withPost.regionTags,
        regionConfidence:
          prev.regionConfidence && prev.regionConfidence > 0
            ? prev.regionConfidence
            : withPost.regionConfidence,
        allowedOutputs: prev.allowedOutputs ?? withPost.allowedOutputs,
      })
    }
  }
  return hits
}

/** Pending paste fetch — deep ref (base64+paste_url) already saved. */
export type PendingPaste = {
  postId: string
  payloadHash: string
  url: string
  base64: string
}

/**
 * One row per find: base64 + paste_url stubs only.
 * No paste HTTP and no portal extract — that is the process phase.
 */
function collectDeepRefs(
  body: string,
  _acc: Map<string, CatalogPortal>,
  _maxResults: number,
  postId: string,
): {
  refs: DeepRefRecord[]
  pendingPastes: PendingPaste[]
} {
  const refs: DeepRefRecord[] = []
  const pendingPastes: PendingPaste[] = []
  const seenPaste = new Set<string>()

  for (const m of body.matchAll(B64_HTTP)) {
    const raw = m[0] ?? ''
    let decoded: string
    try {
      decoded = Buffer.from(raw, 'base64').toString('utf8')
    } catch {
      const hash = hashPayload(raw)
      refs.push({
        postId,
        base64: raw,
        pasteUrl: '',
        pasteBody: null,
        payloadHash: hash,
        refHost: '',
        fetchOk: null,
        extractCount: 0,
        needsRecheck: true,
        portals: [],
      })
      continue
    }

    if (decoded.startsWith('http') && isPasteSite(decoded)) {
      if (seenPaste.has(decoded)) continue
      seenPaste.add(decoded)
      const hash = hashPayload(`${raw}|${decoded}`)
      refs.push({
        postId,
        base64: raw,
        pasteUrl: decoded,
        pasteBody: null,
        payloadHash: hash,
        refHost: hostOf(decoded),
        fetchOk: null,
        extractCount: 0,
        needsRecheck: false,
        portals: [],
      })
      pendingPastes.push({
        postId,
        payloadHash: hash,
        url: decoded,
        base64: raw,
      })
    } else if (!decoded.startsWith('http') && decoded.includes(':')) {
      // Collect only — extract portals in process phase from paste_body.
      refs.push({
        postId,
        base64: raw,
        pasteUrl: '',
        pasteBody: truncatePayload(decoded),
        payloadHash: hashPayload(raw),
        refHost: '',
        fetchOk: null,
        extractCount: 0,
        needsRecheck: true,
        portals: [],
      })
    } else {
      refs.push({
        postId,
        base64: raw,
        pasteUrl: '',
        pasteBody: truncatePayload(decoded),
        payloadHash: hashPayload(raw),
        refHost: '',
        fetchOk: null,
        extractCount: 0,
        needsRecheck: true,
        portals: [],
      })
    }
  }

  for (const m of body.matchAll(RAW_PASTE)) {
    const url = m[0] ?? ''
    if (!url || seenPaste.has(url)) continue
    seenPaste.add(url)
    const hash = hashPayload(`|${url}`)
    refs.push({
      postId,
      base64: '',
      pasteUrl: url,
      pasteBody: null,
      payloadHash: hash,
      refHost: hostOf(url),
      fetchOk: null,
      extractCount: 0,
      needsRecheck: true,
      portals: [],
    })
    pendingPastes.push({
      postId,
      payloadHash: hash,
      url,
      base64: '',
    })
  }

  return { refs, pendingPastes }
}

/** Fetch paste body; return updated deep ref (same base64+paste_url row). */
export async function resolvePendingPastes(
  pending: PendingPaste[],
  acc: Map<string, CatalogPortal>,
  maxResults: number,
): Promise<{
  refs: DeepRefRecord[]
  l2FetchOk: number
  l2FetchFail: number
  l2ExtractCount: number
}> {
  const refs: DeepRefRecord[] = []
  let l2FetchOk = 0
  let l2FetchFail = 0
  let l2ExtractCount = 0

  for (const dl of pending) {
    if (acc.size >= maxResults) break
    const text = await fetchPasteBody(dl.url)
    if (text) {
      l2FetchOk++
      const hits = addExtracted(
        acc,
        text,
        'catalog-deep',
        maxResults,
        dl.postId,
      )
      l2ExtractCount += hits.length
      refs.push({
        postId: dl.postId,
        base64: dl.base64,
        pasteUrl: dl.url,
        pasteBody: truncatePayload(text),
        payloadHash: dl.payloadHash,
        refHost: hostOf(dl.url),
        fetchOk: true,
        extractCount: hits.length,
        needsRecheck: hits.length === 0,
        portals: hits,
      })
    } else {
      l2FetchFail++
      refs.push({
        postId: dl.postId,
        base64: dl.base64,
        pasteUrl: dl.url,
        pasteBody: null,
        payloadHash: dl.payloadHash,
        refHost: hostOf(dl.url),
        fetchOk: false,
        extractCount: 0,
        needsRecheck: true,
        portals: [],
      })
    }
  }

  return { refs, l2FetchOk, l2FetchFail, l2ExtractCount }
}

/** Process one collected deep_ref: fetch paste if needed, extract portals. */
export async function processDeepRefRow(
  row: PendingDeepRefRow,
  maxResults = 500,
): Promise<{
  ref: DeepRefRecord
  l2FetchOk: number
  l2FetchFail: number
  l2ExtractCount: number
}> {
  const acc = new Map<string, CatalogPortal>()
  let pasteBody = row.paste_body
  let fetchOk: boolean | null = row.fetch_ok
  let l2FetchOk = 0
  let l2FetchFail = 0

  const pasteUrl = String(row.paste_url ?? '').trim()
  if (pasteUrl && fetchOk == null) {
    const text = await fetchPasteBody(pasteUrl)
    if (text) {
      pasteBody = truncatePayload(text)
      fetchOk = true
      l2FetchOk = 1
    } else {
      fetchOk = false
      l2FetchFail = 1
    }
  } else if (!pasteUrl && pasteBody) {
    // Inline base64 body already collected — mark processed so it leaves the queue.
    fetchOk = true
  }

  const hits: DeepRefPortalHit[] = pasteBody
    ? addExtracted(
        acc,
        pasteBody,
        pasteUrl ? 'catalog-deep' : 'catalog-decoded',
        maxResults,
        row.post_id,
      )
    : []

  return {
    ref: {
      postId: row.post_id,
      base64: row.base64 ?? '',
      pasteUrl,
      pasteBody,
      payloadHash: row.payload_hash,
      refHost: row.ref_host ?? hostOf(pasteUrl),
      fetchOk,
      extractCount: hits.length,
      needsRecheck: hits.length === 0,
      portals: hits,
    },
    l2FetchOk,
    l2FetchFail,
    l2ExtractCount: hits.length,
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
  /** Base64 refs with type + decoded output — persist BEFORE paste fetch. */
  deepRefs: DeepRefRecord[]
  /** Paste URLs to fetch after deepRefs are saved. */
  pendingPastes: PendingPaste[]
  funnel: ScrapePageFunnel
}

/**
 * One Reddit /new page (SCRAPE_PAGE_SIZE posts) → L1 + base64 decode.
 * Does NOT fetch pastes — caller persists deepRefs then calls resolvePendingPastes.
 */
export async function scrapeCatalogPage(
  after: string | null | undefined,
  maxResults = 50,
  knownPostIds: ReadonlySet<string> = new Set(),
  pageSize = SCRAPE_PAGE_SIZE,
): Promise<ScrapePageResult> {
  const cursor = parseCursor(after)
  let subIdx = cursor.subIdx
  if (subIdx >= CATALOG_SUBS.length) subIdx = 0
  const sub = CATALOG_SUBS[subIdx]!
  const redditAfter = cursor.after

  const root = (await fetchOauthListing(sub, redditAfter, pageSize)) as {
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
      subIdx + 1 < CATALOG_SUBS.length ? encodeCursor(subIdx + 1, null) : null
    return {
      portals: [],
      postIds: [],
      nextAfter,
      subreddit: sub,
      postsSeen: 0,
      hitWatermark: false,
      deepRefs: [],
      pendingPastes: [],
      funnel: emptyFunnel,
    }
  }

  const posts = root.data.children ?? []
  const nextRaw = root.data.after
  const hasMoreListing = Boolean(nextRaw && nextRaw !== 'null')
  const nextListingAfter = hasMoreListing
    ? encodeCursor(subIdx, nextRaw ?? null)
    : subIdx + 1 < CATALOG_SUBS.length
      ? encodeCursor(subIdx + 1, null)
      : null

  const acc = new Map<string, CatalogPortal>()
  const postIds: string[] = []
  const deepRefs: DeepRefRecord[] = []
  const pendingPastes: PendingPaste[] = []
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
    const deep = collectDeepRefs(body, acc, maxResults, postId)
    funnel.deepRefCount += deep.refs.length
    funnel.unparsedCount += deep.refs.filter((r) => r.needsRecheck).length
    deepRefs.push(...deep.refs)
    pendingPastes.push(...deep.pendingPastes)
  }

  return {
    portals: [...acc.values()],
    postIds,
    nextAfter: hitWatermark ? null : nextListingAfter,
    subreddit: sub,
    postsSeen: postIds.length,
    hitWatermark,
    deepRefs,
    pendingPastes,
    funnel,
  }
}
