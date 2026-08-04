import { inngest } from '@/inngest/client'
import { classifyRegion } from '@/server/iptv-catalog/region'
import {
  processDeepRefRow,
  scrapeCatalogPage,
} from '@/server/iptv-catalog/reddit'
import { cronIsDueUtc, isValidScrapeCron } from '@/lib/scrape-cron'
import {
  createCatalogAdminClient,
  getLastScheduledScrapeStartedAt,
  getScrapeCronSettings,
  insertScrapeRun,
  listPendingDeepRefsForRun,
  loadKnownScrapePostIds,
  patchScrapeRun,
  upsertCatalogCandidate,
  upsertScrapeDeepRef,
  upsertScrapePostId,
} from '@/server/iptv-catalog/supabase-admin'
import type { CatalogPortal, PortalStatus } from '@/server/iptv-catalog/types'
import { portalKey } from '@/server/iptv-catalog/types'
import { verifyPortalStatus } from '@/server/iptv-catalog/verify'

/**
 * player_api probes are slow (N Inngest steps). Off for now — still upserts
 * candidates with alive=null. Flip to true to restore verify-portal-status-*.
 * Verify is separate from scrape upsert volume (no upsert cap).
 */
const VERIFY_PORTAL_STATUS = false

/** Chunk size for Inngest upsert steps (timeout safety only — not a product cap). */
const UPSERT_CHUNK = 50

