import { portalKey, type IptvPortalRow } from '@/lib/sync-domains'

const CSV_HEADERS = [
  'label',
  'name',
  'url',
  'username',
  'password',
  'source',
  'platform',
  'expiry',
  'max',
  'active',
  'favorite',
] as const

type CsvHeader = (typeof CSV_HEADERS)[number]

const HEADER_ALIASES: Record<string, CsvHeader> = {
  label: 'label',
  name: 'name',
  url: 'url',
  username: 'username',
  user: 'username',
  password: 'password',
  pass: 'password',
  source: 'source',
  platform: 'platform',
  type: 'platform',
  expiry: 'expiry',
  expires: 'expiry',
  max: 'max',
  active: 'active',
  favorite: 'favorite',
  favourite: 'favorite',
}

function csvEscape(value: string): string {
  if (/[",\r\n]/.test(value)) {
    return `"${value.replaceAll('"', '""')}"`
  }
  return value
}

/** Parse one CSV line into fields (RFC 4180 quotes). */
export function parseCsvLine(line: string): string[] {
  const fields: string[] = []
  let current = ''
  let inQuotes = false
  for (let i = 0; i < line.length; i++) {
    const ch = line[i]!
    if (inQuotes) {
      if (ch === '"') {
        if (line[i + 1] === '"') {
          current += '"'
          i++
        } else {
          inQuotes = false
        }
      } else {
        current += ch
      }
      continue
    }
    if (ch === '"') {
      inQuotes = true
      continue
    }
    if (ch === ',') {
      fields.push(current)
      current = ''
      continue
    }
    current += ch
  }
  fields.push(current)
  return fields
}

function splitCsvRows(text: string): string[] {
  const normalized = text.replace(/^\uFEFF/, '').replace(/\r\n/g, '\n').replace(/\r/g, '\n')
  const rows: string[] = []
  let current = ''
  let inQuotes = false
  for (let i = 0; i < normalized.length; i++) {
    const ch = normalized[i]!
    if (ch === '"') {
      if (inQuotes && normalized[i + 1] === '"') {
        current += '""'
        i++
        continue
      }
      inQuotes = !inQuotes
      current += ch
      continue
    }
    if (ch === '\n' && !inQuotes) {
      if (current.trim().length > 0) rows.push(current)
      current = ''
      continue
    }
    current += ch
  }
  if (current.trim().length > 0) rows.push(current)
  return rows
}

function normalizeHeader(raw: string): CsvHeader | null {
  const key = raw.trim().toLowerCase().replace(/\s+/g, '')
  return HEADER_ALIASES[key] ?? null
}

function parseFavorite(raw: string | undefined): boolean | undefined {
  if (raw == null) return undefined
  const v = raw.trim().toLowerCase()
  if (!v) return undefined
  if (['yes', 'y', 'true', '1', 'fav', 'favorite', 'favourite'].includes(v)) {
    return true
  }
  if (['no', 'n', 'false', '0'].includes(v)) return false
  return undefined
}

export type ParsedPortalCsvRow = {
  portal: IptvPortalRow
  favorite?: boolean
}

export type ParsePortalsCsvResult = {
  portals: ParsedPortalCsvRow[]
  skipped: number
}

/** Parse a CSV string produced by `portalsToCsv` (or a compatible export). */
export function parsePortalsCsv(text: string): ParsePortalsCsvResult {
  const rows = splitCsvRows(text)
  if (rows.length === 0) {
    throw new Error('CSV is empty')
  }

  const headerCells = parseCsvLine(rows[0]!).map((h) => h.trim())
  const mapped = headerCells.map(normalizeHeader)
  const knownCount = mapped.filter(Boolean).length

  let dataStart = 0
  let columnIndex: Partial<Record<CsvHeader, number>> = {}

  if (knownCount >= 2) {
    mapped.forEach((header, index) => {
      if (header) columnIndex[header] = index
    })
    dataStart = 1
  } else if (headerCells.length >= 3) {
    // No header — assume export column order.
    CSV_HEADERS.forEach((header, index) => {
      columnIndex[header] = index
    })
    dataStart = 0
  } else {
    throw new Error('CSV needs a header row (url, username, password, …)')
  }

  if (
    columnIndex.url == null ||
    columnIndex.username == null ||
    columnIndex.password == null
  ) {
    throw new Error('CSV must include url, username, and password columns')
  }

  const portals: ParsedPortalCsvRow[] = []
  let skipped = 0

  for (let r = dataStart; r < rows.length; r++) {
    const cells = parseCsvLine(rows[r]!)
    const cell = (header: CsvHeader) => {
      const idx = columnIndex[header]
      if (idx == null) return ''
      return (cells[idx] ?? '').trim()
    }
    const url = cell('url')
    const username = cell('username')
    const password = cell('password')
    const platformRaw = cell('platform').toLowerCase()
    const platform =
      platformRaw === 'm3u' || platformRaw === 'stalker' ? platformRaw : 'xtream'
    const userOk =
      platform === 'm3u' ? Boolean(url) : Boolean(url && username)
    const passOk = platform === 'xtream' ? Boolean(password) : true
    if (!userOk || !passOk) {
      skipped++
      continue
    }
    const portal: IptvPortalRow = {
      url,
      username: platform === 'm3u' ? '__m3u__' : username,
      password,
      platform,
      portalName: cell('label') || cell('name') || username || 'M3U',
      source: cell('source') || 'csv',
      expiry: cell('expiry') || undefined,
      max: cell('max') || undefined,
      active: cell('active') || undefined,
    }
    portals.push({
      portal,
      favorite: parseFavorite(cell('favorite')),
    })
  }

  if (portals.length === 0) {
    throw new Error(
      skipped > 0
        ? 'No valid portals found (need url, username, and password on each row)'
        : 'No portal rows found',
    )
  }

  return { portals, skipped }
}

export type MergePortalsCsvLogEntry = {
  status: 'added' | 'already_present'
  label: string
  url: string
  username: string
}

export type MergePortalsCsvResult = {
  portals: IptvPortalRow[]
  favoriteKeys: string[]
  added: number
  skippedExisting: number
  log: MergePortalsCsvLogEntry[]
}

function portalLogLabel(portal: IptvPortalRow): string {
  const label = (portal.portalName ?? portal.label)?.trim()
  if (label) return label
  const user = portal.username?.trim()
  return user || portal.url || 'Portal'
}

/** Add CSV portals that are not already in the list; never overwrite existing rows. */
export function mergePortalsFromCsv(
  existingPortals: IptvPortalRow[],
  existingFavorites: Iterable<string>,
  parsed: ParsedPortalCsvRow[],
): MergePortalsCsvResult {
  const byKey = new Map(existingPortals.map((p) => [portalKey(p), p]))
  const favorites = new Set(existingFavorites)
  let added = 0
  let skippedExisting = 0
  const log: MergePortalsCsvLogEntry[] = []

  for (const row of parsed) {
    const key = portalKey(row.portal)
    const label = portalLogLabel(row.portal)
    if (byKey.has(key)) {
      skippedExisting++
      log.push({
        status: 'already_present',
        label,
        url: row.portal.url,
        username: row.portal.username,
      })
      continue
    }
    byKey.set(key, row.portal)
    added++
    log.push({
      status: 'added',
      label,
      url: row.portal.url,
      username: row.portal.username,
    })
    if (row.favorite === true) favorites.add(key)
  }

  return {
    portals: [...byKey.values()],
    favoriteKeys: [...favorites],
    added,
    skippedExisting,
    log,
  }
}

/** Build a CSV string for Xtream portals (UTF-8, Excel-friendly BOM). */
export function portalsToCsv(
  portals: IptvPortalRow[],
  favoriteKeys: Iterable<string> = [],
): string {
  const favorites = new Set(favoriteKeys)
  const lines = [
    CSV_HEADERS.join(','),
    ...portals.map((portal) => {
      const cells: string[] = [
        (portal.portalName ?? portal.label)?.trim() ?? '',
        '',
        portal.url ?? '',
        portal.username ?? '',
        portal.password ?? '',
        portal.source?.trim() ?? '',
        portal.platform ?? 'xtream',
        portal.expiry?.trim() ?? '',
        portal.max?.trim() ?? '',
        portal.active?.trim() ?? '',
        favorites.has(portalKey(portal)) ? 'yes' : 'no',
      ]
      return cells.map(csvEscape).join(',')
    }),
  ]
  return `\uFEFF${lines.join('\r\n')}\r\n`
}

/** Trigger a browser download of a text blob. */
export function downloadTextFile(
  filename: string,
  content: string,
  mime = 'text/csv;charset=utf-8',
): void {
  if (typeof document === 'undefined') return
  const blob = new Blob([content], { type: mime })
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = filename
  anchor.rel = 'noopener'
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()
  window.setTimeout(() => URL.revokeObjectURL(url), 2_000)
}

export function iptvPortalsCsvFilename(date = new Date()): string {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `forja-iptv-portals-${y}-${m}-${d}.csv`
}
