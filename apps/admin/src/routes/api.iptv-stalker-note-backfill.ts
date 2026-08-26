import { createFileRoute } from '@tanstack/react-router'
import { authedAdmin } from '@/server/admin-request'
import { createCatalogAdminClient } from '@/server/iptv-catalog/supabase-admin'
import { backfillStalkerNotesChunk } from '@/server/iptv-catalog/stalker-note-backfill'

function json(data: unknown, status = 200) {
  return Response.json(data, { status })
}

export const Route = createFileRoute('/api/iptv-stalker-note-backfill')({
  server: {
    handlers: {
      POST: async ({ request }) => {
        try {
          const gate = await authedAdmin(request)
          if ('error' in gate && gate.error) return gate.error

          const body = (await request.json().catch(() => ({}))) as {
            limit?: number
          }
          const limit = Number(body.limit ?? 25)
          const sb = createCatalogAdminClient()
          const result = await backfillStalkerNotesChunk(sb, { limit })
          return json({ ok: true, ...result })
        } catch (e) {
          return json(
            { error: e instanceof Error ? e.message : 'backfill failed' },
            500,
          )
        }
      },
    },
  },
})
