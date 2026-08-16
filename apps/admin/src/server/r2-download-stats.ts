/**
 * Installer download stats: Cloudflare GraphQL GetObject → R2 JSON rollup.
 * Object: stats/downloads.json (lifetime days; CF only keeps ~31d raw).
 */

import { r2Config, r2GetObject, r2GetObjectPublic, r2PutObject, hasR2S3Creds } from '@/server/r2-s3'

export const DOWNLOADS_STATS_KEY = 'stats/downloads.json'

export type DaySlice = {
  by_platform: Record<string, number>
  by_object: Record<string, number>
}

export type DownloadsRollup = {
  schema: 1
  updated_at: string
  bucket: string
  /** UTC YYYY-MM-DD → that day's installer GetObject counts */
  days: Record<string, DaySlice>
  totals: {
    total: number
    by_platform: Record<string, number>
    by_object: Record<string, number>
  }
}

export type DownloadStatsView = {
  total: number
  byPlatform: Record<string, number>
  byObject: Array<{ object: string; platform: string; count: number }>
  byVersion: Array<{
    version: string
    count: number
    byPlatform: Record<string, number>
  }>
  dayCount: number
  updatedAt: string | null
  bucket: string
  source: 'r2_rollup'
}

const SHOWCASE = ['windows', 'macos', 'linux', 'android_tv'] as const

export function detectPlatformFromObject(objectName: string): string {
  const file = (objectName.split('/').pop() ?? objectName).toLowerCase()
  if (
    !file ||
    file === 'manifest.json' ||
    file.endsWith('.md') ||
    file.endsWith('.json')
  ) {
    return 'other'
  }
  if (file.includes('windows') || file.endsWith('.exe') || file.endsWith('.msi')) {
    return 'windows'
  }
  if (file.includes('macos') || file.includes('darwin') || file.endsWith('.dmg')) {
    return 'macos'
  }
  if (
    file.includes('linux') ||
    file.endsWith('.appimage') ||
    file.endsWith('.deb') ||
    file.endsWith('.rpm')
  ) {
    return 'linux'
  }
  if (
    file.includes('android-tv') ||
    file.includes('android_tv') ||
    file.includes('androidtv') ||
    file.endsWith('.apk') ||
    file.includes('android')
  ) {
    return 'android_tv'
  }
  if (file.includes('ios') || file.endsWith('.ipa')) return 'ios'
  return 'other'
}

export function isInstallerObject(objectName: string): boolean {
  const file = (objectName.split('/').pop() ?? objectName).toLowerCase()
  return (
    file.endsWith('.exe') ||
    file.endsWith('.msi') ||
    file.endsWith('.dmg') ||
    file.endsWith('.appimage') ||
    file.endsWith('.deb') ||
    file.endsWith('.rpm') ||
    file.endsWith('.apk') ||
    file.endsWith('.ipa')
  )
}

/** Prefer semver in filename, else `v1.2.3/…` prefix, else `latest` / `unknown`. */
export function versionFromObjectKey(objectName: string): string {
  const parts = objectName.split('/').filter(Boolean)
  const file = parts[parts.length - 1] ?? objectName
  const fileMatch = file.match(/(?:^|[^0-9])(\d+\.\d+\.\d+)(?:[^0-9]|$)/)
  if (fileMatch) return fileMatch[1]

  const prefix = parts[0] ?? ''
  const prefixMatch = prefix.match(/^v?(\d+\.\d+\.\d+)$/i)
  if (prefixMatch) return prefixMatch[1]

  if (prefix.toLowerCase() === 'latest') return 'latest'
  return 'unknown'
}

function compareSemverDesc(a: string, b: string): number {
  const pa = a.split('.').map((n) => Number(n))
  const pb = b.split('.').map((n) => Number(n))
  if (pa.length === 3 && pb.length === 3 && pa.every(Number.isFinite) && pb.every(Number.isFinite)) {
    for (let i = 0; i < 3; i++) {
      if (pa[i] !== pb[i]) return pb[i]! - pa[i]!
    }
    return 0
  }
  if (a === 'latest') return -1
  if (b === 'latest') return 1
  return a.localeCompare(b)
}

/** UTC calendar day YYYY-MM-DD */
export function utcDayString(d: Date): string {
  return d.toISOString().slice(0, 10)
}

export function emptyRollup(bucket: string): DownloadsRollup {
  return {
    schema: 1,
    updated_at: new Date().toISOString(),
    bucket,
    days: {},
    totals: {
      total: 0,
      by_platform: Object.fromEntries(SHOWCASE.map((id) => [id, 0])),
      by_object: {},
    },
  }
}

