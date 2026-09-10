import { supabase, supabaseConfigured } from '@/lib/supabase'

export type ForjaPluginCatalogEntry = {
  id: string
  kind: string
  name: string
  description: string
  accent: 'brand' | 'flame'
  /** Curated ForjaHQ packs in this catalog. Community entries omit or set false. */
  official?: boolean
  /** Soft CTA — Recommended badge on core ForjaHQ packs. */
  recommended?: boolean
  author?: string
  version?: string
  pluginCount?: number
  /** Topic tags for filters (anime, arabic, kids, …). */
  tags?: string[]
}

export type ForjaPluginPackLive = ForjaPluginCatalogEntry & {
  /** Install source — internal only; never render or copy in UI. */
  manifestUrl: string
}

/** Admin-published product set (ordered packs). Not a row in the pack table. */
export type ForjaPluginBundleMeta = {
  id: string
  name: string
  description: string
  recommended: boolean
  sortOrder: number
  packIds: string[]
}

export type ForjaPluginBundleLive = ForjaPluginBundleMeta & {
  /** Published packs in bundle order (missing catalog ids omitted). */
  packs: ForjaPluginPackLive[]
}

export function pluginKindLabel(kind: string): string {
  const trimmed = kind.trim()
  if (!trimmed) return 'Pack'
  return trimmed
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())
}

export function pluginTagLabel(tag: string): string {
  return pluginKindLabel(tag)
}

export function pluginKindsFromPacks(packs: ForjaPluginPackLive[]): string[] {
  const kinds = [...new Set(packs.map((pack) => pack.kind.trim()).filter(Boolean))]
  return kinds.sort((a, b) => pluginKindLabel(a).localeCompare(pluginKindLabel(b)))
}

export function pluginTagsFromPacks(packs: ForjaPluginPackLive[]): string[] {
  const tags = new Set<string>()
  for (const pack of packs) {
    for (const tag of pack.tags ?? []) {
      const trimmed = tag.trim()
      if (trimmed) tags.add(trimmed)
    }
  }
  return [...tags].sort((a, b) => pluginTagLabel(a).localeCompare(pluginTagLabel(b)))
}

export function packHasTag(pack: ForjaPluginPackLive, tag: string): boolean {
  const want = tag.trim().toLowerCase()
  if (!want) return false
  return (pack.tags ?? []).some((t) => t.trim().toLowerCase() === want)
}

export function isOfficialPluginPack(pack: ForjaPluginPackLive): boolean {
  return pack.official === true
}

export function isRecommendedPluginPack(pack: ForjaPluginPackLive): boolean {
  return pack.recommended === true
}

export function packAuthorLabel(pack: ForjaPluginPackLive): string | undefined {
  const author = pack.author?.trim()
  return author || undefined
}

function rowToLivePack(row: {
  id: string | null
  kind: string | null
  name: string | null
  description: string | null
  accent: string | null
  official: boolean | null
  recommended: boolean | null
  author: string | null
  cached_version: string | null
  plugin_count: number | null
  tags: string[] | null
  manifest_url: string | null
}): ForjaPluginPackLive | null {
  const id = row.id?.trim()
  const manifestUrl = row.manifest_url?.trim()
  const name = row.name?.trim()
  if (!id || !manifestUrl || !name) return null
  const accent = row.accent === 'flame' ? 'flame' : 'brand'
  return {
    id,
    kind: row.kind?.trim() || 'providers',
    name,
    description: row.description ?? '',
    accent,
    official: row.official === true,
    recommended: row.recommended === true,
    author: row.author ?? undefined,
    version: row.cached_version ?? undefined,
    pluginCount: row.plugin_count ?? undefined,
    tags: row.tags ?? [],
    manifestUrl,
  }
}

/** Published packs from admin / Supabase (RFC-100). Empty list when none published. */
export async function fetchPublishedPluginPacksFromSupabase(): Promise<
  ForjaPluginPackLive[]
