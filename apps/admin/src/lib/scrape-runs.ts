import type { QueryClient } from '@tanstack/react-query'
import { adminDb } from '@/lib/admin-db'
import { fetchAllRows } from '@/lib/fetch-all-rows'
import { supabase } from '@/lib/supabase'

export const SCRAPE_RUNS_KEY = ['admin', 'scrape_runs'] as const
export const SCRAPE_RUNS_LATEST_KEY = ['admin', 'scrape_runs', 'latest'] as const

export const SCRAPE_RUN_SELECT =
  'id, started_at, finished_at, status, source, posts_seen, l1_extract_count, deep_ref_count, l2_fetch_ok, l2_fetch_fail, l2_extract_count, unparsed_count, candidates_upserted, alive_count, error'

export const PROMOTE_BACKFILL_SOURCE = 'promote-backfill'
export const STALKER_NOTE_BACKFILL_SOURCE = 'stalker-note-backfill'

export type ScrapeRunRow = {
  id: string
  started_at: string
  finished_at: string | null
  status: string
  source?: string | null
  posts_seen: number
  l1_extract_count: number
  deep_ref_count: number
  l2_fetch_ok: number
  l2_fetch_fail: number
  l2_extract_count: number
  unparsed_count: number
  candidates_upserted: number
  alive_count: number
  error?: string | null
}

export function isPromoteBackfillRun(run: {
  source?: string | null
}): boolean {
  return run.source === PROMOTE_BACKFILL_SOURCE
}

export function isStalkerNoteBackfillRun(run: {
  source?: string | null
}): boolean {
  return run.source === STALKER_NOTE_BACKFILL_SOURCE
}

export function isOpsBackfillRun(run: {
  source?: string | null
}): boolean {
  return isPromoteBackfillRun(run) || isStalkerNoteBackfillRun(run)
}

export function scrapeSourceLabel(source?: string | null): string {
  if (source === PROMOTE_BACKFILL_SOURCE) return 'backfill'
  if (source === STALKER_NOTE_BACKFILL_SOURCE) return 'note backfill'
  const s = source?.trim()
  return s || '—'
}

export function scrapeRunFunnelLine(run: ScrapeRunRow): string {
  if (isPromoteBackfillRun(run)) {
    return `claimed ${run.l1_extract_count} · upserted ${run.candidates_upserted} · already ${run.alive_count} · skipped ${run.unparsed_count ?? 0}`
  }
  if (isStalkerNoteBackfillRun(run)) {
    return `deep ${run.deep_ref_count} · paste ${run.l2_fetch_ok}/${run.l2_fetch_fail} · junctions ${run.l2_extract_count} · portals ${run.candidates_upserted}`
  }
  return `new ${run.posts_seen} · portals ${run.l1_extract_count} · deep ${run.deep_ref_count} · L2 ${run.l2_fetch_ok}/${run.l2_fetch_fail} · unparsed ${run.unparsed_count ?? 0} · upserted ${run.candidates_upserted}`
}

export function scrapeRunMetricChips(
  run: ScrapeRunRow,
): { label: string; value: string | number }[] {
  if (isPromoteBackfillRun(run)) {
    return [
      { label: 'Claimed', value: run.l1_extract_count },
      { label: 'Promoted', value: run.candidates_upserted },
      { label: 'Already in DB', value: run.alive_count },
      { label: 'Skipped', value: run.unparsed_count ?? 0 },
    ]
  }
  if (isStalkerNoteBackfillRun(run)) {
    return [
      { label: 'Deep refs', value: run.deep_ref_count },
      { label: 'Paste ok', value: run.l2_fetch_ok },
      { label: 'Paste fail', value: run.l2_fetch_fail },
      { label: 'Junctions', value: run.l2_extract_count },
      { label: 'Portals', value: run.candidates_upserted },
    ]
  }
  return [
    { label: 'New posts', value: run.posts_seen },
    { label: 'Portals', value: run.l1_extract_count },
    { label: 'Deep', value: run.deep_ref_count },
    { label: 'L2 ok', value: run.l2_fetch_ok },
    { label: 'L2 fail', value: run.l2_fetch_fail },
    { label: 'L2 portals', value: run.l2_extract_count },
    { label: 'Unparsed', value: run.unparsed_count ?? 0 },
    { label: 'Upserted', value: run.candidates_upserted },
    { label: 'Alive', value: run.alive_count },
  ]
}

export function emptyScrapeRun(
  partial: Pick<ScrapeRunRow, 'id' | 'started_at' | 'status' | 'source'>,
): ScrapeRunRow {
  return {
    id: partial.id,
    started_at: partial.started_at,
    finished_at: null,
    status: partial.status || 'running',
    source: partial.source ?? 'manual-admin',
    posts_seen: 0,
    l1_extract_count: 0,
    deep_ref_count: 0,
    l2_fetch_ok: 0,
    l2_fetch_fail: 0,
    l2_extract_count: 0,
    unparsed_count: 0,
    candidates_upserted: 0,
    alive_count: 0,
    error: null,
  }
}

