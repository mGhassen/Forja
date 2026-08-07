import { adminDb } from '@/lib/admin-db'

export type PortalPlatform = 'xtream' | 'm3u' | 'stalker'

export type PoolCand = {
  id: string
  url: string
  username: string
  alive: boolean | null
  expiry: string | null
  max_connections: string | null
  region_primary: string
  dealt_count: number
  catalog_pool: boolean
  platform: PortalPlatform
  updated_at: string
  created_at: string
  last_scraped_at: string | null
}

export type PoolHostSummary = {
  host: string
  accounts: number
  alive: number
  last_scraped_at: string | null
}

export type PoolHostsResult = {
  hosts: PoolHostSummary[]
  host_count: number
  portal_count: number
  regions: string[]
}

export type PoolFilterParams = {
  q?: string
  inventory?: 'all' | 'pool' | 'nonpool'
  platform?: 'all' | PortalPlatform
  status?: 'all' | 'alive' | 'dead' | 'unchecked'
  region?: string
  sort?: 'host' | 'accounts' | 'alive' | 'scraped'
  dir?: 'asc' | 'desc'
  limit?: number
  offset?: number
}

function errMessage(e: unknown, fallback: string): string {
  if (e && typeof e === 'object' && 'message' in e) {
    const m = (e as { message?: string }).message
    if (m) return m
  }
  return e instanceof Error ? e.message : fallback
}

export function poolHostKey(host: string): string {
  return host.trim().toLowerCase()
}

export async function fetchPoolHosts(
  opts: PoolFilterParams,
): Promise<PoolHostsResult> {
  const { data, error } = await adminDb.rpc('admin_iptv_pool_hosts', {
    p_q: opts.q?.trim() || null,
    p_inventory: opts.inventory ?? 'all',
    p_platform: opts.platform ?? 'all',
    p_status: opts.status ?? 'all',
    p_region: opts.region ?? 'all',
    p_sort: opts.sort ?? 'accounts',
    p_dir: opts.dir ?? 'desc',
    p_limit: opts.limit ?? 50,
    p_offset: opts.offset ?? 0,
  })
  if (error) throw new Error(errMessage(error, 'Pool hosts failed'))
  const raw = (data ?? {}) as Record<string, unknown>
  const hosts = Array.isArray(raw.hosts)
    ? (raw.hosts as PoolHostSummary[]).map((h) => ({
        host: String(h.host ?? ''),
        accounts: Number(h.accounts ?? 0),
        alive: Number(h.alive ?? 0),
        last_scraped_at: (h.last_scraped_at as string | null) ?? null,
      }))
    : []
  const regions = Array.isArray(raw.regions)
    ? (raw.regions as unknown[]).map((r) => String(r))
    : []
  return {
    hosts,
    host_count: Number(raw.host_count ?? 0),
    portal_count: Number(raw.portal_count ?? 0),
    regions,
  }
}

export async function fetchPoolHostPortals(
  host: string,
  opts: Omit<PoolFilterParams, 'sort' | 'dir' | 'limit' | 'offset'>,
): Promise<PoolCand[]> {
  const { data, error } = await adminDb.rpc('admin_iptv_pool_host_portals', {
    p_host: poolHostKey(host),
    p_q: opts.q?.trim() || null,
    p_inventory: opts.inventory ?? 'all',
    p_platform: opts.platform ?? 'all',
    p_status: opts.status ?? 'all',
    p_region: opts.region ?? 'all',
  })
  if (error) throw new Error(errMessage(error, 'Pool portals failed'))
  return (Array.isArray(data) ? data : []) as PoolCand[]
}

export async function fetchPoolPortalById(
  id: string,
): Promise<PoolCand | null> {
  const { data, error } = await adminDb
    .from('iptv_portals')
    .select(
      'id, url, username, alive, expiry, max_connections, region_primary, dealt_count, catalog_pool, platform, updated_at, created_at, last_scraped_at',
    )
    .eq('id', id)
    .maybeSingle()
  if (error) throw new Error(errMessage(error, 'Portal fetch failed'))
  return data ? (data as PoolCand) : null
}

/** Resolve deep-ref → pool focus when portal_id is stale/orphaned. */
export async function resolvePoolFocusPortalId(opts: {
  portal?: string
  url?: string
  user?: string
}): Promise<string | null> {
  const portalId = opts.portal?.trim()
  if (portalId) {
    const { data: direct } = await adminDb
      .from('iptv_portals')
      .select('id')
      .eq('id', portalId)
      .maybeSingle()
    if (direct?.id) return String(direct.id)
  }

  let url = opts.url?.trim() ?? ''
  let user = opts.user?.trim() ?? ''
  if ((!url || !user) && portalId) {
    const { data: hit } = await adminDb
      .from('iptv_scrape_deep_ref_portals')
      .select('url, username')
      .eq('portal_id', portalId)
      .limit(1)
      .maybeSingle()
    if (hit) {
      url = String(hit.url ?? '').trim()
      user = String(hit.username ?? '').trim()
    }
  }
  if (!url || !user) return null

  const { data: foundId } = await adminDb.rpc('find_iptv_portal_id', {
    p_url: url,
    p_username: user,
  })
  return typeof foundId === 'string' && foundId ? foundId : null
}

export function candidateHost(url: string): string {
  try {
    const u = new URL(url.includes('://') ? url : `http://${url}`)
    return (u.host || url).toLowerCase()
  } catch {
    return url.toLowerCase()
  }
}
