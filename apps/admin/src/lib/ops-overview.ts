import { adminDb } from '@/lib/admin-db'
import {
  type ScrapeRunRow,
  fetchScrapeRuns,
  runDurationMs,
} from '@/lib/scrape-runs'

export const OPS_OVERVIEW_KEY = ['admin', 'ops_overview'] as const

export type RegionCount = { region: string; count: number }

export type OpsOverview = {
  all: number
  pool: number
  alive: number
  dead: number
  unchecked: number
  accounts: number
  creditsTotal: number
  scrapeEnabledAccounts: number
  runsTotal: number
  runsOk: number
  runsError: number
  runsRunning: number
  postsSeenTotal: number
  upsertedTotal: number
  scheduleEnabled: boolean
  scheduleCron: string
  regions: RegionCount[]
  latest: ScrapeRunRow | null
  recent: ScrapeRunRow[]
}

export async function fetchOpsOverview(): Promise<OpsOverview> {
  const [
    all,
    pool,
    alive,
    dead,
    unchecked,
    accounts,
    creditRows,
    scrapeFeature,
    runsTotal,
    runsOk,
    runsError,
    runsRunning,
    settings,
    regionRows,
    recent,
  ] = await Promise.all([
    adminDb
      .from('iptv_portals')
      .select('id', { count: 'exact', head: true }),
    adminDb
      .from('iptv_portals')
      .select('id', { count: 'exact', head: true })
      .eq('catalog_pool', true),
    adminDb
      .from('iptv_portals')
      .select('id', { count: 'exact', head: true })
      .eq('catalog_pool', true)
      .eq('alive', true),
    adminDb
      .from('iptv_portals')
      .select('id', { count: 'exact', head: true })
      .eq('catalog_pool', true)
      .eq('alive', false),
    adminDb
      .from('iptv_portals')
      .select('id', { count: 'exact', head: true })
      .eq('catalog_pool', true)
      .is('alive', null),
    adminDb.from('accounts').select('id', { count: 'exact', head: true }),
    adminDb.from('accounts').select('iptv_credits').limit(5000),
    adminDb
      .from('accounts')
      .select('id, features')
      .contains('features', { iptvScrape: true })
      .limit(5000),
    adminDb.from('iptv_scrape_runs').select('id', { count: 'exact', head: true }),
    adminDb
      .from('iptv_scrape_runs')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'ok'),
    adminDb
      .from('iptv_scrape_runs')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'error'),
    adminDb
      .from('iptv_scrape_runs')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'running'),
    adminDb
      .from('iptv_ops_settings')
      .select('scrape_cron_enabled, scrape_cron')
      .eq('id', 1)
      .maybeSingle(),
    adminDb
      .from('iptv_portals')
      .select('region_primary')
      .eq('catalog_pool', true)
      .limit(2000),
    fetchScrapeRuns(8),
  ])

  const creditsTotal = ((creditRows.data ?? []) as { iptv_credits: number }[])
    .reduce((n, r) => n + (r.iptv_credits ?? 0), 0)

  const regionMap = new Map<string, number>()
  for (const row of (regionRows.data ?? []) as { region_primary: string }[]) {
    const key = (row.region_primary || 'UNKNOWN').trim() || 'UNKNOWN'
    regionMap.set(key, (regionMap.get(key) ?? 0) + 1)
  }
  const regions = [...regionMap.entries()]
    .map(([region, count]) => ({ region, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 8)

  const postsSeenTotal = recent.reduce((n, r) => n + (r.posts_seen ?? 0), 0)
  const upsertedTotal = recent.reduce(
    (n, r) => n + (r.candidates_upserted ?? 0),
    0,
  )

  return {
    all: all.count ?? 0,
    pool: pool.count ?? 0,
    alive: alive.count ?? 0,
    dead: dead.count ?? 0,
    unchecked: unchecked.count ?? 0,
    accounts: accounts.count ?? 0,
    creditsTotal,
    scrapeEnabledAccounts: (scrapeFeature.data ?? []).length,
    runsTotal: runsTotal.count ?? 0,
    runsOk: runsOk.count ?? 0,
    runsError: runsError.count ?? 0,
    runsRunning: runsRunning.count ?? 0,
    postsSeenTotal,
    upsertedTotal,
    scheduleEnabled: settings.data?.scrape_cron_enabled !== false,
    scheduleCron:
      typeof settings.data?.scrape_cron === 'string' &&
      settings.data.scrape_cron.trim()
        ? settings.data.scrape_cron.trim()
        : '0 6 * * *',
    regions,
    latest: recent[0] ?? null,
    recent,
  }
}

export function formatDuration(ms: number | null): string {
  if (ms == null || ms < 0) return '—'
  if (ms < 1000) return `${ms}ms`
  const s = Math.round(ms / 1000)
  if (s < 60) return `${s}s`
  const m = Math.floor(s / 60)
  const rem = s % 60
  return rem ? `${m}m ${rem}s` : `${m}m`
}

export function runDurationLabel(run: ScrapeRunRow): string {
  return formatDuration(runDurationMs(run))
}
