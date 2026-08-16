import { formatPortalExpiry } from '@/lib/iptv-portal-expiry'
import {
  classifyRegion,
  classifyRegionFromNote,
  regionFromChannelGeoBracket,
} from './region'
import type { CatalogPortal, RegionGuess } from './types'
import { portalKey } from './types'

/** Xtream-style host + user + pass in query (optional type/output). */
const URL_PARAM = /(https?:\/\/[^?\s"'<]+)\?([^\s"'<)\]]*)/gi

const LABEL_HOST_FIRST =
  /(?:(?:🔗|🌍|🌐|📡)\s*)?(?:Portal|Host(?:\s*URL)?|H[ᴏo]s[ᴛt]|Panel|Server|Servidor|S[ᴇe]rv[ᴇe]r|ꜱᴇʀᴠᴇʀ|URL)\W+(https?:\/\/[^<\s"']+).{1,160}?(?:(?:👤|👑)\s*)?(?<![?&\w])(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\W+([^\s|<"'\n&]+).{1,80}?(?:(?:🔑|🔐|🔒)\s*)?(?<![?&\w])(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\W+([^\s|<"'\n&]+)/gis

const LABEL_USER_FIRST =
  /(?:(?:👤|👑)\s*)?(?<![?&\w])(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\W+([^\s|<"'\n&]+).{1,80}?(?:(?:🔑|🔐|🔒)\s*)?(?<![?&\w])(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\W+([^\s|<"'\n&]+).{1,120}?(?:(?:🔗|🌍|🌐|📡)\s*)?(?:Portal|Host(?:\s*URL)?|H[ᴏo]s[ᴛt]|Panel|Server|Servidor|S[ᴇe]rv[ᴇe]r|ꜱᴇʀᴠᴇʀ|URL)\W+(https?:\/\/[^<\s"']+)/gis

/**
 * IPTV_ZONENEW status cards: `🔗 http://…` then later `👤 USERNAME :` / `🔑 PASSWORD :`.
 * Also `🌍 SERVIDOR: http://…` (label between emoji and URL).
 */
const EMOJI_LINK =
  /(?:🔗|🌍|🌐|📡)\s*(?:(?:SERVIDOR|Servidor|Host|Server|Portal|URL)\s*[:=]\s*)?(https?:\/\/[^\s<"']+)/gi

/** Bare get.php lines (sometimes missing 🔗 after Telegram glue). */
const GET_PHP_URL =
  /(https?:\/\/[^?\s<"']+\?[^?\s<"']*?[?&](?:username|user)=[^&\s<"']+[^?\s<"']*)/gi

/** Emoji-required so we never match `username=` inside get.php query strings. */
const EMOJI_CREDS =
  /(?:👤|👑)\s*(?:Username|Usu[áa]rio|Usuario|Us[ᴇe]rname|Us[ᴜu][ᴀa]r[ɪi][ᴏo]|User|Us[ᴇe]r|ᴜꜱᴇʀ)\s*[:=]\s*([^\s|<"'\n]+)[\s\S]{0,240}?(?:🔑|🔐|🔒)\s*(?:Password|Senha|Contrase[ñn]a|P[ᴀa]ssword|S[ᴇe]nh[ᴀa]|Pass|P[ᴀa]ss|ᴩᴀꜱꜱ|ᴘᴀꜱꜱ)\s*[:=]\s*([^\s|<"'\n]+)/gi

const TABLE_LINE =
  /^[^\S\n]*(?:https?:\/\/)?((?:(?:\d{1,3}\.){3}\d{1,3}|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,})):([1-9]\d{1,4})[^\S\n]+([A-Za-z0-9._@+-]{3,64})\s*:\s*(\S{3,64})([^\n]*)/gim

const TABLE_CONN = /^(\d+)\/(\d+)$/
const TABLE_CONN_SPACED = /\b(\d+)\s*\/\s*(\d+)\b/
const TABLE_MON_DAY =
  /^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)(\d{1,2})$/i
const TABLE_TZ = /^(?:[A-Za-z]+\/[A-Za-z_/+]+|UTC|GMT)$/i
const TABLE_OUTPUTS = /^(?:m3u8?|ts|rtmp)(?:,(?:m3u8?|ts|rtmp))+$/i
const TABLE_STATUS =
  /^(?:Active|Expired|Banned|Disabled|Trial|Activa|Activo|Inactiva|Expirad[ao]|Banead[ao]|Prueba)$/i
/** Spanish panel dumps: `25 jul de 2026` / `26 ago de 2026`. */
const TABLE_ES_DATE =
  /\b(\d{1,2})\s+(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)[a-záéíóú]*\s+(?:de\s+)?(\d{4})\b/gi
const TABLE_ES_MON: Record<string, string> = {
  ene: 'Jan',
  feb: 'Feb',
  mar: 'Mar',
  abr: 'Apr',
  may: 'May',
  jun: 'Jun',
  jul: 'Jul',
  ago: 'Aug',
  sep: 'Sep',
  oct: 'Oct',
  nov: 'Nov',
  dic: 'Dec',
}

/** App sentinel — same as `IptvPortalPlatform.m3uUsernameSentinel`. */
const M3U_USER_SENTINEL = '__m3u__'

/**
 * Direct playlist URLs (not get.php with user/pass — those stay URL_PARAM).
 * From notes or inside `#EXTM3U` (master / leaf playlists only — not every #EXTINF media).
 */
const PLAYLIST_FILE_URL =
  /https?:\/\/[^\s<"'\)\]>]+?\.(?:m3u8?|m3u)(?:\?[^\s<"'\)\]>]*)?/gi

const LABELED_PLAYLIST_URL =
  /(?:🔗\s*)?(?:Playlist|M3U8?|Liste)\s*[:=]\s*(https?:\/\/[^\s<"']+)/gi

/**
 * Stalker / Ministra MAC lines.
 * Accepts `mac=…`, `MAC: …`, `MAC Addr: …`, Hit Hunter smallcaps `ᴍᴀᴄ : …`.
 */
const STALKER_MAC =
  /(?:ᴍᴀᴄ|mac)(?:\s*addr(?:ess)?)?\s*[=:]\s*((?:[0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2})/gi

const STALKER_PORTAL =
  /(https?:\/\/[^<\s"']+?(?:\/c\/?(?=[?\s"'<]|$)|\/portal\.php(?:[^\s"'<]*)?|\/stalker_portal[^<\s"']*))/gi

/** Hit Hunter / Ishiro cards — smallcaps labels, MAC → EXP → PORTAL order. */
const HH_MAC_LINE =
  /(?:🔌\s*)?(?:ᴍᴀᴄ|MAC)\s*:\s*((?:[0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2})/i
const HH_PORTAL_LINE =
  /(?:🌐\s*)?(?:ᴘᴏʀᴛᴀʟ|PORTAL|Portal)\s*:\s*(https?:\/\/[^\s\n]+)/i
const HH_EXP_LINE =
  /(?:📅\s*)?(?:ᴇxᴘɪʀᴀᴛɪᴏɴ|EXPIRATION|Expiration|Exp(?:iry|ired)?(?:\s*date|\s*on)?)\s*:\s*([^\n]+)/i
const HH_TZ_LINE =
  /(?:🕰️\s*)?(?:ᴛɪᴍᴇᴢᴏɴᴇ|TIMEZONE|Timezone|Time\s*zone)\s*:\s*([^\n]+)/i
const HH_COUNTRY_LINE =
  /(?:🌍\s*)?(?:ᴄᴏᴜɴᴛʀʏ|COUNTRY|Country)\s*:\s*([^\n]+)/i

/**
 * KC night-owl / math-sans dumps (after foldMathSansSerif):
 * `PANEL ✦:➤ http://host/c/` + `MAC ✦: ➤ …` + `EXPIRES ✦: Month D, YYYY…`
 * Also tolerates truncated `ANEL` label.
 */
const KC_SEP = String.raw`[✦:=➤\s]+`
const KC_PANEL_LINE = new RegExp(
  String.raw`(?:PANEL|Portal|ANEL)\s*${KC_SEP}(https?:\/\/[^\s]+)`,
  'i',
)
const KC_MAC_LINE = new RegExp(
  String.raw`(?:❀+\s*)?(?:✦\s*)?MAC\s*${KC_SEP}((?:[0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2})`,
  'i',
)
const KC_EXPIRES_LINE = new RegExp(
  String.raw`(?:❀+\s*)?(?:✦\s*)?EXPIRES\s*${KC_SEP}([^\n]+)`,
  'i',
)

const MAC_ADDR_RE = /^(?:[0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}$/

const BLOCK_TAGS = /<(?:p|br|div|li|h\d|tr|td|th|table)[^>]*>/gi
const ANY_TAG = /<[^>]+>/g
const MARKDOWN_LINK = /\[([^\]]*)]\((https?:\/\/[^)\s]+)\)/gi
const ANGLE_URL = /<(https?:\/\/[^>\s]+)>/gi
const PATH_SUFFIX =
  /\/(?:get|live|portal|c|index|playlist|player_api|xmltv|index\.php|portal\.php)\.php$/i

const MAXCONN_RE =
  /(?:👥|⏳|🔝\s*)?(?:MAXCONN|Max\s*conn(?:ections?)?|CONEX(?:ÕES|OES|ões))\s*[:=]\s*(\d+)/i
const OUTPUTS_RE =
  /(?:📺|✅\s*)?Allowed\s*(?:Outputs?|formats?)\s*[:=]\s*(\[[^\]]*\]|[^\n\r⏱]+)/i
const EXPIRED_RE = /(?:📆\s*)?Expired\s*on\s*[:=]\s*([^\n\r]+)/i
/** Stalker / dump cards: `Exp date: …`, `Expire date: …`, PT `VALIDADE: …`. */
const EXP_DATE_RE =
  /(?:📆|📅\s*)?(?:Exp(?:ire[ds]?|iry)?(?:\s*date|\s*on)?|VALIDADE)\s*[:=]\s*([^\n\r]+)/i
const REGION_HINT_RE =
  /(?:mainly|mostly|focus|region)\s*[:\-]?\s*([^\n\r]{2,80})/i

/** Placeholder tokens that LABEL_* / headers falsely capture as creds. */
const JUNK_CRED =
  /^(?:name|user|username|password|pass|null|undefined|admin|test|xxx+|host|portal|server|url|expiry|biti[sş]|g[uü]n)$/i

/**
 * Dump sheets under a portal host:
 * `AliErdoTV jypCCT5A7hhp 226 Gün (Bitiş: 01/02/2027)`
 * `e7112e5513e7  7d02fab71b  Expires: 17/01/2027`
 * `G1  kmf2spi76q  06/07/2027  (AR,AT,CH, DE)`
 */
const DUMP_CRED_LINE =
  /^([A-Za-z0-9@._+-]{2,64})\s+(\S{3,64})(?:\s+\d+\s*G[uü]n)?(?:\s*\([^)]*Biti[sş]:\s*(\d{1,2}\/\d{1,2}\/\d{4})[^)]*\))?(?:\s+(?:Expires?\s*:?\s*)?(\d{1,2}\/\d{1,2}\/\d{4})\b.*)?$/i

const DUMP_HEADER =
  /^(?:usr|user|username|usu[áa]rio)\s+(?:pw|pass|password|senha)\b/i

const BARE_DUMP_HOST = /^(https?:\/\/[^\s/?#]+)\/?$/i

/** `Portal : http://…/c/` + `MAC Addr:` / `🔑 MAC:` + optional `Exp date:` card. */
const STALKER_CARD =
  /Portal\s*:\s*(https?:\/\/[^\s\n]+)[\t ]*\n[\t ]*(?:🔑\s*)?MAC(?:\s*Addr(?:ess)?)?\s*:\s*((?:[0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2})(?:[\t ]*\n[\s\S]{0,300}?Exp(?:ire[ds]?|iry)?(?:\s*date|\s*on)?\s*:\s*([^\n]+))?/gi

/**
 * MAC-checker / pipe dumps:
 * `[19:18:51] ✅ HIT: http://host:80 | 00:1A:79:… | Expires on February 16, 2027, 7:51 pm`
 * `http://host | 00:1A:79:… | Expires on November 22, 2027, 12:00 am`  (HIT: optional)
 * Atlas: unicode pipes, tabs, or spaces between URL and MAC. Portal may be bare host:port.
 */
const STALKER_HIT_LINE =
  /(?:(?:✅\s*)?HIT:\s*)?(https?:\/\/[^\s|│┃｜]+)(?:\s*[|│┃｜]\s*|\s+)((?:[0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2})(?:\s*[|│┃｜]?\s*Expires\s+on\s+([^\n|│┃｜]+))?/gi

const EXPIRES_ON = /Expires\s+on\s+(.+)/i

/**
 * MAC Raider / KC cards (math-bold folded to ASCII):
 * `Host  ➩ http://host/c/` + `ExpDate ➩ …` + `MAC  ➩ 00:1A:79:…`
 */
const RAIDER_SEP = String.raw`[➩:>\-✦═\s]+`
const RAIDER_HOST_LINE = new RegExp(
  String.raw`(?:Host|Portal|Panel)\s*${RAIDER_SEP}(https?:\/\/[^\s]+)`,
  'i',
)
const RAIDER_MAC_LINE = new RegExp(
  String.raw`MAC(?:\s*Addr(?:ess)?)?\s*${RAIDER_SEP}((?:[0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2})`,
  'i',
)
const RAIDER_EXP_LINE = new RegExp(
  String.raw`Exp(?:Date|iry|ires|ired)?(?:\s*date|\s*on)?\s*${RAIDER_SEP}([^\n]+)`,
  'i',
)

/**
 * Scan dumps: portal URL alone, then lines
 * `00:1A:79:… [Total: …] [March 28, 2027, 12:00 am]`
 */
const BARE_MAC_LINE =
  /^((?:[0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2})\b(.*)$/

const DATE_IN_BRACKETS =
  /\[((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s*\d{4}[^\]]*)\]/gi

const STALKER_PORTAL_ONLY_LINE =
  /^(https?:\/\/\S+?(?:\/c\/?|\/portal\.php(?:\S*)?|\/stalker_portal\S*))\/?\s*$/i

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
  return foldMathAlnum(
    stripIptvNoteNoise(s)
      .replace(MARKDOWN_LINK, '$2')
      .replace(ANGLE_URL, '$1')
      .replace(BLOCK_TAGS, '\n')
      .replace(ANY_TAG, ''),
  )
}

/**
 * Hit Hunter / Ishiro notes dump live category lists and Mag device blobs
 * that dwarf the MAC cards (often >64k). Drop them before extract.
 */
export function stripIptvNoteNoise(s: string): string {
  return s
    .replace(/📺[\s\S]*?╰─+╯/g, '\n')
    .replace(/╭[─✦\s]*📱[\s\S]*?╰[─✦]+/g, '\n')
    .replace(/╰─📺[^\n]*(?:\n[^\n]*)?/g, '\n')
    .replace(/^[^\n]*⚡[^\n]*⚡[^\n]*$/gm, '')
}

/**
 * Mathematical Alphanumeric Symbols (U+1D400–U+1D7FF) → ASCII.
 * Covers bold/italic/sans/mono Latin used in Telegram portal cards.
 */
function foldMathAlnum(s: string): string {
  return s.replace(/[\u{1D400}-\u{1D7FF}]/gu, (ch) => {
    const cp = ch.codePointAt(0)!
    for (const start of [0x1d7ce, 0x1d7d8, 0x1d7e2, 0x1d7ec, 0x1d7f6]) {
      if (cp >= start && cp <= start + 9) {
        return String.fromCharCode(48 + (cp - start))
      }
    }
    // Contiguous A–Z/a–z styles (skip script/fraktur/double-struck holes).
    for (const start of [
      0x1d400, 0x1d434, 0x1d468, 0x1d4d0, 0x1d56c, 0x1d5a0, 0x1d5d4, 0x1d608,
      0x1d63c, 0x1d670,
    ]) {
      const off = cp - start
      if (off >= 0 && off < 52) {
        return String.fromCharCode(off < 26 ? 65 + off : 97 + (off - 26))
      }
    }
    return ch
  })
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

function expiryFromMacRest(rest: string): string | null {
  const on = EXPIRES_ON.exec(rest)?.[1]?.trim()
  if (on) return formatPortalExpiry(on)
  DATE_IN_BRACKETS.lastIndex = 0
  let expiry: string | null = null
  for (const dm of rest.matchAll(DATE_IN_BRACKETS)) {
    const formatted = formatPortalExpiry((dm[1] ?? '').trim())
    if (formatted) expiry = formatted
  }
  return expiry
}

/**
 * MAC checkers often emit bare `http://host:port`. Mag portals expect `/c`.
 * Leave paths that already look like stalker alone.
 */
function stalkerPortalUrl(raw: string): string {
  const url = cleanPortalUrl(raw)
  if (!url) return url
  if (/\/c$/i.test(url) || /portal\.php|stalker_portal/i.test(url)) return url
  try {
    const parsed = new URL(url)
    if (parsed.pathname === '/' || parsed.pathname === '') {
      return cleanPortalUrl(`${url}/c`)
    }
  } catch {
    // keep cleaned
  }
  return url
}

function cleanCred(raw: string): string {
  let s = scrubQsValue(raw)
  while (s.startsWith('=')) s = s.slice(1)
  return (s.split(/[ \n&?]/)[0] ?? '').trim()
}

function isJunkCred(s: string): boolean {
  return !s || JUNK_CRED.test(s)
}

function isMacBridgePass(pass: string): boolean {
  const lp = pass.toLowerCase()
  return lp.includes('live.php') || lp.includes('mac=') || lp.startsWith('live.')
}

/** `live.php?mac=00:1A:79:…` (nested qs inside get.php password=). */
function macFromBridgePass(rawPass: string): string | null {
  const m =
    /mac=((?:[0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2})/i.exec(rawPass)
  if (!m?.[1]) return null
  return m[1].toUpperCase().replace(/-/g, ':')
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
  // "M3U/XTREAM" → leave null. Hint never overrides host+user+pass → xtream.

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
  let allowed = OUTPUTS_RE.exec(block)?.[1]?.trim() ?? null
  if (allowed) {
    // `[‘m3u8’, ‘ts’, ‘rtmp’]` → m3u8,ts,rtmp
    const listed = [...allowed.matchAll(/[a-z0-9]+/gi)].map((m) => m[0])
    if (listed.length > 0 && /\[/.test(allowed)) {
      allowed = listed.join(',')
    } else {
      allowed = allowed.replace(/\s+/g, '').replace(/,+$/, '')
    }
  }
  let expiredRaw =
    EXPIRED_RE.exec(block)?.[1]?.trim() ??
    EXP_DATE_RE.exec(block)?.[1]?.trim() ??
    null
  if (expiredRaw) {
    expiredRaw = expiredRaw.replace(/\s+\d+\s+Days?\s*$/i, '').trim()
  }
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
 * Spanish panel rows: `UTC  Activa  25 jul de 2026 (19 d)  25 jul de 2027  345  0 / 3  No`
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

  TABLE_ES_DATE.lastIndex = 0
  const esDates = [...tail.matchAll(TABLE_ES_DATE)]
  if (esDates.length > 0) {
    const last = esDates[esDates.length - 1]!
    const mon = TABLE_ES_MON[(last[2] ?? '').toLowerCase()]
    if (mon) expiry = formatPortalExpiry(`${Number(last[1])} ${mon} ${last[3]}`)
  }
  const spacedConn = TABLE_CONN_SPACED.exec(tail)
  if (spacedConn) maxConnections = spacedConn[2] ?? null

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
  const hit = re.exec(cleaned)?.[0] ?? ''
  if (!hit) return ''
  // Don't bleed Allowed Outputs / Expired on from the next Telegram card.
  const cut = hit.search(/\n(?:🔗|📡|🌐|🌍|Portal\s*:)/i)
  return cut >= 0 ? hit.slice(0, cut) : hit
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
  if (!url) return

  // Pull MAC before cleanCred — it splits on `?` and would drop `?mac=…`.
  const bridgeMac = macFromBridgePass(rawPass)
  const username = cleanCred(rawUser)
  const password = cleanCred(rawPass)

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

  // MAC-bridge fake M3U (`play` + `live.php?mac=…`) → stalker with MAC username.
  const isBridge =
    Boolean(bridgeMac) ||
    isMacBridgePass(rawPass) ||
    isMacBridgePass(password) ||
    (username.toLowerCase() === 'play' &&
      (password.toLowerCase().includes('live') ||
        password.toLowerCase().includes('mac') ||
        /live\.php/i.test(rawPass)))
  if (isBridge) {
    if (bridgeMac) {
      put(acc, {
        url: stalkerPortalUrl(url),
        username: bridgeMac,
        password: '',
        source,
        platform: 'stalker',
        type,
        output,
        ...shared,
      })
      return
    }
    if (username.length < 1 || password.length < 1) return
    if (isJunkCred(username) || isJunkCred(password)) return
    put(acc, {
      url: stalkerPortalUrl(url),
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

  if (username.length < 1 || password.length < 1) return
  if (isJunkCred(username) || isJunkCred(password)) return
  if (username.includes('http') || password.includes('http')) return

  const lu = url.toLowerCase()
  if (lu.endsWith('/c') || lu.includes('/c/')) {
    // Mag /c/ portals take MAC usernames — reject xtream user/pass glued on
    // via LABEL_* after math-sans `PANEL` folds to ASCII `Panel`.
    if (!MAC_ADDR_RE.test(username)) return
    put(acc, {
      url,
      username: username.toUpperCase().replace(/-/g, ':'),
      password: '',
      source,
      platform: 'stalker',
      type,
      output,
      ...shared,
    })
    return
  }

  // Host + user + pass is always Xtream (player_api). get.php `type=` /
  // `output=` (m3u_plus, m3u8, ts, …) are export metadata on the hit — not
  // the product platform. Bare playlist URLs use `__m3u__` via
  // extractM3uPlaylistUrls only.
  put(acc, {
    url,
    username,
    password,
    source,
    platform: 'xtream',
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
  // Telegram sometimes strips the 🔗 — still treat get.php as a URL mark so
  // the following 👤/🔑 card doesn't glue onto the previous host.
  for (const m of cleaned.matchAll(GET_PHP_URL)) {
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
    const urlUser = q.username || q.user || ''
    if (urlUser && urlUser !== mark.user) continue
    const block =
      cardBlockForUser(cleaned, mark.user) ||
      cleaned.slice(Math.max(0, mark.index - 80), mark.end + 200)
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
      // Credentialed rows stay xtream/stalker — never flip to m3u from a
      // note header that says "M3U" (that's usually Allowed Outputs / get.php).
      platform: p.platform === 'stalker' ? 'stalker' : 'xtream',
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
  extractPortalDumpLines(cleaned, acc, source, fileMeta)
  extractPathCredUrls(cleaned, acc, source, fileMeta)
  extractM3uPlaylistUrls(cleaned, acc, source, fileMeta)
  enrichPortalsFromCards(cleaned, acc, fileMeta)
  extractStalkerPortals(cleaned, acc, source, fileMeta)

  return [...acc.values()]
}

/**
 * Path-style Xtream lines (no get.php query):
 * `http://host:port/user/pass`
 * `http://host/live/user/pass` (also movie/series)
 */
function extractPathCredUrls(
  cleaned: string,
  acc: Map<string, ExtractedPortal>,
  source: string,
  fileMeta: FileMeta,
) {
  for (const line of cleaned.split(/\n/)) {
    const trimmed = line.trim().replace(/[.,;]+$/, '')
    if (!/^https?:\/\//i.test(trimmed)) continue
    if (/[?&](?:username|user)=/i.test(trimmed)) continue
    if (/\/(?:get|player_api|xmltv|portal)\.php/i.test(trimmed)) continue
    if (/\/c\/?$/i.test(trimmed) || /stalker_portal/i.test(trimmed)) continue
    if (/\.(?:m3u8?|m3u)(?:$|\?)/i.test(trimmed)) continue

    let parsed: URL
    try {
      parsed = new URL(trimmed)
    } catch {
      continue
    }
    let segs = parsed.pathname.split('/').filter(Boolean)
    if (
      segs.length === 3 &&
      /^(?:live|movie|series)$/i.test(segs[0] ?? '')
    ) {
      segs = segs.slice(1)
    }
    if (segs.length !== 2) continue

    let user = segs[0] ?? ''
    let pass = segs[1] ?? ''
    try {
      user = decodeURIComponent(user)
      pass = decodeURIComponent(pass)
    } catch {
      // keep raw
    }
    if (user.length < 2 || pass.length < 2) continue
    if (isJunkCred(user) || isJunkCred(pass)) continue
    if (/\.(?:php|html?|js|css|json|xml|ts|m3u8?)$/i.test(pass)) continue
    if (user.includes('http') || pass.includes('http')) continue

    const portalUrl = `${parsed.protocol}//${parsed.host}`
    finalizeXtreamOrM3u(
      acc,
      portalUrl,
      user,
      pass,
      source,
      '',
      '',
      undefined,
      fileMeta,
    )
  }
}

/**
 * Bare / labeled playlist URLs → platform=m3u with username `__m3u__` (no login).
 * Skips get.php (handled via username/password query extract).
 * Inside `#EXTM3U` notes: only `.m3u` / `.m3u8` URLs (playlist files), not every #EXTINF media.
 */
function extractM3uPlaylistUrls(
  cleaned: string,
  acc: Map<string, ExtractedPortal>,
  source: string,
  fileMeta: FileMeta,
) {
  const urls = new Set<string>()
  const labeledUrls = new Set<string>()

  for (const m of cleaned.matchAll(LABELED_PLAYLIST_URL)) {
    const u = (m[1] ?? '').replace(/[.,;]+$/, '')
    if (u) {
      urls.add(u)
      labeledUrls.add(u)
    }
  }
  for (const m of cleaned.matchAll(PLAYLIST_FILE_URL)) {
    const u = (m[0] ?? '').replace(/[.,;]+$/, '')
    if (u) urls.add(u)
  }

  for (const raw of urls) {
    if (/\/get\.php\?/i.test(raw) || /[?&]username=/i.test(raw)) continue
    if (/\/c\/?$/i.test(raw) || /stalker_portal|portal\.php/i.test(raw)) continue
    const url = cleanPortalUrl(raw)
    if (!url || !/^https?:\/\//i.test(url)) continue
    if (
      !labeledUrls.has(raw) &&
      !/\.(?:m3u8?|m3u)(?:$|\?)/i.test(url)
    ) {
      continue
    }
    put(acc, {
      url,
      username: M3U_USER_SENTINEL,
      password: '',
      source,
      platform: 'm3u',
      type: '',
      output: '',
      regionPrimary: fileMeta.region.primary,
      regionTags: fileMeta.region.tags,
      regionConfidence: fileMeta.region.confidence,
    })
  }
}

function dumpPortalHost(raw: string): string | null {
  const url = cleanPortalUrl(raw)
  if (
    !url ||
    /\/c\/?$/i.test(url) ||
    /portal\.php|stalker_portal/i.test(url)
  ) {
    return null
  }
  return url
}

/**
 * Sheets like j_1vsS7a: `Portal: http://host` then many
 * `user pass N Gün (Bitiş: dd/mm/yyyy)` lines.
 * Also a lone `http://host:port` then `Usr / pw` columns with `Expires:`.
 */
function extractPortalDumpLines(
  cleaned: string,
  acc: Map<string, ExtractedPortal>,
  source: string,
  fileMeta: FileMeta,
) {
  const lines = cleaned.split(/\n/)
  let currentPortal: string | null = null
  for (const line of lines) {
    const trimmed = line.trim()
    if (!trimmed) continue
    const portalLine = /^Portal\s*:\s*(https?:\/\/\S+)/i.exec(trimmed)
    if (portalLine?.[1]) {
      currentPortal = dumpPortalHost(portalLine[1])
      continue
    }
    const bareHost = BARE_DUMP_HOST.exec(trimmed)
    if (bareHost?.[1]) {
      currentPortal = dumpPortalHost(bareHost[1])
      continue
    }
    if (!currentPortal) continue
    if (DUMP_HEADER.test(trimmed)) continue
    if (
      /user\s*name|password|subject:|allowed\s*outputs|maxconn/i.test(trimmed)
    ) {
      continue
    }
    if (/^https?:\/\//i.test(trimmed)) continue
    const m = DUMP_CRED_LINE.exec(trimmed)
    if (!m?.[1] || !m[2]) continue
    const expiryRaw = m[3] || m[4] || ''
    const expiry = expiryRaw ? formatPortalExpiry(expiryRaw) : null
    finalizeXtreamOrM3u(
      acc,
      currentPortal,
      m[1],
      m[2],
      source,
      '',
      '',
      { expiry },
      fileMeta,
    )
  }
}

/**
 * Hit Hunter / Ishiro dump cards:
 * `├● 🔌 ᴍᴀᴄ : …` then nearby `ᴇxᴘɪʀᴀᴛɪᴏɴ` / `ᴘᴏʀᴛᴀʟ` / `ᴛɪᴍᴇᴢᴏɴᴇ`.
 */
function extractHitHunterStalkerCards(
  cleaned: string,
  acc: Map<string, ExtractedPortal>,
  source: string,
  pairedMacs: Set<string>,
  pairedPortals: Set<string>,
) {
  const lines = cleaned.split(/\n/)
  for (let i = 0; i < lines.length; i++) {
    const macM = HH_MAC_LINE.exec(lines[i] ?? '')
    if (!macM?.[1]) continue
    const mac = macM[1].toUpperCase().replace(/-/g, ':')
    if (pairedMacs.has(mac)) continue

    const window = lines.slice(i, Math.min(lines.length, i + 16)).join('\n')
    const portalRaw = HH_PORTAL_LINE.exec(window)?.[1]
    if (!portalRaw) continue
    const portalUrl = stalkerPortalUrl(portalRaw)
    if (!portalUrl) continue

    const expiryRaw = HH_EXP_LINE.exec(window)?.[1]?.trim() ?? null
    const expiry = expiryRaw ? formatPortalExpiry(expiryRaw) : null
    const timezone = HH_TZ_LINE.exec(window)?.[1]?.trim() || null
    const country = HH_COUNTRY_LINE.exec(window)?.[1]?.trim() || ''
    const region = timezone
      ? classifyRegion(timezone, country ? [country] : [])
      : country
        ? classifyRegionFromNote(country)
        : undefined

    pairedMacs.add(mac)
    pairedPortals.add(portalUrl)
    put(acc, {
      url: portalUrl,
      username: mac,
      password: '',
      source,
      platform: 'stalker',
      type: '',
      output: '',
      expiry,
      timezone,
      regionPrimary: region?.primary,
      regionTags: region?.tags,
      regionConfidence: region?.confidence,
    })
  }
}

/**
 * KC night-owl PANEL/MAC/EXPIRES cards (math-sans folded to ASCII).
 * Portal line first, then MAC + EXPIRES in the next few lines.
 */
function extractKcPanelStalkerCards(
  cleaned: string,
  acc: Map<string, ExtractedPortal>,
  source: string,
  pairedMacs: Set<string>,
  pairedPortals: Set<string>,
) {
  const lines = cleaned.split(/\n/)
  for (let i = 0; i < lines.length; i++) {
    const panelM = KC_PANEL_LINE.exec(lines[i] ?? '')
    if (!panelM?.[1]) continue
    const portalUrl = stalkerPortalUrl(panelM[1])
    if (!portalUrl) continue

    const window = lines.slice(i, Math.min(lines.length, i + 6)).join('\n')
    const macRaw = KC_MAC_LINE.exec(window)?.[1]
    if (!macRaw) continue
    const mac = macRaw.toUpperCase().replace(/-/g, ':')
    if (pairedMacs.has(mac)) continue

    let expiryRaw = KC_EXPIRES_LINE.exec(window)?.[1]?.trim() ?? null
    if (expiryRaw) {
      expiryRaw = expiryRaw
        .replace(/\s*\(\d+\s+Days?\)\s*$/i, '')
        .replace(/\s+\d+\s+Days?\s*$/i, '')
        .trim()
      if (/^unlimited$/i.test(expiryRaw)) expiryRaw = null
    }
    const expiry = expiryRaw ? formatPortalExpiry(expiryRaw) : null

    pairedMacs.add(mac)
    pairedPortals.add(portalUrl)
    put(acc, {
      url: portalUrl,
      username: mac,
      password: '',
      source,
      platform: 'stalker',
      type: '',
      output: '',
      expiry,
    })
  }
}

/**
 * MAC Raider cards: Host/Portal ➩ url, ExpDate ➩ …, MAC ➩ …
 */
function extractMacRaiderStalkerCards(
  cleaned: string,
  acc: Map<string, ExtractedPortal>,
  source: string,
  pairedMacs: Set<string>,
  pairedPortals: Set<string>,
) {
  const lines = cleaned.split(/\n/)
  for (let i = 0; i < lines.length; i++) {
    const hostM = RAIDER_HOST_LINE.exec(lines[i] ?? '')
    if (!hostM?.[1]) continue
    const portalUrl = stalkerPortalUrl(hostM[1])
    if (!portalUrl) continue

    const window = lines.slice(i, Math.min(lines.length, i + 18)).join('\n')
    const macRaw = RAIDER_MAC_LINE.exec(window)?.[1]
    if (!macRaw) continue
    const mac = macRaw.toUpperCase().replace(/-/g, ':')
    if (pairedMacs.has(mac)) continue

    let expiryRaw = RAIDER_EXP_LINE.exec(window)?.[1]?.trim() ?? null
    if (expiryRaw) {
      expiryRaw = expiryRaw.replace(/\s+\d+\s+Days?\s*$/i, '').trim()
    }
    const expiry = expiryRaw ? formatPortalExpiry(expiryRaw) : null

    pairedMacs.add(mac)
    pairedPortals.add(portalUrl)
    put(acc, {
      url: portalUrl,
      username: mac,
      password: '',
      source,
      platform: 'stalker',
      type: '',
      output: '',
      expiry,
    })
  }
}

/**
 * Prefer Portal+MAC(+Exp) cards and bare MAC dumps under a portal URL line;
 * fall back to unique portal×MAC cartesian for leftover labeled macs.
 */
function extractStalkerPortals(
  cleaned: string,
  acc: Map<string, ExtractedPortal>,
  source: string,
  _fileMeta: FileMeta,
) {
  const pairedMacs = new Set<string>()
  const pairedPortals = new Set<string>()

  extractHitHunterStalkerCards(
    cleaned,
    acc,
    source,
    pairedMacs,
    pairedPortals,
  )
  extractKcPanelStalkerCards(
    cleaned,
    acc,
    source,
    pairedMacs,
    pairedPortals,
  )
  extractMacRaiderStalkerCards(
    cleaned,
    acc,
    source,
    pairedMacs,
    pairedPortals,
  )

  for (const m of cleaned.matchAll(STALKER_HIT_LINE)) {
    const portalUrl = stalkerPortalUrl(m[1] ?? '')
    const mac = (m[2] ?? '').toUpperCase().replace(/-/g, ':')
    if (!portalUrl || !mac) continue
    const expiryRaw = m[3]?.trim() ?? null
    const expiry = expiryRaw ? formatPortalExpiry(expiryRaw) : null
    pairedMacs.add(mac)
    pairedPortals.add(portalUrl)
    put(acc, {
      url: portalUrl,
      username: mac,
      password: '',
      source,
      platform: 'stalker',
      type: '',
      output: '',
      expiry,
    })
  }

  for (const m of cleaned.matchAll(STALKER_CARD)) {
    const portalUrl = stalkerPortalUrl(m[1] ?? '')
    const mac = (m[2] ?? '').toUpperCase().replace(/-/g, ':')
    if (!portalUrl || !mac) continue
    const expiryRaw = m[3]?.trim() ?? null
    const expiry = expiryRaw ? formatPortalExpiry(expiryRaw) : null
    const after = cleaned.slice(
      m.index ?? 0,
      (m.index ?? 0) + m[0].length + 280,
    )
    const timezone =
      /(?:⏱\s*)?Server\s*timezone\s*:\s*([^\n]+)/i.exec(after)?.[1]?.trim() ||
      null
    const region = timezone ? classifyRegion(timezone, []) : undefined
    pairedMacs.add(mac)
    pairedPortals.add(portalUrl)
    put(acc, {
      url: portalUrl,
      username: mac,
      password: '',
      source,
      platform: 'stalker',
      type: '',
      output: '',
      expiry,
      timezone,
      regionPrimary: region?.primary,
      regionTags: region?.tags,
      regionConfidence: region?.confidence,
    })
  }

  // Line dumps: http://host/c/ (or bare host:port) then MAC lines.
  // Atlas HTML tables become URL / MAC / Expires on separate lines after td→newline.
  let currentPortal: string | null = null
  let lastStalker: { url: string; mac: string } | null = null
  for (const line of cleaned.split(/\n/)) {
    const trimmed = line.trim()
    if (!trimmed) continue

    const expOnly = /^Expires\s+on\s+(.+)/i.exec(trimmed)
    if (expOnly?.[1] && lastStalker) {
      put(acc, {
        url: lastStalker.url,
        username: lastStalker.mac,
        password: '',
        source,
        platform: 'stalker',
        type: '',
        output: '',
        expiry: formatPortalExpiry(expOnly[1].trim()),
      })
      continue
    }

    const portalOnly = STALKER_PORTAL_ONLY_LINE.exec(trimmed)
    if (portalOnly?.[1]) {
      const url = stalkerPortalUrl(portalOnly[1])
      if (url) currentPortal = url
      lastStalker = null
      continue
    }
    const bareHost = BARE_DUMP_HOST.exec(trimmed)
    if (bareHost?.[1]) {
      currentPortal = stalkerPortalUrl(bareHost[1])
      lastStalker = null
      continue
    }
    // Also accept "Portal: http://…/c/"
    const portalLabeled = /^Portal\s*:\s*(https?:\/\/\S+)/i.exec(trimmed)
    if (portalLabeled?.[1]) {
      const raw = portalLabeled[1]
      if (
        /\/c\/?$/i.test(raw) ||
        /portal\.php|stalker_portal/i.test(raw)
      ) {
        currentPortal = stalkerPortalUrl(raw)
      }
      lastStalker = null
      continue
    }

    if (!currentPortal) continue
    const macLine = BARE_MAC_LINE.exec(trimmed)
    if (!macLine?.[1]) continue
    const mac = macLine[1].toUpperCase().replace(/-/g, ':')
    const rest = macLine[2] ?? ''
    const expiry = expiryFromMacRest(rest)
    const geo = regionFromChannelGeoBracket(rest)
    pairedMacs.add(mac)
    pairedPortals.add(currentPortal)
    lastStalker = { url: currentPortal, mac }
    put(acc, {
      url: currentPortal,
      username: mac,
      password: '',
      source,
      platform: 'stalker',
      type: '',
      output: '',
      expiry,
      regionPrimary: geo?.primary,
      regionTags: geo?.tags,
      regionConfidence: geo?.confidence,
    })
  }

  const macs = [
    ...new Set(
      [...cleaned.matchAll(STALKER_MAC)]
        .map((m) => (m[1] ?? '').toUpperCase().replace(/-/g, ':'))
        .filter((mac) => mac && !pairedMacs.has(mac)),
    ),
  ]
  const portalUrls = [
    ...new Set(
      [...cleaned.matchAll(STALKER_PORTAL)]
        .map((m) => cleanPortalUrl(m[1] ?? ''))
        .filter((u): u is string => Boolean(u)),
    ),
  ]

  if (macs.length === 0) {
    // Don't leave empty-user stalker shells when MACs were paired.
    for (const portalUrl of portalUrls) {
      if (pairedPortals.has(portalUrl)) continue
      put(acc, {
        url: portalUrl,
        username: '',
        password: '',
        source,
        platform: 'stalker',
        type: '',
        output: '',
      })
    }
    return
  }

  for (const portalUrl of portalUrls) {
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