function recomputeTotals(rollup: DownloadsRollup): void {
  const byPlatform: Record<string, number> = Object.fromEntries(
    SHOWCASE.map((id) => [id, 0]),
  )
  const byObject: Record<string, number> = {}
  for (const slice of Object.values(rollup.days)) {
    for (const [p, n] of Object.entries(slice.by_platform)) {
      byPlatform[p] = (byPlatform[p] ?? 0) + n
    }
    for (const [obj, n] of Object.entries(slice.by_object)) {
      byObject[obj] = (byObject[obj] ?? 0) + n
    }
  }
  rollup.totals = {
    total: Object.values(byObject).reduce((s, n) => s + n, 0),
    by_platform: byPlatform,
    by_object: byObject,
  }
  rollup.updated_at = new Date().toISOString()
}

type GqlGroup = {
  sum?: { requests?: number }
  dimensions?: { objectName?: string | null; actionType?: string | null }
}

/** CF GetObject groups for [start, end) → DaySlice (installers only). */
export async function fetchCfDaySlice(opts: {
  start: Date
  end: Date
  bucket?: string
}): Promise<DaySlice> {
  const { accountId, bucket: defaultBucket } = r2Config()
  const token =
    process.env.CLOUDFLARE_API_TOKEN?.trim() ||
    process.env.CF_API_TOKEN?.trim() ||
    ''
  const bucket = opts.bucket ?? defaultBucket

  if (!token) {
    throw new Error(
      'CLOUDFLARE_API_TOKEN is not configured (Account → Create Token → Account Analytics Read)',
    )
  }

  const query = `
    query R2Downloads($accountTag: String!, $start: Time, $end: Time, $bucket: String) {
      viewer {
        accounts(filter: { accountTag: $accountTag }) {
          r2OperationsAdaptiveGroups(
            limit: 10000
            filter: {
              datetime_geq: $start
              datetime_leq: $end
              bucketName: $bucket
              actionType: "GetObject"
            }
          ) {
            sum { requests }
            dimensions { objectName actionType }
          }
        }
      }
    }
  `

  const res = await fetch('https://api.cloudflare.com/client/v4/graphql', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      query,
      variables: {
        accountTag: accountId,
        start: opts.start.toISOString(),
        // Inclusive upper bound: last ms of [start, end)
        end: new Date(opts.end.getTime() - 1).toISOString(),
        bucket,
      },
    }),
  })

  const body = (await res.json().catch(() => ({}))) as {
    data?: {
      viewer?: {
        accounts?: Array<{ r2OperationsAdaptiveGroups?: GqlGroup[] }>
      }
    }
    errors?: Array<{ message?: string }>
  }

  if (!res.ok) throw new Error(`Cloudflare GraphQL HTTP ${res.status}`)
  if (body.errors?.length) {
    throw new Error(body.errors.map((e) => e.message ?? 'GraphQL error').join('; '))
  }

  const groups =
    body.data?.viewer?.accounts?.[0]?.r2OperationsAdaptiveGroups ?? []

  const by_platform: Record<string, number> = Object.fromEntries(
    SHOWCASE.map((id) => [id, 0]),
  )
  const by_object: Record<string, number> = {}

  for (const g of groups) {
    const objectName = g.dimensions?.objectName?.trim() || ''
    if (!objectName || !isInstallerObject(objectName)) continue
    const count = Number(g.sum?.requests ?? 0)
    if (!Number.isFinite(count) || count <= 0) continue

    const platform = detectPlatformFromObject(objectName)
    by_platform[platform] = (by_platform[platform] ?? 0) + count
    by_object[objectName] = (by_object[objectName] ?? 0) + count
  }

  return { by_platform, by_object }
}

function parseRollupBytes(
  raw: Uint8Array,
  bucket: string,
): DownloadsRollup | null {
  try {
    const parsed = JSON.parse(new TextDecoder().decode(raw)) as DownloadsRollup
    if (parsed?.schema !== 1 || !parsed.days) return null
    parsed.bucket = parsed.bucket || bucket
    if (!parsed.totals) recomputeTotals(parsed)
    return parsed
  } catch {
    return null
  }
}

