import { formatPortalExpiry } from '@/lib/iptv-portal-expiry'
import { classifyRegion, classifyRegionFromNote } from './region'
import type { CatalogPortal, RegionGuess } from './types'
import { portalKey } from './types'

/** Xtream-style host + user + pass in query (optional type/output). */
const URL_PARAM = /(https?:\/\/[^?\s"'<]+)\?([^\s"'<)\]]*)/gi

const LABEL_HOST_FIRST =
  /(?:(?:🔗|🌍|🌐)\s*)?(?:Portal|Host(?:\s*URL)?|H[ᴏo]s[ᴛt]|Panel|Server|S[ᴇe]rv[ᴇe]r|ꜱᴇʀᴠᴇʀ|URL)\W+(https?:\/\/[^<\s"']+).{1,500}?(?:(?:👤|👑)\s*)?(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\W+([^\s|<"'\n]+).{1,200}?(?:(?:🔑|🔐)\s*)?(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\W+([^\s|<"'\n]+)/gis

const LABEL_USER_FIRST =
  /(?:(?:👤|👑)\s*)?(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\W+([^\s|<"'\n]+).{1,400}?(?:(?:🔑|🔐)\s*)?(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\W+([^\s|<"'\n]+).{1,400}?(?:(?:🔗|🌍|🌐)\s*)?(?:Portal|Host(?:\s*URL)?|H[ᴏo]s[ᴛt]|Panel|Server|S[ᴇe]rv[ᴇe]r|ꜱᴇʀᴠᴇʀ|URL)\W+(https?:\/\/[^<\s"']+)/gis

/**
 * IPTV_ZONENEW status cards: `🔗 http://…` then later `👤 USERNAME :` / `🔑 PASSWORD :`.
 * Emoji on the link is enough — no Host/URL word required.
 */
const EMOJI_LINK = /(?:🔗|🌍|🌐)\s*(https?:\/\/[^\s<"']+)/gi

/** Emoji-required so we never match `username=` inside get.php query strings. */
const EMOJI_CREDS =
  /(?:👤|👑)\s*(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\s*[:=]\s*([^\s|<"'\n]+)[\s\S]{0,240}?(?:🔑|🔐)\s*(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\s*[:=]\s*([^\s|<"'\n]+)/gi

const TABLE_LINE =
  /^[^\S\n]*((?:(?:\d{1,3}\.){3}\d{1,3}|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,})):([1-9]\d{1,4})[^\S\n]+([A-Za-z0-9._@+-]{3,64}):(\S{3,64})([^\n]*)/gim

const TABLE_CONN = /^(\d+)\/(\d+)$/
const TABLE_MON_DAY =
  /^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)(\d{1,2})$/i
const TABLE_TZ = /^[A-Za-z]+\/[A-Za-z_/+]+$/
const TABLE_OUTPUTS = /^(?:m3u8?|ts|rtmp)(?:,(?:m3u8?|ts|rtmp))+$/i
const TABLE_STATUS = /^(?:Active|Expired|Banned|Disabled|Trial)$/i

/**
 * Stalker / Ministra MAC lines.
 * Accepts `mac=…`, `MAC: …`, `MAC Addr: …`, `Mac Address: …`.
 */
const STALKER_MAC =
  /mac(?:\s*addr(?:ess)?)?\s*[=:]\s*((?:[0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2})/gi

const STALKER_PORTAL =
  /(https?:\/\/[^<\s"']+?(?:\/c\/?|\/portal\.php|\/stalker_portal[^<\s"']*))/gi

const BLOCK_TAGS = /<(?:p|br|div|li|h\d)[^>]*>/gi
const ANY_TAG = /<[^>]+>/g
const MARKDOWN_LINK = /\[([^\]]*)]\((https?:\/\/[^)\s]+)\)/gi
const ANGLE_URL = /<(https?:\/\/[^>\s]+)>/gi
const PATH_SUFFIX =
  /\/(?:get|live|portal|c|index|playlist|player_api|xmltv|index\.php|portal\.php)\.php$/i

const MAXCONN_RE = /(?:👥\s*)?MAXCONN\s*[:=]\s*(\d+)/i
const OUTPUTS_RE =
  /(?:📺\s*)?Allowed\s*Outputs?\s*[:=]\s*([^\n\r]+)/i
const EXPIRED_RE = /(?:📆\s*)?Expired\s*on\s*[:=]\s*([^\n\r]+)/i
const REGION_HINT_RE =
  /(?:mainly|mostly|focus|region)\s*[:\-]?\s*([^\n\r]{2,80})/i

const JUNK_CODE = [
  'Array.isArray',
  'prototype.',
  'function(',
  'var ',
  'const ',
  'let ',
  'return!',
  'void ',
  '.message}',
  'window.',
  'document.',
]

/** Platform of the portal hit (not the get.php `type=` query). */
export type PortalPlatform = 'xtream' | 'm3u' | 'stalker'

export type ExtractedPortal = CatalogPortal & {
  platform: PortalPlatform
  /** get.php ?type= — e.g. m3u_plus (empty for plain xtream). */
  type: string
  /** get.php ?output= — e.g. m3u8 / ts (empty for plain xtream). */
  output: string
}

export type FileMeta = {
  platformHint: PortalPlatform | null
  region: RegionGuess
}

type CardMeta = {
  maxConnections: string | null
  expiry: string | null
  allowedOutputs: string | null
}

function cleanHtmlish(raw: string): string {
  const s = raw.replaceAll('&amp;', '&').replaceAll('&quot;', '"')
  return s
    .replace(MARKDOWN_LINK, '$2')
    .replace(ANGLE_URL, '$1')
    .replace(BLOCK_TAGS, '\n')
    .replace(ANY_TAG, '')
}

function isJunkCode(text: string): boolean {
  let hits = 0
  for (const m of JUNK_CODE) {
    if (text.includes(m)) {
      hits++
      if (hits >= 2) return true
    }
  }
  return false
}

function scrubQsValue(raw: string): string {
  let v = raw.trim()
  try {
    v = decodeURIComponent(v.replace(/\+/g, ' '))
  } catch {
    // keep raw
  }
  return v.replace(/[\]>"')]+$/g, '').trim()
}

function parseQuery(qs: string): Record<string, string> {
  const out: Record<string, string> = {}
  for (const part of qs.split('&')) {
    const eq = part.indexOf('=')
    if (eq <= 0) continue
    const k = decodeURIComponent(part.slice(0, eq)).trim().toLowerCase()
    const v = scrubQsValue(part.slice(eq + 1))
    if (k) out[k] = v
  }
  return out
}

function cleanPortalUrl(raw: string): string {
  let clean = raw.replace(/\s+/g, '')
  const q = clean.indexOf('?')
  if (q >= 0) clean = clean.slice(0, q)
  clean = clean.trim().replace(/[\]>"')]+$/g, '')
  const at = clean.lastIndexOf('@')
  if (at >= 0) clean = `http://${clean.slice(at + 1)}`
  clean = clean.replace(PATH_SUFFIX, '')
  while (clean.endsWith('/')) clean = clean.slice(0, -1)
  if (!clean.startsWith('http')) clean = `http://${clean}`
  return clean
}

function cleanCred(raw: string): string {
  let s = scrubQsValue(raw)
  while (s.startsWith('=')) s = s.slice(1)
  return (s.split(/[ \n&?]/)[0] ?? '').trim()
}

function isMacBridgePass(pass: string): boolean {
  const lp = pass.toLowerCase()
  return lp.includes('live.php') || lp.includes('mac=') || lp.startsWith('live.')
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

/** Prefer full Allowed Outputs (m3u8,ts,rtmp); else get.php output=. Never drop outputs. */
function resolveOutput(queryOutput: string, allowed: string | null): string {
  const q = queryOutput.trim()
  const a = (allowed ?? '').trim()
  if (a && (!q || a.length >= q.length)) return a
  return q || a
}

function parseFileMeta(cleaned: string): FileMeta {
  const head = cleaned.slice(0, 1200)
  const hasM3u = /\bM3U\b/i.test(head)
  const hasXtream = /\bXTREAM\b/i.test(head)
  let platformHint: PortalPlatform | null = null
  if (hasM3u && !hasXtream) platformHint = 'm3u'
  else if (hasXtream && !hasM3u) platformHint = 'xtream'
  // "M3U/XTREAM" → leave null; get.php `type=` decides

  const regionLine = REGION_HINT_RE.exec(head)?.[1]?.trim() ?? ''
  const fallbackRegion =
    !regionLine && /\bUK\b|\bUS\b|\bUSA\b|\bEU\b|\bDE\b|\bFR\b/i.test(head)
      ? head.split('\n').slice(0, 8).join(' ')
      : regionLine
  return {
    platformHint,
    region: classifyRegionFromNote(fallbackRegion),
  }
}

/** Public for LLM extract path. */
export function parseNoteFileMeta(rawText: string): FileMeta {
  return parseFileMeta(cleanHtmlish(rawText))
}

function parseCardMeta(block: string): CardMeta {
  const max = MAXCONN_RE.exec(block)?.[1]?.trim() ?? null
  const allowed = OUTPUTS_RE.exec(block)?.[1]?.trim() ?? null
  const expiredRaw = EXPIRED_RE.exec(block)?.[1]?.trim() ?? null
  const expiry = expiredRaw ? formatPortalExpiry(expiredRaw) : null
  return {
    maxConnections: max,
    expiry,
    allowedOutputs: allowed,
  }
}

/**
 * XML2-style rows:
 * `host:port  user:pass  0/500  Sep23  2026  Active  host:port  m3u8,ts  Europe/Rome`
 */
function parseTableTail(
  tail: string,
  host: string,
  port: string,
): Partial<ExtractedPortal> {
  const tokens = tail.trim().split(/\s+/).filter(Boolean)
  let maxConnections: string | null = null
  let expiry: string | null = null
  let allowedOutputs: string | null = null
  let timezone: string | null = null
  const hostPort = `${host}:${port}`.toLowerCase()
  const hostLower = host.toLowerCase()

  for (let i = 0; i < tokens.length; i++) {
    const t = tokens[i]!
    const conn = TABLE_CONN.exec(t)
    if (conn) {
      maxConnections = conn[2] ?? null
      continue
    }
    if (/^no_expiry$/i.test(t)) {
      expiry = null
      continue
    }
    const md = TABLE_MON_DAY.exec(t)
    if (md && i + 1 < tokens.length && /^\d{4}$/.test(tokens[i + 1]!)) {
      const mon =
        md[1]!.charAt(0).toUpperCase() + md[1]!.slice(1, 3).toLowerCase()
      const day = String(Number(md[2]))
      const year = tokens[i + 1]!
      expiry = formatPortalExpiry(`${day} ${mon} ${year}`)
      i++
      continue
    }
    if (TABLE_STATUS.test(t)) continue
    const tl = t.toLowerCase()
    if (tl === hostPort || tl === hostLower) continue
    if (TABLE_OUTPUTS.test(t) || /(?:^|,)(?:m3u8?|ts|rtmp)(?:,|$)/i.test(t)) {
      allowedOutputs = t
      continue
    }
    if (TABLE_TZ.test(t)) {
      timezone = t
      continue
    }
  }

  const region = timezone ? classifyRegion(timezone, []) : undefined
  return {
    maxConnections,
    expiry,
    allowedOutputs,
    timezone,
    regionPrimary: region?.primary,
    regionTags: region?.tags,
    regionConfidence: region?.confidence,
  }
}

function cardBlockForUser(cleaned: string, username: string): string {
  if (!username) return ''
  const re = new RegExp(
    `(?:👤|👑)\\s*(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\\s*[:=]\\s*${escapeRegExp(username)}\\b[\\s\\S]{0,700}`,
    'i',
  )
  return re.exec(cleaned)?.[0] ?? ''
}

function mergePortalMeta(
  base: ExtractedPortal,
  patch: Partial<ExtractedPortal>,
): ExtractedPortal {
  return {
    ...base,
    type: base.type || patch.type || '',
    output: base.output || patch.output || '',
    expiry: base.expiry ?? patch.expiry ?? null,
    maxConnections: base.maxConnections ?? patch.maxConnections ?? null,
    timezone: base.timezone ?? patch.timezone ?? null,
    allowedOutputs: base.allowedOutputs ?? patch.allowedOutputs ?? null,
    regionPrimary: base.regionPrimary ?? patch.regionPrimary,
    regionTags: base.regionTags?.length ? base.regionTags : patch.regionTags,
    regionConfidence:
      base.regionConfidence && base.regionConfidence > 0
        ? base.regionConfidence
        : patch.regionConfidence,
  }
}

function put(
  acc: Map<string, ExtractedPortal>,
  portal: ExtractedPortal,
) {
  const key = `${portal.platform}|${portalKey(portal)}|${portal.type}|${portal.output}`
  const prev = acc.get(key)
  if (!prev) acc.set(key, portal)
  else acc.set(key, mergePortalMeta(prev, portal))
}

function finalizeXtreamOrM3u(
  acc: Map<string, ExtractedPortal>,
  rawUrl: string,
  rawUser: string,
  rawPass: string,
  source: string,
  queryType: string,
  queryOutput: string,
  meta?: Partial<ExtractedPortal>,
  fileMeta?: FileMeta,
) {
  const url = cleanPortalUrl(rawUrl)
  const username = cleanCred(rawUser)
  const password = cleanCred(rawPass)
  if (!url || username.length < 1 || password.length < 1) return
  if (username.includes('http') || password.includes('http')) return

  const region = fileMeta?.region
  const allowed = meta?.allowedOutputs ?? null
  const output = resolveOutput(queryOutput, allowed)
  const type = queryType || meta?.type || ''

  const shared = {
    expiry: meta?.expiry ?? null,
    maxConnections: meta?.maxConnections ?? null,
    timezone: meta?.timezone ?? null,
    allowedOutputs: allowed,
    regionPrimary: meta?.regionPrimary ?? region?.primary,
    regionTags: meta?.regionTags?.length ? meta.regionTags : region?.tags,
    regionConfidence:
      meta?.regionConfidence && meta.regionConfidence > 0
        ? meta.regionConfidence
        : region?.confidence,
  }

  // MAC-bridge fake M3U → stalker, keep it.
  if (
    isMacBridgePass(password) ||
    (username.toLowerCase() === 'play' &&
      (password.toLowerCase().includes('live') ||
        password.toLowerCase().includes('mac')))
  ) {
    put(acc, {
      url,
      username,
      password,
      source,
      platform: 'stalker',
      type,
      output,
      ...shared,
    })
    return
  }

  const lu = url.toLowerCase()
  if (lu.endsWith('/c') || lu.includes('/c/')) {
    put(acc, {
      url,
      username,
      password,
      source,
      platform: 'stalker',
      type,
      output,
      ...shared,
    })
    return
  }

  const hasM3uType =
    type.toLowerCase().includes('m3u') ||
    output.toLowerCase().includes('m3u') ||
    output.toLowerCase() === 'ts' ||
    rawUrl.toLowerCase().includes('/get.php') ||
    fileMeta?.platformHint === 'm3u'

  let platform: PortalPlatform =
    hasM3uType && (type || output || fileMeta?.platformHint === 'm3u')
      ? 'm3u'
      : 'xtream'
  if (fileMeta?.platformHint === 'xtream' && !type && !output) {
    platform = 'xtream'
  }

  put(acc, {
    url,
    username,
    password,
    source,
    platform,
    type,
    output,
    ...shared,
  })
}

export type LoosePortalHit = {
  url: string
  username: string
  password: string
  platform?: PortalPlatform
  type?: string
  output?: string
  expiry?: string | null
  maxConnections?: string | null
  timezone?: string | null
  allowedOutputs?: string | null
  regionPrimary?: string
  regionTags?: string[]
  regionConfidence?: number
}

/** Normalize a loose hit (LLM or other) into the extract map. */
export function ingestPortalHit(
  acc: Map<string, ExtractedPortal>,
  hit: LoosePortalHit,
  source: string,
  fileMeta?: FileMeta,
) {
  const type = hit.type ?? ''
  const output = hit.output ?? ''
  const allowed = hit.allowedOutputs ?? (output || null)
  const meta: Partial<ExtractedPortal> = {
    expiry: hit.expiry ?? null,
    maxConnections: hit.maxConnections ?? null,
    timezone: hit.timezone ?? null,
    allowedOutputs: allowed,
    regionPrimary: hit.regionPrimary,
    regionTags: hit.regionTags,
    regionConfidence: hit.regionConfidence,
    type,
  }

  // LLM / explicit stalker (incl. MAC-only with empty password).
  if (hit.platform === 'stalker') {
    const url = cleanPortalUrl(hit.url)
    if (!url) return
    const username = cleanCred(hit.username)
    const password = cleanCred(hit.password)
    put(acc, {
      url,
      username,
      password,
      source,
      platform: 'stalker',
      type,
      output: resolveOutput(output, allowed),
      expiry: meta.expiry ?? null,
      maxConnections: meta.maxConnections ?? null,
      timezone: meta.timezone ?? null,
      allowedOutputs: allowed,
      regionPrimary: meta.regionPrimary ?? fileMeta?.region.primary,
      regionTags: meta.regionTags?.length
        ? meta.regionTags
        : fileMeta?.region.tags,
      regionConfidence:
        meta.regionConfidence && meta.regionConfidence > 0
          ? meta.regionConfidence
          : fileMeta?.region.confidence,
    })
    return
  }

  finalizeXtreamOrM3u(
    acc,
    hit.url,
    hit.username,
    hit.password,
    source,
    type,
    output,
    meta,
    fileMeta,
  )
}

/** Pair each `👤 USERNAME` / `🔑 PASSWORD` block with the nearest prior `🔗` URL. */
function extractEmojiLinkCards(
  cleaned: string,
  acc: Map<string, ExtractedPortal>,
  source: string,
  fileMeta: FileMeta,
) {
  type Mark =
    | { kind: 'url'; index: number; url: string }
    | { kind: 'cred'; index: number; end: number; user: string; pass: string }

  const marks: Mark[] = []
  for (const m of cleaned.matchAll(EMOJI_LINK)) {
    if (m.index == null || !m[1]) continue
    marks.push({ kind: 'url', index: m.index, url: m[1] })
  }
  for (const m of cleaned.matchAll(EMOJI_CREDS)) {
    if (m.index == null || !m[1] || !m[2]) continue
    marks.push({
      kind: 'cred',
      index: m.index,
      end: m.index + m[0].length,
      user: m[1],
      pass: m[2],
    })
  }
  marks.sort((a, b) => a.index - b.index)

  let lastUrl: string | null = null
  for (const mark of marks) {
    if (mark.kind === 'url') {
      lastUrl = mark.url
      continue
    }
    if (!lastUrl) continue
    const q = parseQuery(
      lastUrl.includes('?') ? (lastUrl.split('?')[1] ?? '') : '',
    )
    const block = cleaned.slice(Math.max(0, mark.index - 80), mark.end + 500)
    const card = parseCardMeta(block)
    finalizeXtreamOrM3u(
      acc,
      lastUrl,
      mark.user,
      mark.pass,
      source,
      q.type ?? '',
      q.output ?? '',
      card,
      fileMeta,
    )
  }
}

/** Fill card meta for portals found via get.php / labels that skipped the emoji path. */
function enrichPortalsFromCards(
  cleaned: string,
  acc: Map<string, ExtractedPortal>,
  fileMeta: FileMeta,
) {
  for (const [key, p] of [...acc.entries()]) {
    if (p.platform === 'stalker' || !p.username) continue
    const block = cardBlockForUser(cleaned, p.username)
    const card = block
      ? parseCardMeta(block)
      : { maxConnections: null, expiry: null, allowedOutputs: null }
    const next = mergePortalMeta(p, {
      ...p,
      expiry: p.expiry ?? card.expiry,
      maxConnections: p.maxConnections ?? card.maxConnections,
      allowedOutputs: p.allowedOutputs ?? card.allowedOutputs,
      output: resolveOutput(
        p.output,
        card.allowedOutputs ?? p.allowedOutputs ?? null,
      ),
      regionPrimary: p.regionPrimary ?? fileMeta.region.primary,
      regionTags: p.regionTags?.length ? p.regionTags : fileMeta.region.tags,
      regionConfidence:
        p.regionConfidence && p.regionConfidence > 0
          ? p.regionConfidence
          : fileMeta.region.confidence,
      platform:
        !p.type && !p.output && fileMeta.platformHint
          ? fileMeta.platformHint
          : p.platform,
    })
    acc.delete(key)
    put(acc, next)
  }
}

/** Extract portals; type/output = get.php query params; platform = xtream|m3u|stalker. */
export function extractPortals(
  rawText: string,
  source = 'catalog',
): ExtractedPortal[] {
  if (rawText.length < 15 || isJunkCode(rawText)) return []
  const cleaned = cleanHtmlish(rawText)
  const fileMeta = parseFileMeta(cleaned)
  const acc = new Map<string, ExtractedPortal>()

  for (const m of cleaned.matchAll(URL_PARAM)) {
    const base = m[1] ?? ''
    const qs = m[2] ?? ''
    const q = parseQuery(qs)
    const user = q.username || q.user || ''
    const pass = q.password || q.pass || ''
    if (!user || !pass) continue
    finalizeXtreamOrM3u(
      acc,
      base,
      user,
      pass,
      source,
      q.type ?? '',
      q.output ?? '',
      undefined,
      fileMeta,
    )
  }

  for (const m of cleaned.matchAll(LABEL_HOST_FIRST)) {
    finalizeXtreamOrM3u(
      acc,
      m[1] ?? '',
      m[2] ?? '',
      m[3] ?? '',
      source,
      '',
      '',
      undefined,
      fileMeta,
    )
  }
  for (const m of cleaned.matchAll(LABEL_USER_FIRST)) {
    finalizeXtreamOrM3u(
      acc,
      m[3] ?? '',
      m[1] ?? '',
      m[2] ?? '',
      source,
      '',
      '',
      undefined,
      fileMeta,
    )
  }
  for (const m of cleaned.matchAll(TABLE_LINE)) {
    const host = m[1] ?? ''
    const port = m[2] ?? ''
    if (!host || !port) continue
    const tailMeta = parseTableTail(m[5] ?? '', host, port)
    finalizeXtreamOrM3u(
      acc,
      `${host}:${port}`,
      m[3] ?? '',
      m[4] ?? '',
      source,
      '',
      '',
      tailMeta,
      fileMeta,
    )
  }

  extractEmojiLinkCards(cleaned, acc, source, fileMeta)
  enrichPortalsFromCards(cleaned, acc, fileMeta)

  // Stalker portals + MACs (even without user/pass pair).
  // One row per unique portal×MAC (same host, many cards → many MACs).
  const macs = [
    ...new Set(
      [...cleaned.matchAll(STALKER_MAC)].map((m) =>
        (m[1] ?? '').toUpperCase().replace(/-/g, ':'),
      ).filter(Boolean),
    ),
  ]
  const portalUrls = [
    ...new Set(
      [...cleaned.matchAll(STALKER_PORTAL)]
        .map((m) => cleanPortalUrl(m[1] ?? ''))
        .filter(Boolean),
    ),
  ]
  for (const portalUrl of portalUrls) {
    if (macs.length === 0) {
      put(acc, {
        url: portalUrl,
        username: '',
        password: '',
        source,
        platform: 'stalker',
        type: '',
        output: '',
      })
      continue
    }
    for (const mac of macs) {
      put(acc, {
        url: portalUrl,
        username: mac,
        password: '',
        source,
        platform: 'stalker',
        type: '',
        output: '',
      })
    }
  }

  return [...acc.values()]
}
