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
  /** Latest scrape deep ref that promoted this portal (junction). */
  deep_ref_id: string | null
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

export type PoolHostPortalsResult = {
  portals: PoolCand[]
  total: number
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

/** PostgREST `.in()` is a GET query string — keep chunks under URL limits. */
const DEEP_REF_IN_CHUNK = 80

/** Latest deep_ref_id per portal from junction (created_at desc). */
async function attachDeepRefIds(
  portals: Omit<PoolCand, 'deep_ref_id'>[],
): Promise<PoolCand[]> {
  if (portals.length === 0) return []
  const ids = portals.map((p) => p.id)
  const map = new Map<string, string>()
  for (let i = 0; i < ids.length; i += DEEP_REF_IN_CHUNK) {
    const chunk = ids.slice(i, i + DEEP_REF_IN_CHUNK)
    const { data, error } = await adminDb
      .from('iptv_scrape_deep_ref_portals')
      .select('portal_id, deep_ref_id, created_at')
      .in('portal_id', chunk)
      .order('created_at', { ascending: false })
    if (error) throw new Error(errMessage(error, 'Deep ref lookup failed'))
    for (const row of data ?? []) {
      const portalId = String(
        (row as { portal_id?: string }).portal_id ?? '',
      ).trim()
      const deepRefId = String(
        (row as { deep_ref_id?: string }).deep_ref_id ?? '',
      ).trim()
      if (!portalId || !deepRefId || map.has(portalId)) continue
      map.set(portalId, deepRefId)
    }
  }
  return portals.map((p) => ({
    ...p,
    deep_ref_id: map.get(p.id) ?? null,
  }))
}

export async function fetchPoolHostPortals(
  host: string,
  opts: Omit<PoolFilterParams, 'sort' | 'dir'> & {
    limit?: number
    offset?: number
  },
): Promise<PoolHostPortalsResult> {
  const { data, error } = await adminDb.rpc('admin_iptv_pool_host_portals', {
    p_host: poolHostKey(host),
    p_q: opts.q?.trim() || null,
    p_inventory: opts.inventory ?? 'all',
    p_platform: opts.platform ?? 'all',
    p_status: opts.status ?? 'all',
    p_region: opts.region ?? 'all',
    p_limit: opts.limit ?? 50,
    p_offset: opts.offset ?? 0,
  })
  if (error) throw new Error(errMessage(error, 'Pool portals failed'))
  const raw = (data ?? {}) as Record<string, unknown>
  // New shape: { portals, total }. Old RPC returned a bare array.
  const list = Array.isArray(raw.portals)
    ? raw.portals
    : Array.isArray(data)
      ? data
      : []
  const rows = list as PoolCand[]
  const needsDeepRef = rows.some((r) => r.deep_ref_id === undefined)
  const portals = needsDeepRef
    ? await attachDeepRefIds(rows as Omit<PoolCand, 'deep_ref_id'>[])
    : rows.map((r) => ({
        ...r,
        deep_ref_id: r.deep_ref_id ?? null,
      }))
  return {
    portals,
    total: Number(raw.total ?? portals.length),
  }
}

const POOL_PORTAL_COLS =
  'id, url, username, alive, expiry, max_connections, region_primary, dealt_count, catalog_pool, platform, updated_at, created_at, last_scraped_at'

export async function fetchPoolPortalById(
  id: string,
): Promise<PoolCand | null> {
  const { data, error } = await adminDb
    .from('iptv_portals')
    .select(POOL_PORTAL_COLS)
    .eq('id', id)
    .maybeSingle()
  if (error) throw new Error(errMessage(error, 'Portal fetch failed'))
  if (!data) return null
  const [withRef] = await attachDeepRefIds([
    data as Omit<PoolCand, 'deep_ref_id'>,
  ])
  return withRef ?? null
}

/** Post-verify hydrate — expiry/seats from DB (skip deep_ref; cache keeps it). */
export async function fetchPoolPortalStatusByIds(
  ids: string[],
): Promise<
  Pick<
    PoolCand,
    'id' | 'alive' | 'expiry' | 'max_connections' | 'region_primary'
  >[]
> {
  const uniq = [...new Set(ids.map((id) => id.trim()).filter(Boolean))]
  if (uniq.length === 0) return []
  const { data, error } = await adminDb
    .from('iptv_portals')
    .select('id, alive, expiry, max_connections, region_primary')
    .in('id', uniq)
  if (error) throw new Error(errMessage(error, 'Portal status fetch failed'))
  return (data ?? []).map((row) => ({
    id: String((row as { id: string }).id),
    alive: (row as { alive: boolean | null }).alive,
    expiry: ((row as { expiry?: string | null }).expiry as string | null) ?? null,
    max_connections:
      ((row as { max_connections?: string | null }).max_connections as
        | string
        | null) ?? null,
    region_primary: String(
      (row as { region_primary?: string }).region_primary ?? 'UNKNOWN',
    ),
  }))
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
