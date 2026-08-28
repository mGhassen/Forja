import { defineApiRoute } from '@/lib/api-route'
import { sendInngestEvent, syncInngestApp } from '@/inngest/send-event'
import { STALKER_NOTE_BACKFILL_SOURCE } from '@/inngest/functions/iptv-stalker-note-backfill'
import { authedAdmin } from '@/server/admin-request'
import { createCatalogAdminClient } from '@/server/iptv-catalog/supabase-admin'
import { countStalkerNoteBackfillPending } from '@/server/iptv-catalog/stalker-note-backfill'

function json(data: unknown, status = 200) {
  return Response.json(data, { status })
}

const MAX_LIMIT = 20_000
const DEFAULT_CHUNK = 15

export const Route = defineApiRoute('/api/iptv-stalker-note-backfill', {
  POST: async ({ request }) => {
        try {
          const gate = await authedAdmin(request)
          if ('error' in gate && gate.error) return gate.error
          const sb = gate.sb!

          const body = (await request.json().catch(() => ({}))) as {
            action?: 'start' | 'count' | 'cancel'
            limit?: number
            chunkSize?: number
            jobId?: string
            runId?: string
          }
          const action = body.action ?? 'start'

          if (action === 'count') {
            const pending = await countStalkerNoteBackfillPending(
              createCatalogAdminClient(),
            )
            return json({ ok: true, pending })
          }

          if (action === 'cancel') {
            const patch = {
              status: 'error',
              finished_at: new Date().toISOString(),
              error: 'Stop requested from admin',
            }
            if (body.runId) {
              await sb
                .from('iptv_scrape_runs')
                .update(patch)
                .eq('id', body.runId)
                .eq('status', 'running')
                .eq('source', STALKER_NOTE_BACKFILL_SOURCE)
            } else {
              const { data: rows } = await sb
                .from('iptv_scrape_runs')
                .select('id')
                .eq('status', 'running')
                .eq('source', STALKER_NOTE_BACKFILL_SOURCE)
                .order('started_at', { ascending: false })
                .limit(3)
              for (const row of rows ?? []) {
                await sb
                  .from('iptv_scrape_runs')
                  .update(patch)
                  .eq('id', row.id)
              }
            }
            let cancelledInngest = false
            try {
              await sendInngestEvent({
                name: 'iptv/catalog.stalker-note-backfill.cancel',
                data: { jobId: body.jobId ?? null },
              })
              cancelledInngest = true
            } catch {
              // DB already closed
            }
            return json({
              ok: true,
              action: 'cancel',
              cancelledInngest,
            })
          }

          const limitRaw = Math.floor(Number(body.limit ?? MAX_LIMIT))
          const limit =
            Number.isFinite(limitRaw) && limitRaw > 0
              ? Math.min(MAX_LIMIT, limitRaw)
              : MAX_LIMIT
          const chunkRaw = Math.floor(Number(body.chunkSize ?? DEFAULT_CHUNK))
          const chunkSize =
            Number.isFinite(chunkRaw) && chunkRaw >= 5
              ? Math.min(40, chunkRaw)
              : DEFAULT_CHUNK

          const jobId = crypto.randomUUID()
          try {
            await syncInngestApp()
          } catch (e) {
            const message =
              e instanceof Error ? e.message : 'Inngest sync failed'
            return json({ error: message }, 502)
          }

          const { data: run, error: runErr } = await sb
            .from('iptv_scrape_runs')
            .insert({
              status: 'running',
              source: STALKER_NOTE_BACKFILL_SOURCE,
              posts_seen: 0,
            })
            .select('id, started_at, status, source')
            .single()
          if (runErr || !run?.id) {
            return json(
              {
                error: runErr?.message ?? 'Failed to create note backfill run',
              },
              500,
            )
          }

          try {
            const { ids } = await sendInngestEvent({
              name: 'iptv/catalog.stalker-note-backfill',
              data: { jobId, runId: run.id, limit, chunkSize },
            })
            return json({
              ok: true,
              action: 'start',
              jobId,
              runId: run.id,
              run,
              limit,
              chunkSize,
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
                    : 'Failed to enqueue Inngest note backfill',
              })
              .eq('id', run.id)
            throw e
          }
        } catch (error) {
          const message =
            error instanceof Error
              ? error.message
              : 'Stalker note backfill control failed'
          console.error('[iptv-stalker-note-backfill]', message)
          return json({ error: message }, 502)
        }
      },
})
