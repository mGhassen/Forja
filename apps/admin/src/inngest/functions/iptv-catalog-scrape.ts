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
  getScrapeCronSettings,
  insertScrapeDeepRefPortalsBulk,
  insertScrapeRun,
  listDeepRefPortalIdsForRun,
  listPendingDeepRefIdsForRun,
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
 * Phase 2: process pending deep_refs (paste + extract + bulk junction insert).
 * Phase 3: promote junction rows → catalog in small chunks (ids only in memo).
 *
 * Never return portal arrays / known-post sets through step.run — that blew
 * Inngest stream JSON ("unexpected end of JSON input") on Vercel.
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
      const pageAfter = after
      const skipped = await step.run(`skip-reddit-page-${s}`, async () => {
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

    // Phase 2 — PROCESS: paste + extract + bulk junction insert. Slim returns only.
    unparsedCount = 0
    const pendingIds = await step.run('list-pending-deep-refs', async () => {
      const sb = createCatalogAdminClient()
      return listPendingDeepRefIdsForRun(sb, runId)
    })

    for (let i = 0; i < pendingIds.length; i++) {
      const deepRefRowId = pendingIds[i]!
      const outcome = await step.run(`process-deep-ref-${i}`, async () => {
        const sb = createCatalogAdminClient()
        const row = await getDeepRefRowById(sb, deepRefRowId)
        if (!row) {
          return {
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
          l2FetchOk: processed.l2FetchOk,
          l2FetchFail: processed.l2FetchFail,
          l2ExtractCount: processed.l2ExtractCount,
          hitCount,
          needsRecheck: processed.ref.needsRecheck,
        }
      })
      l2FetchOk += outcome.l2FetchOk
      l2FetchFail += outcome.l2FetchFail
      l2ExtractCount += outcome.l2ExtractCount
      if (outcome.needsRecheck) unparsedCount++

      if (i % 5 === 0 || i === pendingIds.length - 1) {
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

    // Phase 3 — PROMOTE: junction row ids → catalog (chunked). Ids only in memo.
    let aliveCount = 0
    let upserted = l1Upserted
    let deadCount = 0
    let verified = 0

    const portalRowIds = await step.run('list-run-portal-ids', async () => {
      const sb = createCatalogAdminClient()
      return listDeepRefPortalIdsForRun(sb, runId)
    })

    if (VERIFY_PORTAL_STATUS) {
      // Legacy probe path — load + verify in small chunks (ids from memo).
      for (let i = 0; i < Math.min(portalRowIds.length, maxVerify); i += UPSERT_CHUNK) {
        const chunkIds = portalRowIds.slice(i, i + UPSERT_CHUNK)
        const n = await step.run(`verify-promote-${i}`, async () => {
          const sb = createCatalogAdminClient()
          const rows = await getDeepRefPortalsForPromote(sb, chunkIds)
          let count = 0
          let alive = 0
          let dead = 0
          for (const row of rows) {
            const promoted = await promoteDeepRefPortalRow(sb, row)
            if (!promoted.upserted) continue
            count++
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
          return { count, alive, dead }
        })
        upserted += n.count
        verified += n.count
        aliveCount += n.alive
        deadCount += n.dead
        await step.sleep(`yield-verify-${i}`, '0s')
      }
    } else if (portalRowIds.length > 0) {
      for (let i = 0; i < portalRowIds.length; i += UPSERT_CHUNK) {
        const chunkIds = portalRowIds.slice(i, i + UPSERT_CHUNK)
        const n = await step.run(`upsert-candidates-${i}`, async () => {
          const sb = createCatalogAdminClient()
          const rows = await getDeepRefPortalsForPromote(sb, chunkIds)
          let count = 0
          for (const row of rows) {
            const promoted = await promoteDeepRefPortalRow(sb, row)
            if (promoted.upserted) count++
          }
          return count
        })
        upserted += n
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
        await step.sleep(`yield-upsert-${i}`, '0s')
      }
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
      portalRows: portalRowIds.length,
    }
  },
)

/** When Inngest cancels the scrape, close DB run so Pool UI unsticks. */
export const iptvCatalogScrapeCancelled = inngest.createFunction(
  {
    id: 'iptv-catalog-scrape-cancelled',
    triggers: [{ event: 'inngest/function.cancelled' }],
  },
  async ({ event, step }) => {
    const fnId = String(
      (event.data as { function_id?: string })?.function_id ?? '',
    )
    if (!fnId.includes('iptv-catalog-scrape') || fnId.includes('cancelled')) {
      return { skipped: true }
    }
    await step.run('mark-db-cancelled', async () => {
      const sb = createCatalogAdminClient()
      const { data: rows } = await sb
        .from('iptv_scrape_runs')
        .select('id')
        .eq('status', 'running')
        .order('started_at', { ascending: false })
        .limit(5)
      for (const row of rows ?? []) {
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
