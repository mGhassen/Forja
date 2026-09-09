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
