import { createFileRoute } from '@tanstack/react-router'
import type { SupabaseClient } from '@supabase/supabase-js'
import { authedAdmin } from '@/server/admin-request'
import { classifyRegion } from '@/server/iptv-catalog/region'
import {
  createCatalogAdminClient,
  upsertCatalogCandidate,
} from '@/server/iptv-catalog/supabase-admin'
import type { CatalogPortal } from '@/server/iptv-catalog/types'
import { verifyPortalStatus } from '@/server/iptv-catalog/verify'

function json(data: unknown, status = 200) {
  return Response.json(data, { status })
}

function candidateHost(url: string): string {
  try {
    const u = new URL(url.includes('://') ? url : `http://${url}`)
    return u.host || url
  } catch {
    return url
  }
}

type CandRow = {
  id: string
  url: string
  username: string
}

async function decryptPassword(
  sb: SupabaseClient,
  id: string,
): Promise<string> {
  const { data, error } = await sb.rpc(
    'admin_iptv_catalog_candidate_password',
    { p_id: id },
  )
  if (error) throw new Error(error.message)
  return typeof data === 'string' ? data : ''
}

async function verifyOne(
  sb: SupabaseClient,
  row: CandRow,
): Promise<{
  id: string
  username: string
  alive: boolean
  status: string
  region: string
  error: string | null
}> {
  const password = await decryptPassword(sb, row.id)
  const portal: CatalogPortal = {
    url: row.url,
    username: row.username,
    password,
    source: 'catalog',
  }
  const status = await verifyPortalStatus(portal)
  const region = classifyRegion(status.timezone, status.categoryNames)
  const admin = createCatalogAdminClient()
  await upsertCatalogCandidate(admin, portal, status, region)
  return {
    id: row.id,
    username: row.username,
    alive: status.alive === true,
    status: status.status,
    region: region.primary,
    error: status.error ?? null,
  }
}

export const Route = createFileRoute('/api/iptv-catalog-verify')({
  server: {
    handlers: {
      POST: async ({ request }) => {
        try {
          const gate = await authedAdmin(request)
          if ('error' in gate && gate.error) return gate.error
          const sb = gate.sb!

          const body = (await request.json().catch(() => ({}))) as {
            candidateId?: string
            host?: string
          }
          const candidateId = body.candidateId?.trim()
          const host = body.host?.trim()

          if (!candidateId && !host) {
            return json(
              { error: 'candidateId or host required' },
              400,
            )
          }

          let rows: CandRow[] = []
          if (candidateId) {
            // Any portal by id (pool or assigned-only) — admin ops.
            const { data, error } = await sb
              .from('iptv_portals')
              .select('id, url, username')
              .eq('id', candidateId)
              .maybeSingle()
            if (error) return json({ error: error.message }, 500)
            if (!data) return json({ error: 'portal not found' }, 404)
            rows = [data as CandRow]
          } else if (host) {
            const { data, error } = await sb
              .from('iptv_portals')
              .select('id, url, username')
              .order('updated_at', { ascending: false })
              .limit(500)
            if (error) return json({ error: error.message }, 500)
            rows = ((data ?? []) as CandRow[]).filter(
              (r) => candidateHost(r.url) === host,
            )
            if (rows.length === 0) {
              return json({ error: 'no portals for host' }, 404)
            }
            // Manual host check — cap so one click can’t hang forever.
            rows = rows.slice(0, 40)
          }

          const results = []
          for (const row of rows) {
            try {
              results.push(await verifyOne(sb, row))
            } catch (e) {
              results.push({
                id: row.id,
                username: row.username,
                alive: false,
                status: 'error',
                region: 'UNKNOWN',
                error: e instanceof Error ? e.message : 'verify failed',
              })
            }
          }

          const alive = results.filter((r) => r.alive).length
          return json({
            ok: true,
            checked: results.length,
            alive,
            dead: results.length - alive,
            results,
          })
        } catch (e) {
          const message = e instanceof Error ? e.message : String(e)
          console.error('[iptv-catalog-verify]', message)
          return json({ error: message }, 500)
        }
      },
    },
  },
})
