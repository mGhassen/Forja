import { inngest } from '@/inngest/client'
import { createCatalogAdminClient } from '@/server/iptv-catalog/supabase-admin'

const TTL_MS = 7 * 24 * 60 * 60 * 1000

/**
 * Daily 04:20 UTC: delete IPTV share-code rows older than 7 days.
 * Manual: event `iptv/share-codes.purge`.
 */
export const iptvShareCodesPurge = inngest.createFunction(
  {
    id: 'iptv-share-codes-purge',
    concurrency: { limit: 1 },
    retries: 2,
    checkpointing: false,
    triggers: [
      { cron: '20 4 * * *' },
      { event: 'iptv/share-codes.purge' },
    ],
  },
  async ({ step }) => {
    return step.run('delete-expired', async () => {
      const sb = createCatalogAdminClient()
      const cutoff = new Date(Date.now() - TTL_MS).toISOString()
      const { data, error } = await sb
        .from('iptv_share_codes')
        .delete()
        .lt('created_at', cutoff)
        .select('code')
      if (error) throw error
      return { deleted: data?.length ?? 0 }
    })
  },
)
