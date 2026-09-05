import { PLUGIN_PACK_SOURCES } from '@/lib/generated/plugin-pack-sources'

export type ForjaPluginCatalogEntry = {
  id: string
  kind: string
  name: string
  description: string
  accent: 'brand' | 'flame'
  /** Curated ForjaHQ packs in this catalog. Community entries omit or set false. */
  official?: boolean
  author?: string
  version?: string
  pluginCount?: number
  /** Topic tags for filters (anime, arabic, kids, …). */
  tags?: string[]
}

export type ForjaPluginCatalog = {
  schema: number
  packs: ForjaPluginCatalogEntry[]
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

export function packAuthorLabel(pack: ForjaPluginPackLive): string | undefined {
  const author = pack.author?.trim()
  return author || undefined
}

export async function fetchPluginCatalog(): Promise<ForjaPluginCatalog> {
  const res = await fetch('/plugins/catalog.json', { cache: 'no-store' })
  if (!res.ok) {
    throw new Error('Could not load plugin catalog.')
  }
  const data = (await res.json()) as ForjaPluginCatalog
  if (!Array.isArray(data.packs)) {
    throw new Error('Plugin catalog is invalid.')
  }
  return data
}

/** Attach install URLs from the generated source map (no remote manifest fetch). */
export function hydratePluginCatalog(
  catalog: ForjaPluginCatalog,
): ForjaPluginPackLive[] {
  const packs: ForjaPluginPackLive[] = []
  for (const entry of catalog.packs) {
    const manifestUrl = PLUGIN_PACK_SOURCES[entry.id]?.trim()
    if (!manifestUrl) continue
    packs.push({ ...entry, manifestUrl })
  }
  return packs
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
