import type { QueryClient } from '@tanstack/react-query'
import { adminDb } from '@/lib/admin-db'
import { supabase } from '@/lib/supabase'

export const SCRAPE_RUNS_KEY = ['admin', 'scrape_runs'] as const
export const SCRAPE_RUNS_LATEST_KEY = ['admin', 'scrape_runs', 'latest'] as const

export type ScrapeRunRow = {
  id: string
  started_at: string
  finished_at: string | null
  status: string
  posts_seen: number
  l1_extract_count: number
  candidates_upserted: number
  alive_count: number
  source?: string | null
  error?: string | null
}

export async function fetchScrapeRuns(limit = 50): Promise<ScrapeRunRow[]> {
  const { data, error } = await adminDb
    .from('iptv_scrape_runs')
    .select(
      'id, started_at, finished_at, status, posts_seen, l1_extract_count, candidates_upserted, alive_count, source, error',
    )
    .order('started_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as ScrapeRunRow[]
}

/** Invalidate + hard refetch every scrape_runs query (list + latest). */
export async function refreshScrapeRuns(qc: QueryClient) {
  await qc.invalidateQueries({ queryKey: ['admin', 'scrape_runs'] })
  await qc.refetchQueries({ queryKey: ['admin', 'scrape_runs'] })
}

export function prependOptimisticRun(
  qc: QueryClient,
  run: Pick<ScrapeRunRow, 'id' | 'started_at' | 'status' | 'source'>,
) {
  const row: ScrapeRunRow = {
    id: run.id,
    started_at: run.started_at,
    finished_at: null,
    status: run.status || 'running',
    posts_seen: 0,
    l1_extract_count: 0,
    candidates_upserted: 0,
    alive_count: 0,
    source: run.source ?? 'manual-admin',
    error: null,
  }
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
