import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type {
  CatalogPortal,
  DeepRefRecord,
  PendingDeepRefRow,
  PortalStatus,
  RegionGuess,
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
  const { data, error } = await sb
    .from('iptv_scrape_deep_refs')
    .upsert(
      {
        post_id: ref.postId,
        scrape_run_id: scrapeRunId,
        base64: ref.base64,
        paste_url: ref.pasteUrl,
        paste_body: ref.pasteBody,
        payload_hash: ref.payloadHash,
        ref_host: ref.refHost,
        fetch_ok: ref.fetchOk,
        extract_count: ref.extractCount,
        needs_recheck: ref.needsRecheck,
      },
      { onConflict: 'post_id,payload_hash' },
    )
    .select('id')
    .single()
  if (error) throw error
  const deepRefId = data.id as string

  if (!linkPortals) return deepRefId

  const { error: delErr } = await sb
    .from('iptv_scrape_deep_ref_portals')
    .delete()
    .eq('deep_ref_id', deepRefId)
  if (delErr) throw delErr

  for (const hit of ref.portals ?? []) {
    let portalId: string | null = null
    let wasExisting = false

    if (hit.username && (hit.password || hit.platform === 'stalker')) {
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
        postId: ref.postId,
        expiry: hit.expiry ?? null,
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
          // Never set alive from the note — player_api still owns that.
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
    })
    if (hitErr) throw hitErr
  }

  return deepRefId
}

/** Deep refs for this run that still need paste fetch and/or portal extract. */
export async function listPendingDeepRefsForRun(
  sb: SupabaseClient,
  scrapeRunId: string,
): Promise<PendingDeepRefRow[]> {
  const { data, error } = await sb
    .from('iptv_scrape_deep_refs')
    .select(
      'id, post_id, base64, paste_url, paste_body, payload_hash, ref_host, fetch_ok, extract_count',
    )
    .eq('scrape_run_id', scrapeRunId)
    .order('created_at', { ascending: true })
  if (error) throw error
  return ((data ?? []) as PendingDeepRefRow[]).filter((r) => {
    const pasteUrl = String(r.paste_url ?? '').trim()
    const body = r.paste_body
    const fetchOk = r.fetch_ok
    const extractCount = Number(r.extract_count ?? 0)
    // Paste URL collected but not fetched yet.
    if (pasteUrl && fetchOk == null) return true
    // Inline body collected; extract not run (fetch_ok still null).
    if (!pasteUrl && body && fetchOk == null && extractCount === 0) return true
    return false
  })
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
