import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import {
  dedupeDeepRefPortalHits,
  type CatalogPortal,
  type DeepRefRecord,
  type PendingDeepRefRow,
  type PortalStatus,
  type RegionGuess,
} from './types'

/** Service-role client — server / Inngest only. Never expose to the browser. */
export function createCatalogAdminClient(): SupabaseClient {
  const url =
    process.env.SUPABASE_URL?.trim() ||
    process.env.VITE_SUPABASE_URL?.trim() ||
    ''
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim() || ''
  if (!url) throw new Error('SUPABASE_URL (or VITE_SUPABASE_URL) required')
  if (!key) throw new Error('SUPABASE_SERVICE_ROLE_KEY required')
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
}

export type ScrapeCronSettings = {
  enabled: boolean
  /** 5-field UTC cron; default daily 06:00. */
  cron: string
}

/** Cron gate + expression — false skips scheduled ticks; manual scrape still runs. */
export async function getScrapeCronSettings(
  sb: SupabaseClient,
): Promise<ScrapeCronSettings> {
  const { data, error } = await sb
    .from('iptv_ops_settings')
    .select('scrape_cron_enabled, scrape_cron')
    .eq('id', 1)
    .maybeSingle()
  if (error) throw error
  return {
    enabled: data?.scrape_cron_enabled !== false,
    cron:
      typeof data?.scrape_cron === 'string' && data.scrape_cron.trim()
        ? data.scrape_cron.trim()
        : '0 6 * * *',
  }
}

/** Latest scheduled scrape start (for cron due / catch-up watermark). */
export async function getLastScheduledScrapeStartedAt(
  sb: SupabaseClient,
): Promise<Date | null> {
  const { data, error } = await sb
    .from('iptv_scrape_runs')
    .select('started_at')
    .eq('source', 'inngest-cron')
    .order('started_at', { ascending: false })
    .limit(1)
    .maybeSingle()
  if (error) throw error
  if (!data?.started_at) return null
  const at = new Date(String(data.started_at))
  return Number.isNaN(at.getTime()) ? null : at
}

export async function insertScrapeRun(
  sb: SupabaseClient,
  source = 'inngest-admin',
): Promise<string> {
  const { data, error } = await sb
    .from('iptv_scrape_runs')
    .insert({ status: 'running', source, posts_seen: 0 })
    .select('id')
    .single()
  if (error) throw error
  return data.id as string
}

export async function patchScrapeRun(
  sb: SupabaseClient,
  id: string,
  patch: Record<string, unknown>,
): Promise<void> {
  const { error } = await sb.from('iptv_scrape_runs').update(patch).eq('id', id)
  if (error) throw error
}

/** All known Reddit post ids — watermark so we only process newer posts. */
export async function loadKnownScrapePostIds(
  sb: SupabaseClient,
): Promise<Set<string>> {
  const ids = new Set<string>()
  const pageSize = 1000
  let from = 0
  for (;;) {
    const { data, error } = await sb
      .from('iptv_scrape_posts')
      .select('post_id')
      .range(from, from + pageSize - 1)
    if (error) throw error
    const rows = data ?? []
    for (const row of rows) {
      const id = String(row.post_id ?? '').trim()
      if (id) ids.add(id)
    }
    if (rows.length < pageSize) break
    from += pageSize
  }
  return ids
}

/** Persist Reddit post_id + subreddit — never title / body_excerpt. */
export async function upsertScrapePostId(
  sb: SupabaseClient,
  postId: string,
  scrapeRunId: string,
  subreddit: string,
): Promise<void> {
  const id = postId.trim()
  if (!id) return
  const sub = subreddit.trim() || 'IPTV_ZONENEW'
  const { error } = await sb.from('iptv_scrape_posts').upsert(
    {
      post_id: id,
      subreddit: sub,
      scrape_run_id: scrapeRunId,
    },
    { onConflict: 'post_id' },
  )
  if (error) throw error
}

