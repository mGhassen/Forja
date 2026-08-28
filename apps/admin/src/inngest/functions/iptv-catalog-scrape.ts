import { inngest } from '@/inngest/client'
import { classifyRegion } from '@/server/iptv-catalog/region'
import {
  advanceCatalogListing,
  processDeepRefRow,
  scrapeCatalogPage,
} from '@/server/iptv-catalog/reddit'
import { cronIsDueUtc, isValidScrapeCron } from '@/lib/scrape-cron'
import {
  createCatalogAdminClient,
  getDeepRefPortalsForPromote,
  getDeepRefRowById,
  getLastScheduledScrapeStartedAt,
  getNextPendingDeepRefId,
  getScrapeCronSettings,
  insertScrapeDeepRefPortalsBulk,
  insertScrapeRun,
  listDeepRefPortalIdsPage,
  patchScrapeRun,
  promoteDeepRefPortalRow,
  upsertCatalogCandidate,
  upsertScrapeDeepRef,
  upsertScrapePostId,
} from '@/server/iptv-catalog/supabase-admin'
import type { PortalStatus } from '@/server/iptv-catalog/types'
import { verifyPortalStatus } from '@/server/iptv-catalog/verify'

/**
 * player_api probes are slow (N Inngest steps). Off for now — still upserts
 * candidates with alive=null. Flip to true to restore verify-portal-status-*.
 * Verify is separate from scrape upsert volume (no upsert cap).
 */
const VERIFY_PORTAL_STATUS = false

/** Chunk size for Inngest upsert steps (timeout safety only — not a product cap). */
const UPSERT_CHUNK = 25

/** Hard caps so a runaway loop can't mint unbounded step names. */
const MAX_PROCESS_STEPS = 2000
const MAX_PROMOTE_BATCHES = 4000

type ScrapeData = {
  jobId?: string
  /** Pre-created by admin API so UI shows running immediately. */
  runId?: string
  maxPages?: number
  /** 1-indexed Reddit /new page to start at (after skipping startPage-1). */
  startPage?: number
  /** 1-indexed inclusive end page. */
  endPage?: number
  maxResultsPerPage?: number
  /** Only when VERIFY_PORTAL_STATUS — how many to probe, not upsert limit. */
  maxVerify?: number
  /** Ignore known post_ids (one-time deep_refs backfill). Default false. */
  forceFull?: boolean
}

async function markRun(runId: string, error?: string) {
  const sb = createCatalogAdminClient()
  await patchScrapeRun(sb, runId, {
    status: 'error',
    finished_at: new Date().toISOString(),
    error: error ?? null,
  })
}

/**
 * Scheduled + on-demand catalog scrape.
 * Phase 1: walk Reddit /new → posts + deep_ref stubs in DB (L1 upserted in-step).
 * Phase 2: claim-next pending deep_refs (paste + extract + bulk junction insert).
 * Phase 3: promote junction rows from DB pages (never memoize id lists).
 *
 * Serve uses streaming:false (Nitro/Node). Never return portal arrays /
 * pending-id / portal-id lists through step.run — those truncated the serve
 * body → Inngest "unexpected end of JSON input".
 */
