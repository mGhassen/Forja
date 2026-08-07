import { createFileRoute } from '@tanstack/react-router'
import { authedAdmin } from '@/server/admin-request'
import {
  readDownloadsRollup,
  rollupDaysFromCf,
  rollupToView,
  rollupYesterday,
  utcDayString,
} from '@/server/r2-download-stats'

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
      /**
       * Run rollup/backfill inline (not Inngest queue) so the admin button
       * returns real numbers or a real error immediately.
       */
      POST: async ({ request }) => {
        const auth = await authedAdmin(request)
        if (auth.error) return auth.error

        try {
          const body = (await request.json().catch(() => ({}))) as {
            action?: string
            days?: number
          }

          if (body.action === 'backfill') {
            const days = Math.min(
              31,
              Math.max(1, Math.floor(Number(body.days ?? 30))),
            )
            const to = new Date()
            to.setUTCDate(to.getUTCDate() - 1)
            const from = new Date(to)
            from.setUTCDate(from.getUTCDate() - (days - 1))

            const result = await rollupDaysFromCf({
              fromDay: utcDayString(from),
              toDay: utcDayString(to),
            })
            return Response.json({
              ok: true,
              action: 'backfill',
              daysWritten: result.daysWritten,
              ...result.view,
            })
          }

          const result = await rollupYesterday()
          return Response.json({
            ok: true,
            action: 'rollup',
            day: result.day,
            ...result.view,
          })
        } catch (e) {
          const message = e instanceof Error ? e.message : 'Rollup failed'
          return Response.json({ error: message }, { status: 502 })
        }
      },
    },
  },
})
