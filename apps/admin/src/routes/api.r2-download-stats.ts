import { createFileRoute } from '@tanstack/react-router'
import { authedAdmin } from '@/server/admin-request'
import {
  readDownloadsRollup,
  rollupToView,
} from '@/server/r2-download-stats'
import { sendInngestEvent } from '@/inngest/send-event'

export const Route = createFileRoute('/api/r2-download-stats')({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const auth = await authedAdmin(request)
        if (auth.error) return auth.error

        try {
          const rollup = await readDownloadsRollup()
          return Response.json(rollupToView(rollup))
        } catch (e) {
          const message = e instanceof Error ? e.message : 'R2 stats failed'
          return Response.json({ error: message }, { status: 502 })
        }
      },
      /** Trigger yesterday rollup or CF backfill (admin only). */
      POST: async ({ request }) => {
        const auth = await authedAdmin(request)
        if (auth.error) return auth.error

        try {
          const body = (await request.json().catch(() => ({}))) as {
            action?: string
            days?: number
          }
          if (body.action === 'backfill') {
            const sent = await sendInngestEvent({
              name: 'r2/downloads.backfill',
              data: { days: body.days ?? 30 },
            })
            return Response.json({ ok: true, action: 'backfill', ...sent })
          }
          const sent = await sendInngestEvent({
            name: 'r2/downloads.rollup',
            data: {},
          })
          return Response.json({ ok: true, action: 'rollup', ...sent })
        } catch (e) {
          const message = e instanceof Error ? e.message : 'Trigger failed'
          return Response.json({ error: message }, { status: 502 })
        }
      },
    },
  },
})