export async function upsertScrapeDeepRef(
  sb: SupabaseClient,
  ref: DeepRefRecord,
  scrapeRunId: string,
  opts?: { linkPortals?: boolean },
): Promise<string> {
  const linkPortals = opts?.linkPortals !== false
  const baseRow = {
    post_id: ref.postId,
    scrape_run_id: scrapeRunId,
    base64: ref.base64,
    paste_url: ref.pasteUrl,
    payload_hash: ref.payloadHash,
    ref_host: ref.refHost,
    fetch_ok: ref.fetchOk,
    extract_count: ref.extractCount,
    needs_recheck: ref.needsRecheck,
  }
  // Force-full / watermark re-hit keeps created_at; bump updated_at for admin sort.
  let { data, error } = await sb
    .from('iptv_scrape_deep_refs')
    .upsert(
      { ...baseRow, updated_at: new Date().toISOString() },
      { onConflict: 'post_id,payload_hash' },
    )
    .select('id')
    .single()
  if (error && /updated_at/i.test(error.message)) {
    const retry = await sb
      .from('iptv_scrape_deep_refs')
      .upsert(baseRow, { onConflict: 'post_id,payload_hash' })
      .select('id')
      .single()
    data = retry.data
    error = retry.error
  }
  if (error) throw error
  if (!data) throw new Error('deep ref upsert returned no row')
  const deepRefId = data.id as string

  if (linkPortals) {
    await linkScrapeDeepRefPortals(sb, deepRefId, ref)
  }

  return deepRefId
}

const PORTAL_INSERT_CHUNK = 80

export function canPromoteHit(hit: {
  platform: string
  username: string
  password: string
  url: string
}): boolean {
  return (
    (hit.platform === 'm3u' &&
      hit.username === '__m3u__' &&
      Boolean(hit.url)) ||
    (Boolean(hit.username) &&
      (Boolean(hit.password) || hit.platform === 'stalker'))
  )
}

/**
 * Claim next eligible junction ids with portal_id null (promote gate).
 * Always start from the front — promoted rows drop out of the null set.
 * Offset only skips permanently ineligible null rows.
 */
export async function claimEligibleUnpromotedPortalIds(
  sb: SupabaseClient,
  limit: number,
): Promise<string[]> {
  const want = Math.max(0, Math.floor(limit))
  if (want === 0) return []

  const ids: string[] = []
  let offset = 0
  const pageSize = Math.max(want * 4, 50)

  while (ids.length < want) {
    const to = offset + pageSize - 1
    const { data, error } = await sb
      .from('iptv_scrape_deep_ref_portals')
      .select('id, platform, username, password, url')
      .is('portal_id', null)
      .order('created_at', { ascending: true })
      .order('id', { ascending: true })
      .range(offset, to)
    if (error) throw error
    if (!data?.length) break

    for (const row of data) {
      if (
        canPromoteHit({
          platform: String(row.platform ?? ''),
          username: String(row.username ?? ''),
          password: String(row.password ?? ''),
          url: String(row.url ?? ''),
        })
      ) {
        ids.push(String(row.id))
        if (ids.length >= want) return ids
      }
    }
    if (data.length < pageSize) break
    offset += pageSize
  }
  return ids
}

/** Exact eligible count for admin backfill dialog (paged — PostgREST cap safe). */
export async function countEligibleUnpromotedPortals(
  sb: SupabaseClient,
): Promise<number> {
  const pageSize = 500
  let offset = 0
  let count = 0
  for (;;) {
    const to = offset + pageSize - 1
    const { data, error } = await sb
      .from('iptv_scrape_deep_ref_portals')
      .select('platform, username, password, url')
      .is('portal_id', null)
      .order('created_at', { ascending: true })
      .order('id', { ascending: true })
      .range(offset, to)
    if (error) throw error
    if (!data?.length) break
    for (const row of data) {
      if (
        canPromoteHit({
          platform: String(row.platform ?? ''),
          username: String(row.username ?? ''),
          password: String(row.password ?? ''),
          url: String(row.url ?? ''),
        })
      ) {
        count++
      }
    }
    if (data.length < pageSize) break
    offset += pageSize
  }
  return count
}

