import type { QueryClient } from '@tanstack/react-query'
import { adminDb } from '@/lib/admin-db'
import { supabase } from '@/lib/supabase'

export const SCRAPE_RUNS_KEY = ['admin', 'scrape_runs'] as const
export const SCRAPE_RUNS_LATEST_KEY = ['admin', 'scrape_runs', 'latest'] as const

export const SCRAPE_RUN_SELECT =
  'id, started_at, finished_at, status, source, posts_seen, l1_extract_count, deep_ref_count, l2_fetch_ok, l2_fetch_fail, l2_extract_count, candidates_upserted, alive_count, error'

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
  candidates_upserted: number
  alive_count: number
  error?: string | null
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

export async function fetchScrapeRuns(limit = 50): Promise<ScrapeRunRow[]> {
  const { data, error } = await adminDb
    .from('iptv_scrape_runs')
    .select(SCRAPE_RUN_SELECT)
    .order('started_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return ((data ?? []) as ScrapeRunRow[]).map((r) => ({
    ...emptyScrapeRun(r),
    ...r,
    deep_ref_count: r.deep_ref_count ?? 0,
    l2_fetch_ok: r.l2_fetch_ok ?? 0,
    l2_fetch_fail: r.l2_fetch_fail ?? 0,
    l2_extract_count: r.l2_extract_count ?? 0,
  }))
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

/** Live updates while a scrape is running (realtime + fast poll). */
export function subscribeScrapeRuns(onChange: () => void): () => void {
  const channel = supabase
    .channel(`iptv_scrape_runs_${Date.now()}`)
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'iptv_scrape_runs' },
      () => onChange(),
    )
    .subscribe()
  return () => {
    void supabase.removeChannel(channel)
  }
}
