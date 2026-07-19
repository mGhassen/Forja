import { inngest } from '@/inngest/client'
import { classifyRegion } from '@/server/iptv-catalog/region'
import { scrapeCatalogPage } from '@/server/iptv-catalog/reddit'
import {
  createCatalogAdminClient,
  insertScrapeRun,
  patchScrapeRun,
  upsertCatalogCandidate,
} from '@/server/iptv-catalog/supabase-admin'
import type { CatalogPortal } from '@/server/iptv-catalog/types'
import { portalKey } from '@/server/iptv-catalog/types'
import { verifyPortalStatus } from '@/server/iptv-catalog/verify'

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
 * Daily + on-demand catalog scrape.
 * Cancel with event `iptv/catalog.scrape.cancel` (same jobId).
 * Each portal: step `verify-portal-status-*` → player_api.
 */
export const iptvCatalogScrape = inngest.createFunction(
  {
    id: 'iptv-catalog-scrape',
    concurrency: { limit: 1 },
    retries: 1,
    triggers: [{ cron: '0 6 * * *' }, { event: 'iptv/catalog.scrape' }],
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
    let after: string | null = null
    let postsSeen = 0

    for (let page = 0; page < maxPages; page++) {
      const result = await step.run(`scrape-reddit-page-${page}`, async () =>
        scrapeCatalogPage(after, maxResultsPerPage),
      )
      postsSeen += result.postsSeen
      for (const p of result.portals) {
        portals.set(portalKey(p), p)
      }
      after = result.nextAfter
      if (!after) break
    }

    await step.run('checkpoint-after-reddit', async () => {
      const sb = createCatalogAdminClient()
      await patchScrapeRun(sb, runId, {
        posts_seen: postsSeen,
        l1_extract_count: portals.size,
      })
    })

    const list = [...portals.values()].slice(0, maxVerify)
    let aliveCount = 0
    let upserted = 0
    let deadCount = 0

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
      verified: list.length,
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