export async function readDownloadsRollup(): Promise<DownloadsRollup> {
  const { bucket, cdnBase } = r2Config()

  // S3 first — same path the cron writes. CDN can serve a stale edge copy of
  // stats/downloads.json after overwrite even with cache: no-store on fetch.
  if (hasR2S3Creds()) {
    const raw = await r2GetObject(DOWNLOADS_STATS_KEY)
    if (!raw) return emptyRollup(bucket)
    return parseRollupBytes(raw, bucket) ?? emptyRollup(bucket)
  }

  if (cdnBase) {
    try {
      const fromCdn = await r2GetObjectPublic(DOWNLOADS_STATS_KEY)
      if (fromCdn) {
        const parsed = parseRollupBytes(fromCdn, bucket)
        if (parsed) return parsed
      }
    } catch {
      // empty below
    }
    return emptyRollup(bucket)
  }

  throw new Error(
    'Set R2_ACCESS_KEY_ID + R2_SECRET_ACCESS_KEY (preferred) and/or RELEASE_CDN_URL on the admin host',
  )
}

export async function writeDownloadsRollup(
  rollup: DownloadsRollup,
): Promise<void> {
  recomputeTotals(rollup)
  const body = `${JSON.stringify(rollup, null, 2)}\n`
  await r2PutObject(DOWNLOADS_STATS_KEY, body, 'application/json')
}

/** Upsert one UTC day (idempotent replace). */
export function upsertDay(
  rollup: DownloadsRollup,
  day: string,
  slice: DaySlice,
): DownloadsRollup {
  rollup.days[day] = slice
  recomputeTotals(rollup)
  return rollup
}

export function rollupToView(rollup: DownloadsRollup): DownloadStatsView {
  const byObject = Object.entries(rollup.totals.by_object)
    .map(([object, count]) => ({
      object,
      platform: detectPlatformFromObject(object),
      count,
    }))
    .sort((a, b) => b.count - a.count)

  const versionMap = new Map<
    string,
    { count: number; byPlatform: Record<string, number> }
  >()
  for (const row of byObject) {
    const version = versionFromObjectKey(row.object)
    const cur = versionMap.get(version) ?? {
      count: 0,
      byPlatform: Object.fromEntries(SHOWCASE.map((id) => [id, 0])),
    }
    cur.count += row.count
    cur.byPlatform[row.platform] =
      (cur.byPlatform[row.platform] ?? 0) + row.count
    versionMap.set(version, cur)
  }

  const byVersion = [...versionMap.entries()]
    .map(([version, v]) => ({
      version,
      count: v.count,
      byPlatform: v.byPlatform,
    }))
    .sort((a, b) => {
      const sem = compareSemverDesc(a.version, b.version)
      if (sem !== 0) return sem
      return b.count - a.count
    })

  return {
    total: rollup.totals.total,
    byPlatform: rollup.totals.by_platform,
    byObject,
    byVersion,
    dayCount: Object.keys(rollup.days).length,
    updatedAt:
      Object.keys(rollup.days).length > 0 ? rollup.updated_at : null,
    bucket: rollup.bucket,
    source: 'r2_rollup',
  }
}

/** Snapshot UTC days in [fromDay, toDay] inclusive from CF into the rollup file. */
export async function rollupDaysFromCf(opts: {
  fromDay: string
  toDay: string
}): Promise<{
  daysWritten: string[]
  view: DownloadStatsView
}> {
  const { bucket } = r2Config()
  const rollup = await readDownloadsRollup()
  rollup.bucket = bucket

  const daysWritten: string[] = []
  const cursor = new Date(`${opts.fromDay}T00:00:00.000Z`)
  const endDay = opts.toDay

  while (utcDayString(cursor) <= endDay) {
    const day = utcDayString(cursor)
    const start = new Date(`${day}T00:00:00.000Z`)
    const end = new Date(start.getTime() + 24 * 60 * 60 * 1000)
    const slice = await fetchCfDaySlice({ start, end, bucket })
    upsertDay(rollup, day, slice)
    daysWritten.push(day)
    cursor.setUTCDate(cursor.getUTCDate() + 1)
  }

  await writeDownloadsRollup(rollup)
  return { daysWritten, view: rollupToView(rollup) }
}

/** Yesterday UTC only (daily cron). */
export async function rollupYesterday(): Promise<{
  day: string
  view: DownloadStatsView
}> {
  const yesterday = new Date()
  yesterday.setUTCDate(yesterday.getUTCDate() - 1)
  const day = utcDayString(yesterday)
  const { view } = await rollupDaysFromCf({ fromDay: day, toDay: day })
  return { day, view }
}

/** GET catch-up after the 10:00 UTC job — skip if CF day likely incomplete. */
export function missingYesterdayAfterCronHour(
  rollup: DownloadsRollup,
  now = new Date(),
): boolean {
  if (now.getUTCHours() < 10) return false
  const yesterday = new Date(now)
  yesterday.setUTCDate(yesterday.getUTCDate() - 1)
  return !rollup.days[utcDayString(yesterday)]
}