export const iptvCatalogScrape = inngest.createFunction(
  {
    id: 'iptv-catalog-scrape',
    concurrency: { limit: 1 },
    retries: 1,
    // Classic one-step-per-invoke — matches step.sleep('0s') yields.
    checkpointing: false,
    triggers: [
      { cron: '0 6 * * *' },
      { cron: '* * * * *' },
      { event: 'iptv/catalog.scrape' },
    ],
    cancelOn: [{ event: 'iptv/catalog.scrape.cancel' }],
    onFailure: async ({ error }) => {
      try {
        const sb = createCatalogAdminClient()
        const { data: rows } = await sb
          .from('iptv_scrape_runs')
          .select('id')
          .eq('status', 'running')
          .order('started_at', { ascending: false })
          .limit(1)
        const id = rows?.[0]?.id
        if (id) await markRun(id, error.message)
      } catch {
        // ignore
      }
    },
  },
  async ({ event, step }) => {
    const data = (event?.data ?? {}) as ScrapeData
    const jobId = data.jobId ?? event.id
    const eventName = String(event?.name ?? '')
    const isCron =
      eventName === 'inngest/scheduled.timer' ||
      eventName.startsWith('inngest/scheduled')
    const forceFull = Boolean(data.forceFull)

    if (isCron) {
      const gate = await step.run('check-cron-schedule', async () => {
        const sb = createCatalogAdminClient()
        const settings = await getScrapeCronSettings(sb)
        if (!settings.enabled) {
          return { run: false as const, reason: 'scrape_cron_enabled=false' }
        }
        if (!isValidScrapeCron(settings.cron)) {
          return {
            run: false as const,
            reason: `invalid scrape_cron=${settings.cron}`,
          }
        }
        const ts = typeof event?.ts === 'number' ? event.ts : Date.now()
        const now = new Date(ts)
        const last = await getLastScheduledScrapeStartedAt(sb)
        if (!cronIsDueUtc(settings.cron, now, last)) {
          return {
            run: false as const,
            reason: `not_due cron=${settings.cron}`,
          }
        }
        return { run: true as const, cron: settings.cron }
      })
      if (!gate.run) {
        return { skipped: true, reason: gate.reason, jobId }
      }
    }

    const startPage = Math.min(
      200,
      Math.max(1, Math.floor(data.startPage ?? 1)),
    )
    let endPage = Math.min(
      200,
      Math.max(
        1,
        Math.floor(
          data.endPage ??
            startPage + Math.min(Math.max(data.maxPages ?? 10, 1), 200) - 1,
        ),
      ),
    )
    if (endPage < startPage) endPage = startPage
    const maxPages = endPage - startPage + 1
    const skipPages = startPage - 1
    const maxResultsPerPage = Math.min(
      Math.max(data.maxResultsPerPage ?? 500, 1),
      2000,
    )
    const maxVerify = Math.min(Math.max(data.maxVerify ?? 200, 1), 500)

    const runId = await step.run('create-scrape-run', async () => {
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
      return insertScrapeRun(sb, isCron ? 'inngest-cron' : 'inngest-admin')
    })

    let after: string | null = null
    let postsSeen = 0
    let deepRefCount = 0
    let l2FetchOk = 0
    let l2FetchFail = 0
    let l2ExtractCount = 0
    let unparsedCount = 0
    let l1OnlyCount = 0
    let l1Upserted = 0
    let hitWatermark = false

    for (let s = 0; s < skipPages; s++) {
      const pageAfter: string | null = after
      const skipped: { nextAfter: string | null; subreddit: string } =
        await step.run(`skip-reddit-page-${s}`, async () => {
          return advanceCatalogListing(pageAfter)
        })
      after = skipped.nextAfter
      if (!after) break
    }

    // Phase 1 — COLLECT: Reddit → posts + deep_ref stubs; L1 upserted in-step.
    // Step return is slim (counts + cursor) — never portal arrays / known-id sets.
    for (let page = 0; page < maxPages; page++) {
      const pageAfter = after
      const result = await step.run(`collect-reddit-page-${page}`, async () => {
        const sb = createCatalogAdminClient()
        const knownChecker = forceFull
          ? async () => false
          : async (postId: string) => {
              const { data: row, error } = await sb
                .from('iptv_scrape_posts')
                .select('post_id')
                .eq('post_id', postId)
                .maybeSingle()
              if (error) throw error
              return Boolean(row?.post_id)
            }

        const pageResult = await scrapeCatalogPage(
          pageAfter,
          maxResultsPerPage,
          knownChecker,
        )

        for (const postId of pageResult.postIds) {
          await upsertScrapePostId(
            sb,
            postId,
            runId,
            pageResult.subreddit || 'IPTV_ZONENEW',
          )
        }
        for (const ref of pageResult.deepRefs) {
          await upsertScrapeDeepRef(sb, ref, runId, { linkPortals: false })
        }

        let upserted = 0
        for (const portal of pageResult.portals) {
          const status: PortalStatus = {
            alive: null,
            status: 'unverified',
            expiry: portal.expiry ?? null,
            maxConnections: portal.maxConnections ?? null,
            timezone: portal.timezone ?? null,
            categoryNames: [],
          }
          const region = {
            primary: portal.regionPrimary ?? 'UNKNOWN',
            tags: portal.regionTags ?? [],
            confidence: portal.regionConfidence ?? 0,
          }
          await upsertCatalogCandidate(sb, portal, status, region)
          upserted++
        }

        return {
          nextAfter: pageResult.nextAfter,
          postsSeen: pageResult.postsSeen,
          hitWatermark: pageResult.hitWatermark,
          funnel: pageResult.funnel,
          l1Upserted: upserted,
        }
      })

      postsSeen += result.postsSeen
      deepRefCount += result.funnel?.deepRefCount ?? 0
      unparsedCount += result.funnel?.unparsedCount ?? 0
      l1OnlyCount += result.funnel?.l1OnlyCount ?? 0
      l1Upserted += result.l1Upserted

      await step.run(`checkpoint-collect-${page}`, async () => {
        const sb = createCatalogAdminClient()
        await patchScrapeRun(sb, runId, {
          posts_seen: postsSeen,
          l1_extract_count: l1Upserted,
          deep_ref_count: deepRefCount,
          unparsed_count: unparsedCount,
          candidates_upserted: l1Upserted,
        })
      })
      await step.sleep(`yield-collect-${page}`, '0s')

      after = result.nextAfter
      if (result.hitWatermark) {
        hitWatermark = true
        break
      }
      if (!after) break
    }

    await step.run('checkpoint-collect-done', async () => {
      const sb = createCatalogAdminClient()
      await patchScrapeRun(sb, runId, {
        posts_seen: postsSeen,
        l1_extract_count: l1Upserted,
        deep_ref_count: deepRefCount,
        unparsed_count: unparsedCount,
        candidates_upserted: l1Upserted,
      })
    })

    // Phase 2 — PROCESS: claim-next pending ref each step (no id list in memo).
    unparsedCount = 0
    let processedRefs = 0
    for (let i = 0; i < MAX_PROCESS_STEPS; i++) {
      const outcome = await step.run(`process-deep-ref-${i}`, async () => {
        const sb = createCatalogAdminClient()
        const deepRefRowId = await getNextPendingDeepRefId(sb, runId)
        if (!deepRefRowId) {
          return {
            done: true as const,
            l2FetchOk: 0,
            l2FetchFail: 0,
            l2ExtractCount: 0,
            hitCount: 0,
            needsRecheck: false,
          }
        }
        const row = await getDeepRefRowById(sb, deepRefRowId)
        if (!row) {
          // Stale claim — clear pending so the next step advances.
          await sb
            .from('iptv_scrape_deep_refs')
            .update({ fetch_ok: false, needs_recheck: true })
            .eq('id', deepRefRowId)
          return {
            done: false as const,
            l2FetchOk: 0,
            l2FetchFail: 0,
            l2ExtractCount: 0,
            hitCount: 0,
            needsRecheck: true,
          }
        }
        const processed = await processDeepRefRow(row, maxResultsPerPage)
        const deepRefId = await upsertScrapeDeepRef(
          sb,
          processed.ref,
          runId,
          { linkPortals: false },
        )
        const hitCount = await insertScrapeDeepRefPortalsBulk(
          sb,
          deepRefId,
          processed.ref.portals,
        )
        return {
          done: false as const,
          l2FetchOk: processed.l2FetchOk,
          l2FetchFail: processed.l2FetchFail,
          l2ExtractCount: processed.l2ExtractCount,
          hitCount,
          needsRecheck: processed.ref.needsRecheck,
        }
      })
      if (outcome.done) break
      processedRefs++
      l2FetchOk += outcome.l2FetchOk
      l2FetchFail += outcome.l2FetchFail
      l2ExtractCount += outcome.l2ExtractCount
      if (outcome.needsRecheck) unparsedCount++

      if (i % 5 === 0) {
        await step.run(`checkpoint-process-${i}`, async () => {
          const sb = createCatalogAdminClient()
          await patchScrapeRun(sb, runId, {
            posts_seen: postsSeen,
            l1_extract_count: l1Upserted,
            deep_ref_count: deepRefCount,
            l2_fetch_ok: l2FetchOk,
            l2_fetch_fail: l2FetchFail,
            l2_extract_count: l2ExtractCount,
            unparsed_count: unparsedCount,
            candidates_upserted: l1Upserted,
          })
        })
      }
      await step.sleep(`yield-process-${i}`, '0s')
    }

    await step.run('checkpoint-after-process', async () => {
      const sb = createCatalogAdminClient()
      await patchScrapeRun(sb, runId, {
        posts_seen: postsSeen,
        l1_extract_count: l1Upserted,
        deep_ref_count: deepRefCount,
        l2_fetch_ok: l2FetchOk,
        l2_fetch_fail: l2FetchFail,
        l2_extract_count: l2ExtractCount,
        unparsed_count: unparsedCount,
        candidates_upserted: l1Upserted,
      })
    })

    // Phase 3 — PROMOTE: page junction ids from DB each step (never memoize lists).
    let aliveCount = 0
    let upserted = l1Upserted
    let deadCount = 0
    let verified = 0
    let portalRows = 0
    let promoteOffset = 0
    const promoteCap = VERIFY_PORTAL_STATUS
      ? Math.min(maxVerify, MAX_PROMOTE_BATCHES * UPSERT_CHUNK)
      : MAX_PROMOTE_BATCHES * UPSERT_CHUNK

    for (let i = 0; i < MAX_PROMOTE_BATCHES; i++) {
      if (promoteOffset >= promoteCap) break
      const pageOffset = promoteOffset
      const n = await step.run(
        VERIFY_PORTAL_STATUS ? `verify-promote-${i}` : `upsert-candidates-${i}`,
        async () => {
          const sb = createCatalogAdminClient()
          const chunkIds = await listDeepRefPortalIdsPage(
            sb,
            runId,
            pageOffset,
            UPSERT_CHUNK,
          )
          if (chunkIds.length === 0) {
            return { count: 0, alive: 0, dead: 0, fetched: 0, done: true }
          }
          const rows = await getDeepRefPortalsForPromote(sb, chunkIds)
          let count = 0
          let alive = 0
          let dead = 0
          for (const row of rows) {
            const promoted = await promoteDeepRefPortalRow(sb, row)
            if (!promoted.upserted) continue
            count++
            if (!VERIFY_PORTAL_STATUS) continue
            const portal = {
              url: row.url,
              username: row.username,
              password: row.password || '',
              source: row.paste_url ? 'catalog-deep' : 'catalog-decoded',
              platform: row.platform,
            }
            const status = await verifyPortalStatus(portal)
            const region = classifyRegion(status.timezone, status.categoryNames)
            await upsertCatalogCandidate(sb, portal, status, region)
            if (status.alive) alive++
            else dead++
          }
          return {
            count,
            alive,
            dead,
            fetched: chunkIds.length,
            done: chunkIds.length < UPSERT_CHUNK,
          }
        },
      )
      if (n.fetched === 0) break
      portalRows += n.fetched
      upserted += n.count
      if (VERIFY_PORTAL_STATUS) {
        verified += n.count
        aliveCount += n.alive
        deadCount += n.dead
      }
      promoteOffset += n.fetched

      await step.run(`progress-upsert-${i}`, async () => {
        const sb = createCatalogAdminClient()
        await patchScrapeRun(sb, runId, {
          candidates_upserted: upserted,
          posts_seen: postsSeen,
          l1_extract_count: l1Upserted,
          deep_ref_count: deepRefCount,
          l2_fetch_ok: l2FetchOk,
          l2_fetch_fail: l2FetchFail,
          l2_extract_count: l2ExtractCount,
          unparsed_count: unparsedCount,
        })
      })
      await step.sleep(
        VERIFY_PORTAL_STATUS ? `yield-verify-${i}` : `yield-upsert-${i}`,
        '0s',
      )
      if (n.done) break
    }

    await step.run('finalize-scrape-run', async () => {
      const sb = createCatalogAdminClient()
      await patchScrapeRun(sb, runId, {
        status: 'ok',
        finished_at: new Date().toISOString(),
        posts_seen: postsSeen,
        l1_extract_count: l1Upserted,
        deep_ref_count: deepRefCount,
        l2_fetch_ok: l2FetchOk,
        l2_fetch_fail: l2FetchFail,
        l2_extract_count: l2ExtractCount,
        unparsed_count: unparsedCount,
        candidates_upserted: upserted,
        alive_count: aliveCount,
        error: null,
      })
    })

    return {
      jobId,
      runId,
      scrapedUnique: upserted,
      l1OnlyCount,
      l1Upserted,
      verified,
      verifyEnabled: VERIFY_PORTAL_STATUS,
      upserted,
      aliveCount,
      deadCount,
      deepRefCount,
      l2FetchOk,
      l2FetchFail,
      l2ExtractCount,
      unparsedCount,
      postsSeen,
      hitWatermark,
      processedRefs,
      portalRows,
    }
  },
)

