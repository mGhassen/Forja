export type ForjaPluginCatalogEntry = {
  id: string
  kind: string
  manifestPath: string
  name: string
  description: string
  accent: 'brand' | 'flame'
  /** Curated ForjaHQ packs in this catalog. Community entries omit or set false. */
  official?: boolean
  author?: string
}

export type ForjaPluginCatalog = {
  schema: number
  baseUrl: string
  packs: ForjaPluginCatalogEntry[]
}

export type ForjaPluginManifest = {
  schema?: number
  id?: string
  name?: string
  version?: string
  plugins?: unknown[]
}

export type ForjaPluginPackLive = ForjaPluginCatalogEntry & {
  manifestUrl: string
  version?: string
  pluginCount?: number
}

const DEFAULT_CATALOG_BASE =
  'https://raw.githubusercontent.com/mGhassen/Forja/main/plugins'

export function pluginKindLabel(kind: string): string {
  const trimmed = kind.trim()
  if (!trimmed) return 'Pack'
  return trimmed
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())
}

export function pluginKindsFromPacks(packs: ForjaPluginPackLive[]): string[] {
  const kinds = [...new Set(packs.map((pack) => pack.kind.trim()).filter(Boolean))]
  return kinds.sort((a, b) => pluginKindLabel(a).localeCompare(pluginKindLabel(b)))
}

export function isOfficialPluginPack(pack: ForjaPluginPackLive): boolean {
  return pack.official === true
}

export function packAuthorLabel(pack: ForjaPluginPackLive): string | undefined {
  const author = pack.author?.trim()
  return author || undefined
}

export function resolvePluginManifestUrl(
  entry: ForjaPluginCatalogEntry,
  baseUrl = DEFAULT_CATALOG_BASE,
): string {
  const base = baseUrl.replace(/\/$/, '')
  const path = entry.manifestPath.replace(/^\//, '')
  return `${base}/${path}`
}

export async function fetchPluginCatalog(): Promise<ForjaPluginCatalog> {
  const res = await fetch('/plugins/catalog.json', { cache: 'no-store' })
  if (!res.ok) {
    throw new Error('Could not load plugin catalog.')
  }
  const data = (await res.json()) as ForjaPluginCatalog
  if (!Array.isArray(data.packs) || !data.baseUrl?.trim()) {
    throw new Error('Plugin catalog is invalid.')
  }
  return data
}

export async function fetchPluginManifest(
  manifestUrl: string,
): Promise<ForjaPluginManifest> {
  const res = await fetch(manifestUrl, { cache: 'no-store' })
  if (!res.ok) {
    throw new Error(`Could not load manifest (${res.status}).`)
  }
  return (await res.json()) as ForjaPluginManifest
}

export async function hydratePluginPack(
  entry: ForjaPluginCatalogEntry,
  baseUrl: string,
): Promise<ForjaPluginPackLive> {
  const manifestUrl = resolvePluginManifestUrl(entry, baseUrl)
  try {
    const manifest = await fetchPluginManifest(manifestUrl)
    return {
      ...entry,
      manifestUrl,
      version: manifest.version?.trim() || undefined,
      pluginCount: Array.isArray(manifest.plugins)
        ? manifest.plugins.length
        : undefined,
      name: manifest.name?.trim() || entry.name,
    }
  } catch {
    return { ...entry, manifestUrl }
  }
}

export async function hydratePluginCatalog(
  catalog: ForjaPluginCatalog,
): Promise<ForjaPluginPackLive[]> {
  const packs = await Promise.all(
    catalog.packs.map((entry) => hydratePluginPack(entry, catalog.baseUrl)),
  )
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
