import { defineApiRoute } from '@/lib/api-route'
import { sendInngestEvent } from '@/inngest/send-event'
import { authedAdmin } from '@/server/admin-request'

function json(data: unknown, status = 200) {
  return Response.json(data, { status })
}

export const Route = defineApiRoute('/api/iptv-catalog-scrape', {
  POST: async ({ request }) => {
        try {
          const gate = await authedAdmin(request)
          if ('error' in gate && gate.error) return gate.error
          const sb = gate.sb!

          const body = (await request.json().catch(() => ({}))) as {
            action?: 'start' | 'stop' | 'mark_stuck'
            jobId?: string
            maxPages?: number
            startPage?: number
            endPage?: number
            maxVerify?: number
            forceFull?: boolean
            runId?: string
          }
          const action = body.action ?? 'start'

          if (action === 'stop') {
            // Unstick UI even if Inngest CLI/cloud is down
            const patch = {
              status: 'error',
              finished_at: new Date().toISOString(),
              error: 'Stop requested from admin',
            }
            let source: string | null = null
            if (body.runId) {
              const { data: row } = await sb
                .from('iptv_scrape_runs')
                .select('source')
                .eq('id', body.runId)
                .maybeSingle()
              source = row?.source != null ? String(row.source) : null
              await sb
                .from('iptv_scrape_runs')
                .update(patch)
                .eq('id', body.runId)
                .eq('status', 'running')
            } else {
              const { data: rows } = await sb
                .from('iptv_scrape_runs')
                .select('id')
                .eq('status', 'running')
                .order('started_at', { ascending: false })
                .limit(3)
              for (const row of rows ?? []) {
                await sb
                  .from('iptv_scrape_runs')
                  .update(patch)
                  .eq('id', row.id)
              }
            }
            const cancelBackfill =
              !body.runId || source === 'promote-backfill'
            const cancelScrape =
              !body.runId || source !== 'promote-backfill'
            let cancelledInngest = false
            try {
              if (cancelScrape) {
                await sendInngestEvent({
                  name: 'iptv/catalog.scrape.cancel',
                  data: { jobId: body.jobId ?? null },
                })
                cancelledInngest = true
              }
              if (cancelBackfill) {
                await sendInngestEvent({
                  name: 'iptv/catalog.promote-backfill.cancel',
                  data: { jobId: body.jobId ?? null },
                })
                cancelledInngest = true
              }
            } catch {
              // DB already closed; worker may still finish if Inngest is dead
            }
            return json({ ok: true, action: 'stop', cancelledInngest })
          }

          if (action === 'mark_stuck') {
            const { data: rows, error } = await sb
              .from('iptv_scrape_runs')
              .select('id')
              .eq('status', 'running')
              .order('started_at', { ascending: false })
              .limit(10)
            if (error) return json({ error: error.message }, 500)
            for (const row of rows ?? []) {
              await sb
                .from('iptv_scrape_runs')
                .update({
                  status: 'error',
                  finished_at: new Date().toISOString(),
                  error: 'Marked stuck from admin (Inngest may have died)',
                })
                .eq('id', row.id)
            }
            return json({
              ok: true,
              action: 'mark_stuck',
              count: rows?.length ?? 0,
            })
          }

          // start — insert run row first so admin UI updates immediately
          const jobId = crypto.randomUUID()
          const { data: run, error: runErr } = await sb
            .from('iptv_scrape_runs')
            .insert({
              status: 'running',
              source: 'manual-admin',
              posts_seen: 0,
            })
            .select('id, started_at, status, source')
            .single()
          if (runErr || !run?.id) {
            return json(
              { error: runErr?.message ?? 'Failed to create scrape run' },
              500,
            )
          }

          try {
            const { ids } = await sendInngestEvent({
              name: 'iptv/catalog.scrape',
              data: {
                jobId,
                runId: run.id,
                maxPages: body.maxPages,
                startPage: body.startPage,
                endPage: body.endPage,
                maxVerify: body.maxVerify,
                forceFull: body.forceFull === true,
              },
            })
            return json({
              ok: true,
              action: 'start',
              jobId,
              runId: run.id,
              run,
              ids,
            })
          } catch (e) {
            await sb
              .from('iptv_scrape_runs')
              .update({
                status: 'error',
                finished_at: new Date().toISOString(),
                error:
                  e instanceof Error
                    ? e.message
                    : 'Failed to enqueue Inngest scrape',
              })
              .eq('id', run.id)
            throw e
          }
        } catch (error) {
          const message =
            error instanceof Error ? error.message : 'Scrape control failed'
          console.error('[iptv-catalog-scrape]', message)
          return json({ error: message }, 502)
        }
      },
})