/** When Inngest cancels scrape or backfill, close the matching DB run. */
export const iptvCatalogScrapeCancelled = inngest.createFunction(
  {
    id: 'iptv-catalog-scrape-cancelled',
    triggers: [{ event: 'inngest/function.cancelled' }],
  },
  async ({ event, step }) => {
    const fnId = String(
      (event.data as { function_id?: string })?.function_id ?? '',
    )
    const isBackfill =
      fnId.includes('iptv-promote-backfill') && !fnId.includes('cancelled')
    const isScrape =
      fnId.includes('iptv-catalog-scrape') && !fnId.includes('cancelled')
    if (!isBackfill && !isScrape) {
      return { skipped: true }
    }
    await step.run('mark-db-cancelled', async () => {
      const sb = createCatalogAdminClient()
      const { data: rows } = await sb
        .from('iptv_scrape_runs')
        .select('id, source')
        .eq('status', 'running')
        .order('started_at', { ascending: false })
        .limit(8)
      for (const row of rows ?? []) {
        const source = String(row.source ?? '')
        const backfillRow = source === 'promote-backfill'
        if (isBackfill !== backfillRow) continue
        await patchScrapeRun(sb, row.id as string, {
          status: 'error',
          finished_at: new Date().toISOString(),
          error: 'Cancelled (Inngest)',
        })
      }
    })
    return { ok: true }
  },
)
