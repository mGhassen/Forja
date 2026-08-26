import { inngest } from '@/inngest/client'
import {
  createCatalogAdminClient,
  insertScrapeRun,
  patchScrapeRun,
} from '@/server/iptv-catalog/supabase-admin'
import {
  claimStalkerNoteDeepRefIds,
  processStalkerNoteDeepRefChunk,
} from '@/server/iptv-catalog/stalker-note-backfill'

const DEFAULT_CHUNK = 15
const MIN_CHUNK = 5
const MAX_CHUNK = 40
const MAX_LIMIT = 20_000
const MAX_BATCHES = 4000

export const STALKER_NOTE_BACKFILL_SOURCE = 'stalker-note-backfill'

type BackfillData = {
  jobId?: string
  runId?: string
  limit?: number
  chunkSize?: number
}

function clampChunk(n: number | undefined): number {
  const v = Math.floor(n ?? DEFAULT_CHUNK)
  if (!Number.isFinite(v)) return DEFAULT_CHUNK
  return Math.min(MAX_CHUNK, Math.max(MIN_CHUNK, v))
}

function clampLimit(n: number | undefined): number {
  const v = Math.floor(n ?? MAX_LIMIT)
  if (!Number.isFinite(v) || v < 1) return MAX_LIMIT
  return Math.min(MAX_LIMIT, v)
}

async function markRunError(runId: string, error?: string) {
  const sb = createCatalogAdminClient()
  await patchScrapeRun(sb, runId, {
    status: 'error',
    finished_at: new Date().toISOString(),
    error: error ?? null,
  })
}

/**
 * Deep refs recovery: re-fetch paste → fill Stalker scrape expires into
 * note + expiry on junction / pool rows. Own Inngest function.
 */
export const iptvStalkerNoteBackfill = inngest.createFunction(
  {
    id: 'iptv-stalker-note-backfill',
    concurrency: { limit: 1 },
    retries: 1,
    checkpointing: false,
    triggers: [{ event: 'iptv/catalog.stalker-note-backfill' }],
    cancelOn: [{ event: 'iptv/catalog.stalker-note-backfill.cancel' }],
    onFailure: async ({ error }) => {
      try {
        const sb = createCatalogAdminClient()
        const { data: rows } = await sb
          .from('iptv_scrape_runs')
          .select('id')
          .eq('status', 'running')
          .eq('source', STALKER_NOTE_BACKFILL_SOURCE)
          .order('started_at', { ascending: false })
          .limit(1)
        const id = rows?.[0]?.id
        if (id) await markRunError(id, error.message)
      } catch {
        // ignore
      }
    },
  },
  async ({ event, step }) => {
    const data = (event.data ?? {}) as BackfillData
    const jobId = String(data.jobId ?? crypto.randomUUID())
    const limit = clampLimit(data.limit)
    const chunkSize = clampChunk(data.chunkSize)

    const runId = await step.run('create-note-backfill-run', async () => {
      const sb = createCatalogAdminClient()
      const existing = data.runId?.trim()
      if (existing) {
        const { data: row } = await sb
          .from('iptv_scrape_runs')
          .select('id')
          .eq('id', existing)
          .maybeSingle()
        if (row?.id) return row.id as string
      }
      return insertScrapeRun(sb, STALKER_NOTE_BACKFILL_SOURCE)
    })

    let deepRefs = 0
    let fetchOk = 0
    let fetchFailed = 0
    let junctionsPatched = 0
    let portalsPatched = 0
    const tried: string[] = []
    const maxBatches = Math.min(
      MAX_BATCHES,
      Math.ceil(limit / chunkSize) + 1,
    )

    for (let i = 0; i < maxBatches; i++) {
      if (deepRefs >= limit) break
      const remaining = limit - deepRefs
      const take = Math.min(chunkSize, remaining)
      const excludeSnapshot = [...tried]

      const n = await step.run(`stalker-note-backfill-${i}`, async () => {
        const sb = createCatalogAdminClient()
        const ids = await claimStalkerNoteDeepRefIds(sb, take, excludeSnapshot)
        if (ids.length === 0) {
          return {
            deepRefs: 0,
            fetchOk: 0,
            fetchFailed: 0,
            junctionsPatched: 0,
            portalsPatched: 0,
            claimedIds: [] as string[],
            done: true,
          }
        }
        const result = await processStalkerNoteDeepRefChunk(sb, ids)
        return {
          ...result,
          done: ids.length < take,
        }
      })

      tried.push(...n.claimedIds)
      deepRefs += n.deepRefs
      fetchOk += n.fetchOk
      fetchFailed += n.fetchFailed
      junctionsPatched += n.junctionsPatched
      portalsPatched += n.portalsPatched

      await step.run(`progress-stalker-note-backfill-${i}`, async () => {
        const sb = createCatalogAdminClient()
        await patchScrapeRun(sb, runId, {
          deep_ref_count: deepRefs,
          l2_fetch_ok: fetchOk,
          l2_fetch_fail: fetchFailed,
          l2_extract_count: junctionsPatched,
          candidates_upserted: portalsPatched,
        })
      })

      if (n.deepRefs === 0 || n.done) break
      await step.sleep(`yield-stalker-note-backfill-${i}`, '0s')
    }

    await step.run('finalize-stalker-note-backfill', async () => {
      const sb = createCatalogAdminClient()
      await patchScrapeRun(sb, runId, {
        status: 'ok',
        finished_at: new Date().toISOString(),
        deep_ref_count: deepRefs,
        l2_fetch_ok: fetchOk,
        l2_fetch_fail: fetchFailed,
        l2_extract_count: junctionsPatched,
        candidates_upserted: portalsPatched,
        error: null,
      })
    })

    return {
      jobId,
      runId,
      limit,
      chunkSize,
      deepRefs,
      fetchOk,
      fetchFailed,
      junctionsPatched,
      portalsPatched,
    }
  },
)
