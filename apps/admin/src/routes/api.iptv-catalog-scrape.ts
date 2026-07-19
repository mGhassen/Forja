import { createFileRoute } from '@tanstack/react-router'
import { createClient } from '@supabase/supabase-js'
import { inngest } from '@/inngest/client'

function json(data: unknown, status = 200) {
  return Response.json(data, { status })
}

async function authedAdmin(request: Request) {
  const auth = request.headers.get('authorization') ?? ''
  const token = auth.replace(/^Bearer\s+/i, '').trim()
  if (!token) return { error: json({ error: 'not authenticated' }, 401) }

  const url =
    process.env.SUPABASE_URL?.trim() ||
    process.env.VITE_SUPABASE_URL?.trim() ||
    ''
  const anon =
    process.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim() ||
    process.env.SUPABASE_PUBLISHABLE_KEY?.trim() ||
    ''
  if (!url || !anon) {
    return { error: json({ error: 'Supabase env missing' }, 500) }
  }

  const sb = createClient(url, anon, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  })
  const {
    data: { user },
    error: userErr,
  } = await sb.auth.getUser(token)
  if (userErr || !user) {
    return { error: json({ error: 'not authenticated' }, 401) }
  }

  const { data: admin, error: adminErr } = await sb.rpc('is_admin')
  if (adminErr) return { error: json({ error: adminErr.message }, 500) }
  if (!admin) return { error: json({ error: 'admin only' }, 403) }

  return { sb, user }
}

export const Route = createFileRoute('/api/iptv-catalog-scrape')({
  server: {
    handlers: {
      POST: async ({ request }) => {
        try {
          const gate = await authedAdmin(request)
          if ('error' in gate && gate.error) return gate.error
          const sb = gate.sb!

          const body = (await request.json().catch(() => ({}))) as {
            action?: 'start' | 'stop' | 'mark_stuck'
            jobId?: string
            maxPages?: number
            maxVerify?: number
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
            if (body.runId) {
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
            let cancelledInngest = false
            try {
              await inngest.send({
                name: 'iptv/catalog.scrape.cancel',
                data: { jobId: body.jobId ?? null },
              })
              cancelledInngest = true
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

          // start
          const jobId = crypto.randomUUID()
          const ids = await inngest.send({
            name: 'iptv/catalog.scrape',
            data: {
              jobId,
              maxPages: body.maxPages,
              maxVerify: body.maxVerify,
            },
          })

          return json({ ok: true, action: 'start', jobId, ids })
        } catch (error) {
          const message =
            error instanceof Error ? error.message : 'Scrape control failed'
          return json({ error: message }, 502)
        }
      },
    },
  },
})
