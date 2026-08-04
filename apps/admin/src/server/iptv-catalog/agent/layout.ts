import { formatPortalExpiry } from '@/lib/iptv-portal-expiry'
import {
  type ExtractedPortal,
  type FileMeta,
  type PortalPlatform,
  extractPortals,
  ingestPortalHit,
} from '../extract'
import { classifyRegion, classifyRegionFromNote } from '../region'

export const SAMPLE_BUDGET = 3_500

/** Line token roles for whitespace-split table / dump rows. */
export type LayoutToken =
  | 'hostPort'
  | 'userPass'
  | 'conn'
  | 'expiryMonDay'
  | 'expiryYear'
  | 'expiryNo'
  | 'status'
  | 'outputs'
  | 'timezone'
  | 'skip'
  | 'hostRepeat'

export type NoteLayout = {
  kind: 'table' | 'emoji_card' | 'get_php' | 'labeled' | 'line_template' | 'unknown'
  confidence?: number
  regionHint?: string | null
  platformHint?: 'xtream' | 'm3u' | 'stalker' | null
  tokens?: LayoutToken[]
  minUserLen?: number
  minPassLen?: number
}

export function isDenseLine(line: string): boolean {
  const t = line.trim()
  if (t.length < 8) return false
  return (
    /https?:\/\//i.test(t) ||
    /username|password|maxconn|🔗|👤|🔑/i.test(t) ||
    /:\d{2,5}\s+\S+:\S+/.test(t) ||
    /(?:\d{1,3}\.){3}\d{1,3}:\d{2,5}/.test(t) ||
    /[A-Za-z0-9.-]+:\d{2,5}\s+\S+:\S+/.test(t)
  )
}

export function buildStructureSample(text: string): {
  sample: string
  truncated: boolean
  lineCount: number
  denseLineCount: number
} {
  const lines = text.split(/\r?\n/)
  if (text.length <= SAMPLE_BUDGET) {
    return {
      sample: text,
      truncated: false,
      lineCount: lines.length,
      denseLineCount: lines.filter(isDenseLine).length,
    }
  }

  const headLines = lines.slice(0, 12)
  const dense = lines.filter(isDenseLine)
  const early = dense.slice(0, 40)
  const midStart = Math.max(40, Math.floor(dense.length / 2) - 8)
  const mid = dense.slice(midStart, midStart + 16)
  const picked: string[] = []
  const seen = new Set<string>()
  for (const block of [...headLines, ...early, ...mid]) {
    if (seen.has(block)) continue
    seen.add(block)
    picked.push(block)
    if (picked.join('\n').length >= SAMPLE_BUDGET) break
  }
  let sample = picked.join('\n')
  if (sample.length > SAMPLE_BUDGET) sample = sample.slice(0, SAMPLE_BUDGET)
  return {
    sample,
    truncated: true,
    lineCount: lines.length,
    denseLineCount: dense.length,
  }
}

function asPlatform(raw: string | undefined | null): PortalPlatform | undefined {
  const p = (raw ?? '').trim().toLowerCase()
  if (p === 'xtream' || p === 'm3u' || p === 'stalker') return p
  return undefined
}

const MON_DAY =
  /^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)(\d{1,2})$/i

function parseUserPass(
  token: string,
  minUser: number,
  minPass: number,
): { user: string; pass: string } | null {
  const i = token.indexOf(':')
  if (i <= 0) return null
  const user = token.slice(0, i).trim()
  const pass = token.slice(i + 1).trim()
  if (user.length < minUser || pass.length < minPass) return null
  return { user, pass }
}

function parseHostPort(token: string): string | null {
  const t = token.trim()
  if (/^https?:\/\//i.test(t)) return t
  if (/^\[?[A-Za-z0-9._-]+\]?:\d{2,5}$/.test(t)) return `http://${t}`
  if (/^(?:\d{1,3}\.){3}\d{1,3}:\d{2,5}$/.test(t)) return `http://${t}`
  if (/^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}:\d{2,5}$/.test(t)) return `http://${t}`
  return null
}

const DEFAULT_TABLE_TOKENS: LayoutToken[] = [
  'hostPort',
  'userPass',
  'conn',
  'expiryMonDay',
  'expiryYear',
  'status',
  'hostRepeat',
  'outputs',
  'timezone',
]