type ScrapeData = {
  jobId?: string
  /** Pre-created by admin API so UI shows running immediately. */
  runId?: string
  maxPages?: number
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
 * Phase 1: walk Reddit /new → posts + deep_ref stubs in DB.
 * Phase 2: process pending deep_refs (paste fetch + extract).
 * Then upsert portal candidates. Watermark / maxPages still apply.
 */
export const iptvCatalogScrape = inngest.createFunction(
  {
    id: 'iptv-catalog-scrape',
    concurrency: { limit: 1 },
    retries: 1,
    // Checkpoint every step; bail well under Vercel maxDuration (300s).
    checkpointing: { bufferedSteps: 1, maxRuntime: '45s' },
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

    // One Reddit page (10 posts) per Inngest step. Default 10 pages when unset
    // (full dialog passes an explicit maxPages). Cap 200.
    const maxPages = Math.min(Math.max(data.maxPages ?? 10, 1), 200)
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

    const knownIds = await step.run('load-known-post-ids', async () => {
      if (data.forceFull) return [] as string[]
      const sb = createCatalogAdminClient()
      const set = await loadKnownScrapePostIds(sb)
      return [...set]
    })
    const knownPostIds = new Set(knownIds)

    const portals = new Map<string, CatalogPortal>()
    let after: string | null = null
    let postsSeen = 0
    let deepRefCount = 0
    let l2FetchOk = 0
    let l2FetchFail = 0
    let l2ExtractCount = 0
    let unparsedCount = 0
    let l1OnlyCount = 0
    let hitWatermark = false

    // Phase 1 — COLLECT: Reddit pages → posts + deep_ref stubs (no paste HTTP).
    for (let page = 0; page < maxPages; page++) {
      const pageAfter = after
      const knownSnapshot = [...knownPostIds]
      const result = await step.run(`collect-reddit-page-${page}`, async () => {
        const known = new Set(knownSnapshot)
        const pageResult = await scrapeCatalogPage(
          pageAfter,
          maxResultsPerPage,
          known,
        )
        const sb = createCatalogAdminClient()
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
        return {
          portals: pageResult.portals,
          postIds: pageResult.postIds,
          nextAfter: pageResult.nextAfter,
          postsSeen: pageResult.postsSeen,
          hitWatermark: pageResult.hitWatermark,
          funnel: pageResult.funnel,
        }
      })

      postsSeen += result.postsSeen
      deepRefCount += result.funnel?.deepRefCount ?? 0
      unparsedCount += result.funnel?.unparsedCount ?? 0
      l1OnlyCount += result.funnel?.l1OnlyCount ?? 0
      for (const id of result.postIds) knownPostIds.add(id)
      for (const p of result.portals) {
        portals.set(portalKey(p), p)
      }

      await step.run(`checkpoint-collect-${page}`, async () => {
        const sb = createCatalogAdminClient()
        await patchScrapeRun(sb, runId, {
          posts_seen: postsSeen,
          l1_extract_count: portals.size,
          deep_ref_count: deepRefCount,
          unparsed_count: unparsedCount,
        })
      })
      // Force new Vercel invoke — never chain 10 pages into one 300s request.
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
        l1_extract_count: portals.size,
        deep_ref_count: deepRefCount,
        unparsed_count: unparsedCount,
      })
    })

    // Phase 2 — PROCESS: pending deep_refs from DB → paste fetch + extract.
    // Unparsed after process only (collect stubs are incomplete by design).
    unparsedCount = 0
    const pending = await step.run('list-pending-deep-refs', async () => {
      const sb = createCatalogAdminClient()
      return listPendingDeepRefsForRun(sb, runId)
    })

    for (let i = 0; i < pending.length; i++) {
      const row = pending[i]!
      const outcome = await step.run(`process-deep-ref-${i}`, async () => {
        const processed = await processDeepRefRow(row, maxResultsPerPage)
        const sb = createCatalogAdminClient()
        await upsertScrapeDeepRef(sb, processed.ref, runId, {
          linkPortals: true,
        })
        return {
          portals: processed.ref.portals
            .filter((h) => h.username && (h.password || h.platform === 'stalker'))
            .map((h) => ({
              url: h.url,
              username: h.username,
              password: h.password || '',
              source: processed.ref.pasteUrl
                ? 'catalog-deep'
                : 'catalog-decoded',
              postId: processed.ref.postId,
              expiry: h.expiry ?? null,
              maxConnections: h.maxConnections ?? null,
              timezone: h.timezone ?? null,
              regionPrimary: h.regionPrimary,
              regionTags: h.regionTags,
              regionConfidence: h.regionConfidence,
              allowedOutputs: h.allowedOutputs ?? null,
            })),
          l2FetchOk: processed.l2FetchOk,
          l2FetchFail: processed.l2FetchFail,
          l2ExtractCount: processed.l2ExtractCount,
          needsRecheck: processed.ref.needsRecheck,
        }
      })
      l2FetchOk += outcome.l2FetchOk
      l2FetchFail += outcome.l2FetchFail
      l2ExtractCount += outcome.l2ExtractCount
      if (outcome.needsRecheck) unparsedCount++
      for (const p of outcome.portals) {
        portals.set(portalKey(p), p)
      }

      if (i % 5 === 0 || i === pending.length - 1) {
        await step.run(`checkpoint-process-${i}`, async () => {
          const sb = createCatalogAdminClient()
          await patchScrapeRun(sb, runId, {
            posts_seen: postsSeen,
            l1_extract_count: portals.size,
            deep_ref_count: deepRefCount,
            l2_fetch_ok: l2FetchOk,
            l2_fetch_fail: l2FetchFail,
            l2_extract_count: l2ExtractCount,
            unparsed_count: unparsedCount,
          })
        })
      }
      // One paste per invoke budget — Vercel must not sit open across N pastes.
      await step.sleep(`yield-process-${i}`, '0s')
    }

    await step.run('checkpoint-after-reddit', async () => {
      const sb = createCatalogAdminClient()
      await patchScrapeRun(sb, runId, {
        posts_seen: postsSeen,
        l1_extract_count: portals.size,
        deep_ref_count: deepRefCount,
        l2_fetch_ok: l2FetchOk,
        l2_fetch_fail: l2FetchFail,
        l2_extract_count: l2ExtractCount,
        unparsed_count: unparsedCount,
      })
    })

    const list = [...portals.values()]
    let aliveCount = 0
    let upserted = 0
    let deadCount = 0
    let verified = 0

    if (VERIFY_PORTAL_STATUS) {
      const toVerify = list.slice(0, maxVerify)
      for (let i = 0; i < toVerify.length; i++) {
        const portal = toVerify[i]!
        const outcome = await step.run(
          `verify-portal-status-${i}`,
          async () => {
            const status = await verifyPortalStatus(portal)
            const region = classifyRegion(status.timezone, status.categoryNames)
            const sb = createCatalogAdminClient()
            await upsertCatalogCandidate(sb, portal, status, region)
            return {
              alive: status.alive,
              status: status.status,
              region: region.primary,
              error: status.error ?? null,
            }
          },
        )
        upserted++
        verified++
        if (outcome.alive) aliveCount++
        else deadCount++

        if (i % 5 === 0 || i === toVerify.length - 1) {
          await step.run(`progress-${i}`, async () => {
            const sb = createCatalogAdminClient()
            await patchScrapeRun(sb, runId, {
              candidates_upserted: upserted,
              alive_count: aliveCount,
              posts_seen: postsSeen,
              l1_extract_count: portals.size,
              deep_ref_count: deepRefCount,
              l2_fetch_ok: l2FetchOk,
              l2_fetch_fail: l2FetchFail,
              l2_extract_count: l2ExtractCount,
              unparsed_count: unparsedCount,
            })
          })
        }
      }
    } else if (list.length > 0) {
      for (let i = 0; i < list.length; i += UPSERT_CHUNK) {
        const chunk = list.slice(i, i + UPSERT_CHUNK)
        const n = await step.run(`upsert-candidates-${i}`, async () => {
          const sb = createCatalogAdminClient()
          let count = 0
          for (const portal of chunk) {
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
            count++
          }
          return count
        })
        upserted += n
        await step.run(`progress-upsert-${i}`, async () => {
          const sb = createCatalogAdminClient()
          await patchScrapeRun(sb, runId, {
            candidates_upserted: upserted,
            posts_seen: postsSeen,
            l1_extract_count: portals.size,
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
        l1_extract_count: portals.size,
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
      scrapedUnique: portals.size,
      l1OnlyCount,
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
