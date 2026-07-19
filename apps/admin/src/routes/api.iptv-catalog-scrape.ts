import { createFileRoute } from '@tanstack/react-router'
import { createClient } from '@supabase/supabase-js'
import { inngest } from '@/inngest/client'

function json(data: unknown, status = 200) {
  return Response.json(data, { status })
}

export const Route = createFileRoute('/api/iptv-catalog-scrape')({
  server: {
    handlers: {
      POST: async ({ request }) => {
        try {
          const auth = request.headers.get('authorization') ?? ''
          const token = auth.replace(/^Bearer\s+/i, '').trim()
          if (!token) return json({ error: 'not authenticated' }, 401)

          const url =
            process.env.SUPABASE_URL?.trim() ||
            process.env.VITE_SUPABASE_URL?.trim() ||
            ''
          const anon =
            process.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim() ||
            process.env.SUPABASE_PUBLISHABLE_KEY?.trim() ||
            ''
          if (!url || !anon) {
            return json({ error: 'Supabase env missing' }, 500)
          }

          const sb = createClient(url, anon, {
            auth: { persistSession: false, autoRefreshToken: false },
            global: { headers: { Authorization: `Bearer ${token}` } },
          })
          const {
            data: { user },
            error: userErr,
          } = await sb.auth.getUser(token)
          if (userErr || !user) return json({ error: 'not authenticated' }, 401)

          const { data: admin, error: adminErr } = await sb.rpc('is_admin')
          if (adminErr) return json({ error: adminErr.message }, 500)
          if (!admin) return json({ error: 'admin only' }, 403)

          const body = (await request.json().catch(() => ({}))) as {
            maxPages?: number
            maxVerify?: number
          }

          const ids = await inngest.send({
            name: 'iptv/catalog.scrape',
            data: {
              maxPages: body.maxPages,
              maxVerify: body.maxVerify,
            },
          })

          return json({ ok: true, ids })
        } catch (error) {
          const message =
            error instanceof Error ? error.message : 'Could not start scrape'
          return json({ error: message }, 502)
        }
      },
    },
  },
})