export function applyNoteLayout(
  fullText: string,
  layout: NoteLayout,
  source: string,
  fileMeta: FileMeta,
): ExtractedPortal[] {
  const acc = new Map<string, ExtractedPortal>()
  const minUser = Math.max(1, layout.minUserLen ?? 1)
  const minPass = Math.max(1, layout.minPassLen ?? 1)
  const regionHint = classifyRegionFromNote(
    String(layout.regionHint ?? '').trim(),
  )
  const baseRegion =
    regionHint.primary !== 'UNKNOWN' ? regionHint : fileMeta.region
  const platformHint = asPlatform(layout.platformHint ?? undefined)

  const tokens =
    layout.tokens && layout.tokens.length > 0
      ? layout.tokens
      : layout.kind === 'table' || layout.kind === 'line_template'
        ? DEFAULT_TABLE_TOKENS
        : null

  if (tokens) {
    for (const line of fullText.split(/\r?\n/)) {
      const parts = line.trim().split(/\s+/).filter(Boolean)
      if (parts.length < 2) continue

      let url = ''
      let user = ''
      let pass = ''
      let maxConnections: string | null = null
      let expiry: string | null = null
      let allowedOutputs: string | null = null
      let timezone: string | null = null
      let monDay: string | null = null

      const roles =
        parts.length >= tokens.length ? tokens : tokens.slice(0, parts.length)

      for (let i = 0; i < roles.length && i < parts.length; i++) {
        const role = roles[i]!
        const tok = parts[i]!
        switch (role) {
          case 'hostPort': {
            const hp = parseHostPort(tok)
            if (hp) url = hp
            break
          }
          case 'userPass': {
            const up = parseUserPass(tok, minUser, minPass)
            if (up) {
              user = up.user
              pass = up.pass
            }
            break
          }
          case 'conn': {
            const m = /^(\d+)\/(\d+)$/.exec(tok)
            if (m) maxConnections = m[2] ?? null
            break
          }
          case 'expiryMonDay': {
            if (/^no_expiry$/i.test(tok)) {
              expiry = null
              monDay = null
            } else if (MON_DAY.test(tok)) {
              monDay = tok
            }
            break
          }
          case 'expiryYear': {
            if (/^no_expiry$/i.test(tok)) {
              expiry = null
            } else if (monDay && /^\d{4}$/.test(tok)) {
              const md = MON_DAY.exec(monDay)
              if (md) {
                const mon =
                  md[1]!.charAt(0).toUpperCase() +
                  md[1]!.slice(1, 3).toLowerCase()
                expiry = formatPortalExpiry(`${Number(md[2])} ${mon} ${tok}`)
              }
            }
            break
          }
          case 'expiryNo':
            expiry = null
            break
          case 'outputs':
            if (/(?:m3u8?|ts|rtmp)/i.test(tok)) allowedOutputs = tok
            break
          case 'timezone':
            if (/^[A-Za-z]+\/[A-Za-z_/+]+$/.test(tok)) timezone = tok
            break
          default:
            break
        }
      }

      if (!url || !user || !pass) {
        for (const tok of parts) {
          if (!url) {
            const hp = parseHostPort(tok)
            if (hp) url = hp
          }
          if (!user || !pass) {
            const up = parseUserPass(tok, minUser, minPass)
            if (up) {
              user = up.user
              pass = up.pass
            }
          }
        }
      }
      if (!url || !user || !pass) continue

      const tzRegion = timezone ? classifyRegion(timezone, []) : null
      const region =
        tzRegion && tzRegion.primary !== 'UNKNOWN' ? tzRegion : baseRegion

      ingestPortalHit(
        acc,
        {
          url,
          username: user,
          password: pass,
          platform: platformHint,
          type: '',
          output: allowedOutputs ?? '',
          expiry,
          maxConnections,
          timezone,
          allowedOutputs,
          regionPrimary: region.primary,
          regionTags: region.tags,
          regionConfidence: region.confidence,
        },
        source,
        fileMeta,
      )
    }
  }

  for (const p of extractPortals(fullText, source)) {
    ingestPortalHit(
      acc,
      {
        url: p.url,
        username: p.username,
        password: p.password,
        platform: p.platform,
        type: p.type,
        output: p.output,
        expiry: p.expiry,
        maxConnections: p.maxConnections,
        timezone: p.timezone,
        allowedOutputs: p.allowedOutputs,
        regionPrimary: p.regionPrimary,
        regionTags: p.regionTags,
        regionConfidence: p.regionConfidence,
      },
      source,
      fileMeta,
    )
  }

  return [...acc.values()]
}

export function previewPortals(portals: ExtractedPortal[], n = 3) {
  return portals.slice(0, n).map((p) => ({
    url: p.url,
    username: p.username,
    platform: p.platform,
    type: p.type,
    output: p.output,
    maxConnections: p.maxConnections,
    expiry: p.expiry,
  }))
}