export function runDurationMs(run: ScrapeRunRow): number | null {
  const start = Date.parse(run.started_at)
  if (Number.isNaN(start)) return null
  const end = run.finished_at
    ? Date.parse(run.finished_at)
    : run.status === 'running'
      ? Date.now()
      : start
  if (Number.isNaN(end)) return null
  return Math.max(0, end - start)
}

export async function fetchScrapeRuns(limit?: number): Promise<ScrapeRunRow[]> {
  const mapRow = (r: ScrapeRunRow): ScrapeRunRow => ({
    ...emptyScrapeRun(r),
    ...r,
    deep_ref_count: r.deep_ref_count ?? 0,
    l2_fetch_ok: r.l2_fetch_ok ?? 0,
    l2_fetch_fail: r.l2_fetch_fail ?? 0,
    l2_extract_count: r.l2_extract_count ?? 0,
    unparsed_count: r.unparsed_count ?? 0,
  })

  if (limit != null) {
    const { data, error } = await adminDb
      .from('iptv_scrape_runs')
      .select(SCRAPE_RUN_SELECT)
      .order('started_at', { ascending: false })
      .limit(limit)
    if (error) throw error
    return ((data ?? []) as ScrapeRunRow[]).map(mapRow)
  }

  const rows = await fetchAllRows(async (from, to) => {
    const { data, error } = await adminDb
      .from('iptv_scrape_runs')
      .select(SCRAPE_RUN_SELECT)
      .order('started_at', { ascending: false })
      .range(from, to)
    if (error) throw error
    return (data ?? []) as ScrapeRunRow[]
  })
  return rows.map(mapRow)
}

/** Invalidate + hard refetch every scrape_runs query (list + latest). */
export async function refreshScrapeRuns(qc: QueryClient) {
  await qc.invalidateQueries({ queryKey: ['admin', 'scrape_runs'] })
  await qc.invalidateQueries({ queryKey: ['admin', 'ops_overview'] })
  await qc.refetchQueries({ queryKey: ['admin', 'scrape_runs'] })
  await qc.refetchQueries({ queryKey: ['admin', 'ops_overview'] })
}

export function prependOptimisticRun(
  qc: QueryClient,
  run: Pick<ScrapeRunRow, 'id' | 'started_at' | 'status' | 'source'>,
) {
  const row = emptyScrapeRun(run)
  const patch = (old: ScrapeRunRow[] | undefined) => {
    const rest = (old ?? []).filter((r) => r.id !== row.id)
    return [row, ...rest]
  }
  qc.setQueryData<ScrapeRunRow[]>(SCRAPE_RUNS_KEY, patch)
  qc.setQueryData<ScrapeRunRow[]>(SCRAPE_RUNS_LATEST_KEY, (old) =>
    patch(old).slice(0, 5),
  )
}

export function markRunsStoppedInCache(
  qc: QueryClient,
  opts: { runId?: string; error: string },
) {
  const finished = new Date().toISOString()
  const patch = (old: ScrapeRunRow[] | undefined) =>
    (old ?? []).map((r) => {
      if (r.status !== 'running') return r
      if (opts.runId && r.id !== opts.runId) return r
      return {
        ...r,
        status: 'error',
        finished_at: finished,
        error: opts.error,
      }
    })
  qc.setQueryData<ScrapeRunRow[]>(SCRAPE_RUNS_KEY, patch)
  qc.setQueryData<ScrapeRunRow[]>(SCRAPE_RUNS_LATEST_KEY, patch)
}

/**
 * Shared realtime subscription for scrape runs.
 * OpsOverviewStrip + Scrape page both call this — must be one channel.
 * Date.now() topic names collided in the same tick (second .on after subscribe).
 */
const scrapeRunListeners = new Set<() => void>()
let scrapeRunsChannel: ReturnType<typeof supabase.channel> | null = null

export function subscribeScrapeRuns(onChange: () => void): () => void {
  scrapeRunListeners.add(onChange)

  if (!scrapeRunsChannel) {
    // Drop any leftover same-topic channels (HMR / Strict Mode).
    for (const ch of supabase.getChannels()) {
      if (ch.topic.includes('iptv_scrape_runs')) {
        void supabase.removeChannel(ch)
      }
    }
    scrapeRunsChannel = supabase
      .channel(`iptv_scrape_runs_${crypto.randomUUID()}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'iptv_scrape_runs' },
        () => {
          for (const fn of scrapeRunListeners) fn()
        },
      )
      .subscribe()
  }

  return () => {
    scrapeRunListeners.delete(onChange)
    if (scrapeRunListeners.size === 0 && scrapeRunsChannel) {
      void supabase.removeChannel(scrapeRunsChannel)
      scrapeRunsChannel = null
    }
  }
}
