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

type ScrapeEvent = {
  name: 'iptv/catalog.scrape'
  data: {
    maxPages?: number
    maxResultsPerPage?: number
    /** Cap how many portals get a verify-status step (Vercel-friendly). */
    maxVerify?: number
  }
}

/**
 * Daily (and on-demand) IPTV catalog scrape on Vercel via Inngest.
 * Each portal gets its own `verify-portal-status-*` step that hits player_api.
 */
export const iptvCatalogScrape = inngest.createFunction(
  {
    id: 'iptv-catalog-scrape',
    concurrency: { limit: 1 },
    retries: 1,
    triggers: [{ cron: '0 6 * * *' }, { event: 'iptv/catalog.scrape' }],
  },
  async ({ event, step }) => {
    const data = (event?.data ?? {}) as ScrapeEvent['data']
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
            url: portal.url,
            username: portal.username,
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
      })
    })

    return {
      runId,
      scrapedUnique: portals.size,
      verified: list.length,
      upserted,
      aliveCount,
      deadCount,
    }
  },
)
