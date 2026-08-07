import { createFileRoute } from '@tanstack/react-router'
import { sendInngestEvent } from '@/inngest/send-event'
import { authedAdmin } from '@/server/admin-request'
import {
  countEligibleUnpromotedPortals,
  createCatalogAdminClient,
} from '@/server/iptv-catalog/supabase-admin'

function json(data: unknown, status = 200) {
  return Response.json(data, { status })
}

const MAX_LIMIT = 20_000
const DEFAULT_CHUNK = 25

export const Route = createFileRoute('/api/iptv-promote-backfill')({
  server: {
    handlers: {
      POST: async ({ request }) => {
        try {
          const gate = await authedAdmin(request)
          if ('error' in gate && gate.error) return gate.error

          const body = (await request.json().catch(() => ({}))) as {
            action?: 'start' | 'count' | 'cancel'
            limit?: number
            chunkSize?: number
            jobId?: string
          }
          const action = body.action ?? 'start'

          if (action === 'count') {
            const sb = createCatalogAdminClient()
            const pending = await countEligibleUnpromotedPortals(sb)
            return json({ ok: true, pending })
          }

          if (action === 'cancel') {
            try {
              await sendInngestEvent({
                name: 'iptv/catalog.promote-backfill.cancel',
                data: { jobId: body.jobId ?? null },
              })
              return json({ ok: true, action: 'cancel', cancelledInngest: true })
            } catch {
              return json({
                ok: true,
                action: 'cancel',
                cancelledInngest: false,
              })
            }
          }

          const limitRaw = Math.floor(Number(body.limit ?? MAX_LIMIT))
          const limit =
            Number.isFinite(limitRaw) && limitRaw > 0
              ? Math.min(MAX_LIMIT, limitRaw)
              : MAX_LIMIT
          const chunkRaw = Math.floor(Number(body.chunkSize ?? DEFAULT_CHUNK))
          const chunkSize =
            Number.isFinite(chunkRaw) && chunkRaw >= 10
              ? Math.min(50, chunkRaw)
              : DEFAULT_CHUNK

          const jobId = crypto.randomUUID()
          const { ids } = await sendInngestEvent({
            name: 'iptv/catalog.promote-backfill',
            data: { jobId, limit, chunkSize },
          })

          return json({
            ok: true,
            action: 'start',
            jobId,
            limit,
            chunkSize,
            ids,
          })
        } catch (error) {
          const message =
            error instanceof Error
              ? error.message
              : 'Promote backfill control failed'
          console.error('[iptv-promote-backfill]', message)
          return json({ error: message }, 502)
        }
      },
    },
  },
})
