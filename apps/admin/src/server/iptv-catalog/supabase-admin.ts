import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type { CatalogPortal, PortalStatus, RegionGuess } from './types'

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

/** Daily cron gate — false skips scheduled runs; manual scrape still runs. */
export async function isScrapeCronEnabled(
  sb: SupabaseClient,
): Promise<boolean> {
  const { data, error } = await sb
    .from('iptv_ops_settings')
    .select('scrape_cron_enabled')
    .eq('id', 1)
    .maybeSingle()
  if (error) throw error
  return data?.scrape_cron_enabled !== false
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

/** Persist Reddit post_id only — never title / body_excerpt. */
export async function upsertScrapePostId(
  sb: SupabaseClient,
  postId: string,
  scrapeRunId: string,
  subreddit = '',
): Promise<void> {
  const id = postId.trim()
  if (!id) return
  const { error } = await sb.from('iptv_scrape_posts').upsert(
    {
      post_id: id,
      subreddit,
      scrape_run_id: scrapeRunId,
    },
    { onConflict: 'post_id' },
  )
  if (error) throw error
}

export async function upsertCatalogCandidate(
  sb: SupabaseClient,
  portal: CatalogPortal,
  status: PortalStatus,
  region: RegionGuess,
): Promise<void> {
  const { error } = await sb.rpc('upsert_iptv_catalog_candidate', {
    p_url: portal.url,
    p_username: portal.username,
    p_password: portal.password,
    p_source: portal.source || 'catalog',
    p_layer: 'l1',
    p_alive: status.alive,
    p_expiry: status.expiry,
    p_max_connections: status.maxConnections,
    p_timezone: status.timezone,
    p_region_primary: region.primary,
    p_post_id: portal.postId?.trim() || null,
    p_region_tags: region.tags,
    p_region_confidence: region.confidence,
  })
  if (error) throw error
}