> {
  if (!supabaseConfigured) {
    throw new Error('Plugin catalog requires Supabase.')
  }
  const { data, error } = await supabase
    .from('plugin_packs')
    .select(
      'id, kind, name, description, accent, official, recommended, author, cached_version, plugin_count, tags, manifest_url, sort_order',
    )
    .eq('published', true)
    .order('sort_order', { ascending: true })
    .order('id', { ascending: true })
  if (error) {
    throw new Error(error.message || 'Could not load published packs.')
  }
  const packs: ForjaPluginPackLive[] = []
  for (const row of data ?? []) {
    const pack = rowToLivePack(row)
    if (pack) packs.push(pack)
  }
  return packs
}

/** Community Packs UI — admin-published packs only. */
export async function loadLivePluginCatalog(): Promise<ForjaPluginPackLive[]> {
  return fetchPublishedPluginPacksFromSupabase()
}

/** Published product bundles from admin (metadata + ordered pack ids). */
export async function fetchPublishedPluginBundlesFromSupabase(): Promise<
  ForjaPluginBundleMeta[]
> {
  if (!supabaseConfigured) {
    throw new Error('Plugin catalog requires Supabase.')
  }
  const { data: bundles, error: bErr } = await supabase
    .from('plugin_bundles')
    .select('id, name, description, recommended, sort_order')
    .eq('published', true)
    .order('sort_order', { ascending: true })
    .order('id', { ascending: true })
  if (bErr) {
    throw new Error(bErr.message || 'Could not load published bundles.')
  }
  if (!bundles?.length) return []

  const { data: items, error: iErr } = await supabase
    .from('plugin_bundle_items')
    .select('bundle_id, pack_id, sort_order')
    .order('sort_order', { ascending: true })
  if (iErr) {
    throw new Error(iErr.message || 'Could not load bundle items.')
  }

  const byBundle = new Map<string, Array<{ packId: string; sort: number }>>()
  for (const row of items ?? []) {
    const bid = row.bundle_id?.trim()
    const pid = row.pack_id?.trim()
    if (!bid || !pid) continue
    const list = byBundle.get(bid) ?? []
    list.push({ packId: pid, sort: row.sort_order ?? 0 })
    byBundle.set(bid, list)
  }

  const out: ForjaPluginBundleMeta[] = []
  for (const row of bundles) {
    const id = row.id?.trim()
    const name = row.name?.trim()
    if (!id || !name) continue
    const ordered = [...(byBundle.get(id) ?? [])].sort(
      (a, b) => a.sort - b.sort,
    )
    out.push({
      id,
      name,
      description: row.description ?? '',
      recommended: row.recommended === true,
      sortOrder: row.sort_order ?? 0,
      packIds: ordered.map((p) => p.packId),
    })
  }
  return out
}

/** Join bundle pack ids to live catalog packs (order preserved). */
export function hydratePluginBundles(
  bundles: ForjaPluginBundleMeta[],
  packs: ForjaPluginPackLive[],
): ForjaPluginBundleLive[] {
  const byId = new Map(packs.map((p) => [p.id, p]))
  const hydrated: ForjaPluginBundleLive[] = []
  for (const bundle of bundles) {
    const resolved: ForjaPluginPackLive[] = []
    for (const packId of bundle.packIds) {
      const hit = byId.get(packId)
      if (hit) resolved.push(hit)
    }
    if (resolved.length === 0) continue
    hydrated.push({ ...bundle, packs: resolved })
  }
  return hydrated.sort((a, b) => {
    const byRec = (b.recommended ? 1 : 0) - (a.recommended ? 1 : 0)
    if (byRec !== 0) return byRec
    if (a.sortOrder !== b.sortOrder) return a.sortOrder - b.sortOrder
    return a.name.localeCompare(b.name)
  })
}

export function groupPluginPacksByKind(
  packs: ForjaPluginPackLive[],
): Array<{ kind: string; label: string; packs: ForjaPluginPackLive[] }> {
  const byKind = new Map<string, ForjaPluginPackLive[]>()
  for (const pack of packs) {
    const list = byKind.get(pack.kind) ?? []
    list.push(pack)
    byKind.set(pack.kind, list)
  }
  return pluginKindsFromPacks(packs).map((kind) => ({
    kind,
    label: pluginKindLabel(kind),
    packs: byKind.get(kind) ?? [],
  }))
}
