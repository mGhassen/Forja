import { inngest } from '@/inngest/client'
import {
  claimEligibleUnpromotedPortalIds,
  createCatalogAdminClient,
  getDeepRefPortalsForPromote,
  insertScrapeRun,
  patchScrapeRun,
  promoteDeepRefPortalRow,
} from '@/server/iptv-catalog/supabase-admin'

/** Match scrape Phase 3 — timeout safety only. */
const DEFAULT_CHUNK = 25
const MIN_CHUNK = 10
const MAX_CHUNK = 50
const MAX_LIMIT = 20_000
const MAX_BATCHES = 4000

export const PROMOTE_BACKFILL_SOURCE = 'promote-backfill'

type BackfillData = {
  jobId?: string
  runId?: string
  /** Cap how many eligible rows to promote this run. */
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

async function markBackfillRun(runId: string, error?: string) {
  const sb = createCatalogAdminClient()
  await patchScrapeRun(sb, runId, {
    status: 'error',
    finished_at: new Date().toISOString(),
    error: error ?? null,
  })
}

/**
 * Ops recovery: promote stranded deep_ref_portals (portal_id null + canPromoteHit)
 * into iptv_portals. Own Inngest function — not scrape.
 */
export const iptvPromoteBackfill = inngest.createFunction(
  {
    id: 'iptv-promote-backfill',
    concurrency: { limit: 1 },
    retries: 1,
    checkpointing: false,
    triggers: [{ event: 'iptv/catalog.promote-backfill' }],
    cancelOn: [{ event: 'iptv/catalog.promote-backfill.cancel' }],
    onFailure: async ({ error }) => {
      try {
        const sb = createCatalogAdminClient()
        const { data: rows } = await sb
          .from('iptv_scrape_runs')
          .select('id')
          .eq('status', 'running')
          .eq('source', PROMOTE_BACKFILL_SOURCE)
          .order('started_at', { ascending: false })
          .limit(1)
        const id = rows?.[0]?.id
        if (id) await markBackfillRun(id, error.message)
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

    const runId = await step.run('create-backfill-run', async () => {
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
      return insertScrapeRun(sb, PROMOTE_BACKFILL_SOURCE)
    })

    let promoted = 0
    let wasExisting = 0
    let skipped = 0
    let fetched = 0
    const maxBatches = Math.min(
      MAX_BATCHES,
      Math.ceil(limit / chunkSize) + 1,
    )

    for (let i = 0; i < maxBatches; i++) {
      if (fetched >= limit) break

      const remaining = limit - fetched
      const take = Math.min(chunkSize, remaining)

      const n = await step.run(`promote-backfill-${i}`, async () => {
        const sb = createCatalogAdminClient()
        const chunkIds = await claimEligibleUnpromotedPortalIds(sb, take)
        if (chunkIds.length === 0) {
          return {
            fetched: 0,
            promoted: 0,
            wasExisting: 0,
            skipped: 0,
            done: true,
          }
        }
        const rows = await getDeepRefPortalsForPromote(sb, chunkIds)
        let p = 0
        let existing = 0
        let skip = 0
        for (const row of rows) {
          const outcome = await promoteDeepRefPortalRow(sb, row)
          if (!outcome.upserted) {
            skip++
            continue
          }
          p++
          if (outcome.wasExisting) existing++
        }
        return {
          fetched: chunkIds.length,
          promoted: p,
          wasExisting: existing,
          skipped: skip,
          done: chunkIds.length < take,
        }
      })

      fetched += n.fetched
      promoted += n.promoted
      wasExisting += n.wasExisting
      skipped += n.skipped

      await step.run(`progress-promote-backfill-${i}`, async () => {
        const sb = createCatalogAdminClient()
        await patchScrapeRun(sb, runId, {
          l1_extract_count: fetched,
          candidates_upserted: promoted,
          alive_count: wasExisting,
          unparsed_count: skipped,
        })
      })

      if (n.fetched === 0 || n.done) break

      await step.sleep(`yield-promote-backfill-${i}`, '0s')
    }

    await step.run('finalize-backfill-run', async () => {
      const sb = createCatalogAdminClient()
      await patchScrapeRun(sb, runId, {
        status: 'ok',
        finished_at: new Date().toISOString(),
        l1_extract_count: fetched,
        candidates_upserted: promoted,
        alive_count: wasExisting,
        unparsed_count: skipped,
        error: null,
      })
    })

    return {
      jobId,
      runId,
      limit,
      chunkSize,
      fetched,
      promoted,
      wasExisting,
      skipped,
    }
  },
)