/**
 * Bulk-write junction rows — no per-hit RPCs.
 * was_existing / portal_id filled later in catalog upsert chunks.
 * Safe inside process step: fat portal lists stay in DB, not Inngest memo.
 */
export async function insertScrapeDeepRefPortalsBulk(
  sb: SupabaseClient,
  deepRefId: string,
  hits: DeepRefRecord['portals'],
): Promise<number> {
  const { error: delErr } = await sb
    .from('iptv_scrape_deep_ref_portals')
    .delete()
    .eq('deep_ref_id', deepRefId)
  if (delErr) throw delErr

  const deduped = dedupeDeepRefPortalHits(hits ?? [])
  for (let i = 0; i < deduped.length; i += PORTAL_INSERT_CHUNK) {
    const chunk = deduped.slice(i, i + PORTAL_INSERT_CHUNK).map((hit) => ({
      deep_ref_id: deepRefId,
      platform: hit.platform,
      type: hit.type,
      output: hit.output || hit.allowedOutputs || '',
      url: hit.url,
      username: hit.username,
      password: hit.password,
      was_existing: false,
      portal_id: null as string | null,
      expiry: hit.expiry ?? null,
      note: hit.note ?? null,
      max_connections: hit.maxConnections ?? null,
      timezone: hit.timezone ?? null,
      region_primary: hit.regionPrimary ?? null,
      region_tags: hit.regionTags ?? [],
      region_confidence: hit.regionConfidence ?? 0,
    }))
    const { error: hitErr } = await sb
      .from('iptv_scrape_deep_ref_portals')
      .insert(chunk)
    if (hitErr) throw hitErr
  }
  return deduped.length
}

/**
 * Write `iptv_scrape_deep_ref_portals` (+ optional catalog promote).
 * Prefer insertScrapeDeepRefPortalsBulk from scrape — this path still does
 * N find/upsert RPCs and must not run inside a fat Inngest step.
 */
export async function linkScrapeDeepRefPortals(
  sb: SupabaseClient,
  deepRefId: string,
  ref: DeepRefRecord,
  opts?: { promoteCatalog?: boolean },
): Promise<number> {
  const promoteCatalog = opts?.promoteCatalog !== false
  if (!promoteCatalog) {
    return insertScrapeDeepRefPortalsBulk(sb, deepRefId, ref.portals)
  }

  const { error: delErr } = await sb
    .from('iptv_scrape_deep_ref_portals')
    .delete()
    .eq('deep_ref_id', deepRefId)
  if (delErr) throw delErr

  const hits = dedupeDeepRefPortalHits(ref.portals ?? [])
  for (const hit of hits) {
    let portalId: string | null = null
    let wasExisting = false

    if (canPromoteHit(hit)) {
      const { data: existingId, error: findErr } = await sb.rpc(
        'find_iptv_portal_id',
        { p_url: hit.url, p_username: hit.username },
      )
      if (findErr) throw findErr
      wasExisting = Boolean(existingId)

      const portal: CatalogPortal = {
        url: hit.url,
        username: hit.username,
        password: hit.password || '',
        source: ref.pasteUrl ? 'catalog-deep' : 'catalog-decoded',
        platform: hit.platform,
        postId: ref.postId,
        expiry: hit.expiry ?? null,
        note: hit.note ?? null,
        maxConnections: hit.maxConnections ?? null,
        timezone: hit.timezone ?? null,
        regionPrimary: hit.regionPrimary,
        regionTags: hit.regionTags,
        regionConfidence: hit.regionConfidence,
        allowedOutputs: hit.allowedOutputs ?? null,
      }
      portalId = await upsertCatalogCandidateReturningId(
        sb,
        portal,
        {
          alive: null,
          status: 'unverified',
          expiry: hit.expiry ?? null,
          maxConnections: hit.maxConnections ?? null,
          timezone: hit.timezone ?? null,
          categoryNames: [],
        },
        {
          primary: hit.regionPrimary ?? 'UNKNOWN',
          tags: hit.regionTags ?? [],
          confidence: hit.regionConfidence ?? 0,
        },
      )
    }

    const { error: hitErr } = await sb.from('iptv_scrape_deep_ref_portals').insert({
      deep_ref_id: deepRefId,
      platform: hit.platform,
      type: hit.type,
      output: hit.output || hit.allowedOutputs || '',
      url: hit.url,
      username: hit.username,
      password: hit.password,
      was_existing: wasExisting,
      portal_id: portalId,
      expiry: hit.expiry ?? null,
      note: hit.note ?? null,
      max_connections: hit.maxConnections ?? null,
      timezone: hit.timezone ?? null,
      region_primary: hit.regionPrimary ?? null,
      region_tags: hit.regionTags ?? [],
      region_confidence: hit.regionConfidence ?? 0,
    })
    if (hitErr) throw hitErr
  }

  return hits.length
}

