import type { CatalogPortal } from './types'
import { portalKey } from './types'

/** Xtream-style host + user + pass in query (optional type/output). */
const URL_PARAM =
  /(https?:\/\/[^?\s"'<]+)\?([^\s"'<]*)/gi

const LABEL_HOST_FIRST =
  /(?:(?:🔗|🌍|🌐)\s*)?(?:Portal|Host(?:\s*URL)?|H[ᴏo]s[ᴛt]|Panel|Server|S[ᴇe]rv[ᴇe]r|ꜱᴇʀᴠᴇʀ|URL)\W+(https?:\/\/[^<\s"']+).{1,500}?(?:(?:👤|👑)\s*)?(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\W+([^\s|<"'\n]+).{1,200}?(?:(?:🔑|🔐)\s*)?(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\W+([^\s|<"'\n]+)/gis

const LABEL_USER_FIRST =
  /(?:(?:👤|👑)\s*)?(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\W+([^\s|<"'\n]+).{1,400}?(?:(?:🔑|🔐)\s*)?(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\W+([^\s|<"'\n]+).{1,400}?(?:(?:🔗|🌍|🌐)\s*)?(?:Portal|Host(?:\s*URL)?|H[ᴏo]s[ᴛt]|Panel|Server|S[ᴇe]rv[ᴇe]r|ꜱᴇʀᴠᴇʀ|URL)\W+(https?:\/\/[^<\s"']+)/gis

const TABLE_LINE =
  /^[^\S\n]*((?:(?:\d{1,3}\.){3}\d{1,3}|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,})):([1-9]\d{1,4})[^\S\n]+([A-Za-z0-9._@+-]{3,64}):(\S{3,64})/gim

/** Stalker / Ministra MAC lines. */
const STALKER_MAC =
  /(?:mac|MAC)\s*[=:]\s*((?:[0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2})/g

const STALKER_PORTAL =
  /(https?:\/\/[^<\s"']+?(?:\/c\/?|\/portal\.php|\/stalker_portal[^<\s"']*))/gi

const BLOCK_TAGS = /<(?:p|br|div|li|h\d)[^>]*>/gi
const ANY_TAG = /<[^>]+>/g
const PATH_SUFFIX =
  /\/(?:get|live|portal|c|index|playlist|player_api|xmltv|index\.php|portal\.php)\.php$/i

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

function cleanHtmlish(raw: string): string {
  const s = raw.replaceAll('&amp;', '&').replaceAll('&quot;', '"')
  return s.replace(BLOCK_TAGS, '\n').replace(ANY_TAG, '')
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

function parseQuery(qs: string): Record<string, string> {
  const out: Record<string, string> = {}
  for (const part of qs.split('&')) {
    const eq = part.indexOf('=')
    if (eq <= 0) continue
    const k = decodeURIComponent(part.slice(0, eq)).trim().toLowerCase()
    let v = part.slice(eq + 1)
    try {
      v = decodeURIComponent(v.replace(/\+/g, ' '))
    } catch {
      // keep raw
    }
    if (k) out[k] = v.trim()
  }
  return out
}

function cleanPortalUrl(raw: string): string {
  let clean = raw.replace(/\s+/g, '')
  const q = clean.indexOf('?')
  if (q >= 0) clean = clean.slice(0, q)
  clean = clean.trim()
  const at = clean.lastIndexOf('@')
  if (at >= 0) clean = `http://${clean.slice(at + 1)}`
  clean = clean.replace(PATH_SUFFIX, '')
  while (clean.endsWith('/')) clean = clean.slice(0, -1)
  if (!clean.startsWith('http')) clean = `http://${clean}`
  return clean
}

function cleanCred(raw: string): string {
  let s = raw
  while (s.startsWith('=')) s = s.slice(1)
  return (s.split(/[ \n&?]/)[0] ?? '').trim()
}

function isMacBridgePass(pass: string): boolean {
  const lp = pass.toLowerCase()
  return lp.includes('live.php') || lp.includes('mac=') || lp.startsWith('live.')
}

function put(
  acc: Map<string, ExtractedPortal>,
  portal: ExtractedPortal,
) {
  const key = `${portal.platform}|${portalKey(portal)}|${portal.type}|${portal.output}`
  if (!acc.has(key)) acc.set(key, portal)
}

function finalizeXtreamOrM3u(
  acc: Map<string, ExtractedPortal>,
  rawUrl: string,
  rawUser: string,
  rawPass: string,
  source: string,
  queryType: string,
  queryOutput: string,
) {
  const url = cleanPortalUrl(rawUrl)
  const username = cleanCred(rawUser)
  const password = cleanCred(rawPass)
  if (!url || username.length < 3 || password.length < 3) return
  if (username.includes('http') || password.includes('http')) return

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
      type: queryType,
      output: queryOutput,
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
      type: queryType,
      output: queryOutput,
    })
    return
  }

  const hasM3uType =
    queryType.toLowerCase().includes('m3u') ||
    queryOutput.toLowerCase().includes('m3u') ||
    queryOutput.toLowerCase() === 'ts' ||
    rawUrl.toLowerCase().includes('/get.php')

  put(acc, {
    url,
    username,
    password,
    source,
    platform: hasM3uType && (queryType || queryOutput) ? 'm3u' : 'xtream',
    type: queryType,
    output: queryOutput,
  })
}

/** Extract portals; type/output = get.php query params; platform = xtream|m3u|stalker. */
export function extractPortals(
  rawText: string,
  source = 'catalog',
): ExtractedPortal[] {
  if (rawText.length < 15 || isJunkCode(rawText)) return []
  const cleaned = cleanHtmlish(rawText)
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
    )
  }
  for (const m of cleaned.matchAll(TABLE_LINE)) {
    const host = m[1] ?? ''
    const port = m[2] ?? ''
    if (!host || !port) continue
    finalizeXtreamOrM3u(
      acc,
      `${host}:${port}`,
      m[3] ?? '',
      m[4] ?? '',
      source,
      '',
      '',
    )
  }

  // Stalker portals + MACs (even without user/pass pair).
  const macs: string[] = []
  for (const m of cleaned.matchAll(STALKER_MAC)) {
    const mac = (m[1] ?? '').toUpperCase().replace(/-/g, ':')
    if (mac) macs.push(mac)
  }
  for (const m of cleaned.matchAll(STALKER_PORTAL)) {
    const portalUrl = cleanPortalUrl(m[1] ?? '')
    if (!portalUrl) continue
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
    } else {
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
  }

  return [...acc.values()]
}
