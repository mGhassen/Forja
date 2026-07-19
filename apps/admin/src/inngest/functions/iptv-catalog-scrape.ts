import { inngest } from '@/inngest/client'
import { classifyRegion } from '@/server/iptv-catalog/region'
import { scrapeCatalogPage } from '@/server/iptv-catalog/reddit'
import { cronMatchesUtc, isValidScrapeCron } from '@/lib/scrape-cron'
import {
  createCatalogAdminClient,
  getScrapeCronSettings,
  insertScrapeRun,
  patchScrapeRun,
  upsertCatalogCandidate,
  upsertScrapePostId,
} from '@/server/iptv-catalog/supabase-admin'
import type { CatalogPortal, PortalStatus } from '@/server/iptv-catalog/types'
import { portalKey } from '@/server/iptv-catalog/types'
import { verifyPortalStatus } from '@/server/iptv-catalog/verify'

/**
 * player_api probes are slow (N Inngest steps). Off for now — still upserts
 * candidates with alive=null. Flip to true to restore verify-portal-status-*.
 * Code path kept intentionally.
 */
const VERIFY_PORTAL_STATUS = false

const UNVERIFIED_STATUS: PortalStatus = {
  alive: null,
  status: 'unverified',
  expiry: null,
  maxConnections: null,
  timezone: null,
  categoryNames: [],
}

type ScrapeData = {
  jobId?: string
  maxPages?: number
  maxResultsPerPage?: number
  maxVerify?: number
}

async function markRun(runId: string, error?: string) {
  const sb = createCatalogAdminClient()
  // DB check: status in (running, ok, error) — no cancelled
  await patchScrapeRun(sb, runId, {
    status: 'error',
    finished_at: new Date().toISOString(),
    error: error ?? null,
  })
}

/**
 * Scheduled + on-demand catalog scrape.
 * Inngest ticks every minute; schedule lives in iptv_ops_settings.scrape_cron (UTC).
 * Cancel with event `iptv/catalog.scrape.cancel` (same jobId).
 * When VERIFY_PORTAL_STATUS: each portal step verify-portal-status-* → player_api.
 * Otherwise: bulk upsert unverified (no portal HTTP).
 */
export const iptvCatalogScrape = inngest.createFunction(
  {
    id: 'iptv-catalog-scrape',
    concurrency: { limit: 1 },
    retries: 1,
    triggers: [{ cron: '* * * * *' }, { event: 'iptv/catalog.scrape' }],
    // concurrency 1 → any cancel event stops the active scrape
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
        if (!cronMatchesUtc(settings.cron)) {
          return {
            run: false as const,
            reason: `cron_mismatch=${settings.cron}`,
          }
        }
        return { run: true as const, cron: settings.cron }
      })
      if (!gate.run) {
        return { skipped: true, reason: gate.reason, jobId }
      }
    }

    const maxPages = Math.min(Math.max(data.maxPages ?? 5, 1), 20)
    const maxResultsPerPage = Math.min(
      Math.max(data.maxResultsPerPage ?? 50, 1),
      100,
    )
    const maxVerify = Math.min(Math.max(data.maxVerify ?? 40, 1), 200)

    const runId = await step.run('create-scrape-run', async () => {
      const sb = createCatalogAdminClient()
      return insertScrapeRun(sb, 'inngest-admin')
    })

    const portals = new Map<string, CatalogPortal>()
    const seenPostIds = new Set<string>()
    let after: string | null = null
    let postsSeen = 0

    for (let page = 0; page < maxPages; page++) {
      const result = await step.run(`scrape-reddit-page-${page}`, async () =>
        scrapeCatalogPage(after, maxResultsPerPage),
      )
      postsSeen += result.postsSeen
      for (const id of result.postIds) seenPostIds.add(id)
      for (const p of result.portals) {
        portals.set(portalKey(p), p)
      }
      after = result.nextAfter
      if (!after) break
    }

    await step.run('checkpoint-after-reddit', async () => {
      const sb = createCatalogAdminClient()
      // Id-only post rows (no title/body) + run counters.
      for (const postId of seenPostIds) {
        await upsertScrapePostId(sb, postId, runId)
      }
      await patchScrapeRun(sb, runId, {
        posts_seen: postsSeen,
        l1_extract_count: portals.size,
      })
    })

    const list = [...portals.values()].slice(0, maxVerify)
    let aliveCount = 0
    let upserted = 0
    let deadCount = 0
    let verified = 0

    if (VERIFY_PORTAL_STATUS) {
      for (let i = 0; i < list.length; i++) {
        const portal = list[i]!
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

        if (i % 5 === 0 || i === list.length - 1) {
          await step.run(`progress-${i}`, async () => {
            const sb = createCatalogAdminClient()
            await patchScrapeRun(sb, runId, {
              candidates_upserted: upserted,
              alive_count: aliveCount,
              posts_seen: postsSeen,
              l1_extract_count: portals.size,
            })
          })
        }
      }
    } else if (list.length > 0) {
      // No player_api — one bulk step (verifyPortalStatus kept above for re-enable).
      upserted = await step.run('upsert-candidates-unverified', async () => {
        const sb = createCatalogAdminClient()
        const region = classifyRegion(null, [])
        let n = 0
        for (const portal of list) {
          await upsertCatalogCandidate(sb, portal, UNVERIFIED_STATUS, region)
          n++
        }
        return n
      })
    }

    await step.run('finalize-scrape-run', async () => {
      const sb = createCatalogAdminClient()
      await patchScrapeRun(sb, runId, {
        status: 'ok',
        finished_at: new Date().toISOString(),
        posts_seen: postsSeen,
        l1_extract_count: portals.size,
        candidates_upserted: upserted,
        alive_count: aliveCount,
        error: null,
      })
    })

    return {
      jobId,
      runId,
      scrapedUnique: portals.size,
      verified,
      verifyEnabled: VERIFY_PORTAL_STATUS,
      upserted,
      aliveCount,
      deadCount,
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
        .limit(3)
      for (const row of rows ?? []) {
        await markRun(row.id as string, 'Stopped / cancelled')
      }
    })
  },
)