/**
 * One page of junction row ids for a scrape run.
 * Prefer this inside promote steps — never memoize the full id list.
 */
export async function listDeepRefPortalIdsPage(
  sb: SupabaseClient,
  scrapeRunId: string,
  offset: number,
  limit: number,
): Promise<string[]> {
  if (limit <= 0) return []
  const from = Math.max(0, Math.floor(offset))
  const to = from + Math.max(1, Math.floor(limit)) - 1
  const { data, error } = await sb
    .from('iptv_scrape_deep_ref_portals')
    .select('id, iptv_scrape_deep_refs!inner(scrape_run_id)')
    .eq('iptv_scrape_deep_refs.scrape_run_id', scrapeRunId)
    .order('created_at', { ascending: true })
    .range(from, to)
  if (error) throw error
  return (data ?? [])
    .map((row) => String(row.id ?? '').trim())
    .filter(Boolean)
}

/** @deprecated Prefer listDeepRefPortalIdsPage inside each promote step. */
export async function listDeepRefPortalIdsForRun(
  sb: SupabaseClient,
  scrapeRunId: string,
): Promise<string[]> {
  const ids: string[] = []
  const pageSize = 200
  for (let offset = 0; ; offset += pageSize) {
    const page = await listDeepRefPortalIdsPage(
      sb,
      scrapeRunId,
      offset,
      pageSize,
    )
    ids.push(...page)
    if (page.length < pageSize) break
  }
  return ids
}

type DeepRefPortalPromoteRow = {
  id: string
  url: string
  username: string
  password: string
  platform: 'xtream' | 'm3u' | 'stalker'
  type: string
  output: string
  paste_url: string
  post_id: string
  expiry: string | null
  note: string | null
  maxConnections: string | null
  timezone: string | null
  regionPrimary: string | null
  regionTags: string[]
  regionConfidence: number
}

/** Load junction rows by id + parent deep_ref fields for catalog promote. */
export async function getDeepRefPortalsForPromote(
  sb: SupabaseClient,
  portalRowIds: string[],
): Promise<DeepRefPortalPromoteRow[]> {
  if (portalRowIds.length === 0) return []
  const { data, error } = await sb
    .from('iptv_scrape_deep_ref_portals')
    .select(
      'id, url, username, password, platform, type, output, expiry, note, max_connections, timezone, region_primary, region_tags, region_confidence, iptv_scrape_deep_refs!inner(post_id, paste_url)',
    )
    .in('id', portalRowIds)
  if (error) throw error

  const out: DeepRefPortalPromoteRow[] = []
  for (const row of data ?? []) {
    const parent = row.iptv_scrape_deep_refs as unknown as {
      post_id?: string
      paste_url?: string
    } | null
    const platform = String(row.platform ?? 'xtream') as
      | 'xtream'
      | 'm3u'
      | 'stalker'
    const tags = Array.isArray(row.region_tags)
      ? (row.region_tags as string[])
      : []
    out.push({
      id: String(row.id),
      url: String(row.url ?? ''),
      username: String(row.username ?? ''),
      password: String(row.password ?? ''),
      platform:
        platform === 'm3u' || platform === 'stalker' ? platform : 'xtream',
      type: String(row.type ?? ''),
      output: String(row.output ?? ''),
      paste_url: String(parent?.paste_url ?? ''),
      post_id: String(parent?.post_id ?? ''),
      expiry: row.expiry != null ? String(row.expiry) : null,
      note: row.note != null ? String(row.note) : null,
      maxConnections:
        row.max_connections != null ? String(row.max_connections) : null,
      timezone: row.timezone != null ? String(row.timezone) : null,
      regionPrimary:
        row.region_primary != null ? String(row.region_primary) : null,
      regionTags: tags,
      regionConfidence: Number(row.region_confidence ?? 0),
    })
  }
  return out
}

