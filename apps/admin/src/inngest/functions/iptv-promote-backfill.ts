import { inngest } from '@/inngest/client'
import {
  claimEligibleUnpromotedPortalIds,
  createCatalogAdminClient,
  getDeepRefPortalsForPromote,
  promoteDeepRefPortalRow,
} from '@/server/iptv-catalog/supabase-admin'

/** Match scrape Phase 3 — timeout safety only. */
const DEFAULT_CHUNK = 25
const MIN_CHUNK = 10
const MAX_CHUNK = 50
const MAX_LIMIT = 20_000
const MAX_BATCHES = 4000

type BackfillData = {
  jobId?: string
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

/**
 * Ops recovery: promote stranded deep_ref_portals (portal_id null + canPromoteHit)
 * into iptv_portals. Claim-next from DB each step — never memoize id lists.
 */
export const iptvPromoteBackfill = inngest.createFunction(
  {
    id: 'iptv-promote-backfill',
    concurrency: { limit: 1 },
    retries: 1,
    checkpointing: false,
    triggers: [{ event: 'iptv/catalog.promote-backfill' }],
    cancelOn: [{ event: 'iptv/catalog.promote-backfill.cancel' }],
  },
  async ({ event, step }) => {
    const data = (event.data ?? {}) as BackfillData
    const jobId = String(data.jobId ?? crypto.randomUUID())
    const limit = clampLimit(data.limit)
    const chunkSize = clampChunk(data.chunkSize)

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

      if (n.fetched === 0 || n.done) break

      await step.sleep(`yield-promote-backfill-${i}`, '0s')
    }

    return {
      jobId,
      limit,
      chunkSize,
      fetched,
      promoted,
      wasExisting,
      skipped,
    }
  },
)
