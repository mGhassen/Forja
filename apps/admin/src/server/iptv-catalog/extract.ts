import type { CatalogPortal } from './types'
import { portalKey } from './types'

const URL_PARAM =
  /(https?:\/\/[^?\s"'<]+)\?(?:[^\s"'<]*?&)?(?:username|user)=([^&\s"'<]+)\s*&(?:password|pass)=([^&\s"'<]+)/gi

const LABEL_HOST_FIRST =
  /(?:(?:🔗|🌍|🌐)\s*)?(?:Portal|Host(?:\s*URL)?|H[ᴏo]s[ᴛt]|Panel|Server|S[ᴇe]rv[ᴇe]r|ꜱᴇʀᴠᴇʀ|URL)\W+(https?:\/\/[^<\s"']+).{1,500}?(?:(?:👤|👑)\s*)?(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\W+([^\s|<"'\n]+).{1,200}?(?:(?:🔑|🔐)\s*)?(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\W+([^\s|<"'\n]+)/gis

const LABEL_USER_FIRST =
  /(?:(?:👤|👑)\s*)?(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\W+([^\s|<"'\n]+).{1,400}?(?:(?:🔑|🔐)\s*)?(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\W+([^\s|<"'\n]+).{1,400}?(?:(?:🔗|🌍|🌐)\s*)?(?:Portal|Host(?:\s*URL)?|H[ᴏo]s[ᴛt]|Panel|Server|S[ᴇe]rv[ᴇe]r|ꜱᴇʀᴠᴇʀ|URL)\W+(https?:\/\/[^<\s"']+)/gis

const TABLE_LINE =
  /^[^\S\n]*((?:(?:\d{1,3}\.){3}\d{1,3}|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,})):([1-9]\d{1,4})[^\S\n]+([A-Za-z0-9._@+-]{3,64}):(\S{3,64})/gim

const BLOCK_TAGS = /<(?:p|br|div|li|h\d)[^>]*>/gi
const ANY_TAG = /<[^>]+>/g
const PATH_SUFFIX =
  /\/(?:get|live|portal|c|index|playlist|player_api|xmltv|index\.php|portal\.php)\.php$/i

const JUNK_TOKENS = [
  'type=m3u',
  'output=ts',
  'password=',
  'username=',
  'password',
  'username',
]

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

function isStalkerJunk(url: string, user: string, pass: string): boolean {
  const lu = url.toLowerCase()
  const lp = pass.toLowerCase()
  const un = user.toLowerCase()
  if (lu.endsWith('/c') || lu.includes('/c/')) return true
  if (lp.includes('live.php') || lp.includes('mac=') || lp.startsWith('live.'))
    return true
  if (un === 'play' && (lp.includes('live') || lp.includes('mac'))) return true
  return false
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

function finalize(
  acc: Map<string, CatalogPortal>,
  rawUrl: string,
  rawUser: string,
  rawPass: string,
  source: string,
) {
  const url = cleanPortalUrl(rawUrl)
  const username = cleanCred(rawUser)
  const password = cleanCred(rawPass)
  if (!url || username.length < 3 || password.length < 3) return
  if (username.includes('http') || password.includes('http')) return
  if (isStalkerJunk(url, username, password)) return
  const lu = username.toLowerCase()
  const lp = password.toLowerCase()
  for (const j of JUNK_TOKENS) {
    if (lu.includes(j) || lp.includes(j)) return
  }
  const portal: CatalogPortal = { url, username, password, source }
  const key = portalKey(portal)
  if (!acc.has(key)) acc.set(key, portal)
}

/** Extract unique Xtream portals from free-form text (port of crates/iptv portal_extract). */
export function extractPortals(rawText: string, source = 'catalog'): CatalogPortal[] {
  if (rawText.length < 15 || isJunkCode(rawText)) return []
  const cleaned = cleanHtmlish(rawText)
  const acc = new Map<string, CatalogPortal>()

  for (const m of cleaned.matchAll(URL_PARAM)) {
    finalize(acc, m[1] ?? '', m[2] ?? '', m[3] ?? '', source)
  }
  for (const m of cleaned.matchAll(LABEL_HOST_FIRST)) {
    finalize(acc, m[1] ?? '', m[2] ?? '', m[3] ?? '', source)
  }
  for (const m of cleaned.matchAll(LABEL_USER_FIRST)) {
    finalize(acc, m[3] ?? '', m[1] ?? '', m[2] ?? '', source)
  }
  for (const m of cleaned.matchAll(TABLE_LINE)) {
    const host = m[1] ?? ''
    const port = m[2] ?? ''
    if (!host || !port) continue
    finalize(acc, `${host}:${port}`, m[3] ?? '', m[4] ?? '', source)
  }

  return [...acc.values()]
}