/** Promote one junction row → catalog; patch was_existing + portal_id. */
export async function promoteDeepRefPortalRow(
  sb: SupabaseClient,
  row: DeepRefPortalPromoteRow,
): Promise<{ upserted: boolean; wasExisting: boolean }> {
  if (!canPromoteHit(row)) {
    return { upserted: false, wasExisting: false }
  }

  const { data: existingId, error: findErr } = await sb.rpc(
    'find_iptv_portal_id',
    { p_url: row.url, p_username: row.username },
  )
  if (findErr) throw findErr
  const wasExisting = Boolean(existingId)

  const portal: CatalogPortal = {
    url: row.url,
    username: row.username,
    password: row.password || '',
    source: row.paste_url ? 'catalog-deep' : 'catalog-decoded',
    platform: row.platform,
    postId: row.post_id || undefined,
    expiry: row.expiry,
    note: row.note,
    maxConnections: row.maxConnections,
    timezone: row.timezone,
    regionPrimary: row.regionPrimary ?? undefined,
    regionTags: row.regionTags,
    regionConfidence: row.regionConfidence,
    allowedOutputs: row.output || null,
  }
  const portalId = await upsertCatalogCandidateReturningId(
    sb,
    portal,
    {
      alive: null,
      status: 'unverified',
      expiry: row.expiry,
      maxConnections: row.maxConnections,
      timezone: row.timezone,
      categoryNames: [],
    },
    {
      primary: row.regionPrimary ?? 'UNKNOWN',
      tags: row.regionTags,
      confidence: row.regionConfidence,
    },
  )

  const { error: patchErr } = await sb
    .from('iptv_scrape_deep_ref_portals')
    .update({ was_existing: wasExisting, portal_id: portalId })
    .eq('id', row.id)
  if (patchErr) throw patchErr

  return { upserted: true, wasExisting }
}

function isPendingDeepRefRow(r: {
  paste_url?: string | null
  base64?: string | null
  fetch_ok?: boolean | null
  extract_count?: number | null
}): boolean {
  const pasteUrl = String(r.paste_url ?? '').trim()
  const b64 = String(r.base64 ?? '').trim()
  const fetchOk = r.fetch_ok
  const extractCount = Number(r.extract_count ?? 0)
  if (pasteUrl && fetchOk == null) return true
  if (!pasteUrl && b64 && fetchOk == null && extractCount === 0) return true
  return false
}

/**
 * Next pending deep_ref id for this run — claim inside process step.
 * Never ship the full pending id list through Inngest memo.
 */
export async function getNextPendingDeepRefId(
  sb: SupabaseClient,
  scrapeRunId: string,
): Promise<string | null> {
  // fetch_ok IS NULL covers both paste-pending and base64-only pending.
  const { data, error } = await sb
    .from('iptv_scrape_deep_refs')
    .select('id, paste_url, base64, fetch_ok, extract_count')
    .eq('scrape_run_id', scrapeRunId)
    .is('fetch_ok', null)
    .order('created_at', { ascending: true })
    .limit(40)
  if (error) throw error
  for (const row of data ?? []) {
    if (!isPendingDeepRefRow(row)) continue
    const id = String(row.id ?? '').trim()
    if (id) return id
  }
  return null
}

/**
 * Pending deep_ref ids only — never ship paste bodies through Inngest memo.
 * Prefer getNextPendingDeepRefId inside each process step.
 */
export async function listPendingDeepRefIdsForRun(
  sb: SupabaseClient,
  scrapeRunId: string,
): Promise<string[]> {
  const { data, error } = await sb
    .from('iptv_scrape_deep_refs')
    .select('id, paste_url, base64, fetch_ok, extract_count')
    .eq('scrape_run_id', scrapeRunId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return (data ?? [])
    .filter((r) => isPendingDeepRefRow(r))
    .map((r) => String(r.id))
    .filter(Boolean)
}

export async function getDeepRefRowById(
  sb: SupabaseClient,
  id: string,
): Promise<PendingDeepRefRow | null> {
  const { data, error } = await sb
    .from('iptv_scrape_deep_refs')
    .select(
      'id, post_id, base64, paste_url, payload_hash, ref_host, fetch_ok, extract_count',
    )
    .eq('id', id)
    .maybeSingle()
  if (error) throw error
  return (data as PendingDeepRefRow | null) ?? null
}

/** @deprecated Prefer listPendingDeepRefIdsForRun + getDeepRefRowById. */
export async function listPendingDeepRefsForRun(
  sb: SupabaseClient,
  scrapeRunId: string,
): Promise<PendingDeepRefRow[]> {
  const { data, error } = await sb
    .from('iptv_scrape_deep_refs')
    .select(
      'id, post_id, base64, paste_url, payload_hash, ref_host, fetch_ok, extract_count',
    )
    .eq('scrape_run_id', scrapeRunId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return ((data ?? []) as PendingDeepRefRow[]).filter((r) =>
    isPendingDeepRefRow(r),
  )
}

async function upsertCatalogCandidateReturningId(
  sb: SupabaseClient,
  portal: CatalogPortal,
  status: PortalStatus,
  region: RegionGuess,
): Promise<string> {
  const { data, error } = await sb.rpc('upsert_iptv_catalog_candidate', {
    p_url: portal.url,
    p_username: portal.username,
    p_password: portal.password,
    p_source: portal.source || 'catalog',
    p_alive: status.alive,
    p_expiry: status.expiry,
    p_max_connections: status.maxConnections,
    p_timezone: status.timezone,
    p_region_primary: region.primary,
    p_region_tags: region.tags,
    p_region_confidence: region.confidence,
    p_platform: portal.platform ?? 'xtream',
    p_note: portal.note ?? null,
  })
  if (error) throw error
  return data as string
}

export async function upsertCatalogCandidate(
  sb: SupabaseClient,
  portal: CatalogPortal,
  status: PortalStatus,
  region: RegionGuess,
): Promise<void> {
  await upsertCatalogCandidateReturningId(sb, portal, status, region)
}

export type CatalogPortalStatusRow = {
  id: string
  alive: boolean | null
  expiry: string | null
  max_connections: string | null
  region_primary: string | null
}

/** Manual Pool → Check status: update existing row only — never insert / never force catalog_pool. */
export async function updateCatalogPortalStatus(
  sb: SupabaseClient,
  portalId: string,
  status: PortalStatus,
  region: RegionGuess,
): Promise<CatalogPortalStatusRow> {
  const id = portalId.trim()
  if (!id) throw new Error('portal id required')

  const patch: Record<string, unknown> = {
    alive: status.alive === true,
    last_checked_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }
  if (status.expiry != null && status.expiry !== '') {
    patch.expiry = status.expiry
  }
  if (status.maxConnections != null && status.maxConnections !== '') {
    patch.max_connections = status.maxConnections
  }
  if (status.timezone != null && status.timezone !== '') {
    patch.timezone = status.timezone
  }
  if (region.primary && region.primary !== 'UNKNOWN') {
    patch.region_primary = region.primary
  }
  if (region.tags.length > 0) {
    patch.region_tags = region.tags
  }
  if (region.confidence > 0) {
    patch.region_confidence = region.confidence
  }

  const { data, error } = await sb
    .from('iptv_portals')
    .update(patch)
    .eq('id', id)
    .select('id, alive, expiry, max_connections, region_primary')
    .maybeSingle()
  if (error) throw error
  if (!data) throw new Error(`portal not found: ${id}`)
  return {
    id: String(data.id),
    alive: (data.alive as boolean | null) ?? null,
    expiry: (data.expiry as string | null) ?? null,
    max_connections: (data.max_connections as string | null) ?? null,
    region_primary: (data.region_primary as string | null) ?? null,
  }
}
