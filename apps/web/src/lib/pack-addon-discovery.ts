/**
 * Discover pack-contributed Addons buckets (RFC-089) from profile packs —
 * same idea as Flutter `packContributedAddonMetas`.
 */

import type { ForjaPackRow } from '@/lib/sync-domains'
import { hubTabIdFromPackManifestUrl } from '@/lib/sync-domains'

/** Host built-in Addons ids — packs inject into these, they do not invent rows. */
export const HOST_ADDON_IDS = new Set([
  'playback',
  'torrent',
  'stremio',
  'nuvio',
  'connected_services',
  'lan',
])

export type PackSettingsFieldType =
  | 'toggle'
  | 'select'
  | 'text'
  | 'multi_select'
  | 'password'
  | 'hub_select'

export type PackSettingsFieldOption = { id: string; label: string }

export type PackSettingsField = {
  id: string
  type: PackSettingsFieldType
  label: string
  subtitle?: string
  default?: boolean | string | string[]
  options?: PackSettingsFieldOption[]
  hubTypes?: string[]
  listOpenDefault?: boolean
  group: string
  order: number
  pluginId: string
  pluginName: string
}

export type PackAddonBucket = {
  id: string
  title: string
  subtitle: string
  /** Detail href under account settings. */
  href: string
  fields: PackSettingsField[]
  /** How many contributing plugins (for subtitle). */
  pluginCount: number
}

type ManifestPlugin = {
  id?: unknown
  name?: unknown
  enabled?: unknown
  nav?: { label?: unknown } | null
  settings?: {
    addon?: unknown
    group?: unknown
    order?: unknown
    fields?: unknown
  } | null
}

type ManifestJson = {
  name?: unknown
  plugins?: unknown
}

function titleFromAddonId(id: string): string {
  return id
    .split(/[_-]+/)
    .filter(Boolean)
    .map((p) => `${p[0]!.toUpperCase()}${p.slice(1)}`)
    .join(' ')
}

function hrefForAddon(addonId: string): string {
  if (addonId === 'iptv') return '/account/settings/iptv'
  if (addonId === 'torrent') return '/account/settings/torrent'
  return `/account/settings/addon/${encodeURIComponent(addonId)}`
}

/** Heuristic when manifest fetch fails — official hub / debrid slots. */
function heuristicAddonFromUrl(manifestUrl: string): {
  addonId: string
  title: string
  pluginId: string
} | null {
  const hub = hubTabIdFromPackManifestUrl(manifestUrl)
  if (hub === 'iptv') {
    return { addonId: 'iptv', title: 'IPTV', pluginId: 'iptv-hub' }
  }
  if (hub === 'live_sports') {
    return {
      addonId: 'live_sports',
      title: 'Live Sports',
      pluginId: 'live-sports-hub',
    }
  }
  if (hub === 'my_list') {
    return { addonId: 'my_list', title: 'My List', pluginId: 'my-list-hub' }
  }
  const lower = manifestUrl.toLowerCase()
  if (
    lower.includes('/debrid/') ||
    lower.includes('/plugins/debrid') ||
    /\/debrid\/manifest\.json(?:\?|$)/.test(lower)
  ) {
    return { addonId: 'debrid', title: 'Debrid', pluginId: 'realdebrid' }
  }
  return null
}

/** Official fallback fields when the live manifest cannot be fetched (CORS). */
const OFFICIAL_FIELD_FALLBACKS: Record<string, PackSettingsField[]> = {
  'live-sports-hub': [
    {
      id: 'forjaLiveEnabled',
      type: 'toggle',
      label: 'Enable Forja Live',
      subtitle: 'Show the Forja Live server in Live Sports',
      default: true,
      group: 'Setup',
      order: 10,
      pluginId: 'live-sports-hub',
      pluginName: 'Live Sports',
    },
    {
      id: 'forjaSportsEnabled',
      type: 'toggle',
      label: 'Enable Forja Sports',
      subtitle: 'Match IPTV portal channels on Live TV',
      default: true,
      group: 'Setup',
      order: 10,
      pluginId: 'live-sports-hub',
      pluginName: 'Live Sports',
    },
    {
      id: 'mergeMatchingEvents',
      type: 'toggle',
      label: 'Merge matching events',
      subtitle:
        'Combine the same game across catalogs into one card. Off keeps every catalog row separate.',
      default: true,
      group: 'Setup',
      order: 10,
      pluginId: 'live-sports-hub',
      pluginName: 'Live Sports',
    },
    {
      id: 'matchOpen',
      type: 'select',
      label: 'Open matches in',
      subtitle: 'Side panel beside the schedule, or a full detail page',
      default: 'panel',
      options: [
        { id: 'panel', label: 'Side panel' },
        { id: 'details', label: 'Detail page' },
      ],
      group: 'Setup',
      order: 10,
      pluginId: 'live-sports-hub',
      pluginName: 'Live Sports',
    },
  ],
  'my-list-hub': [
    {
      id: 'openDefault.movie',
      type: 'hub_select',
      label: 'Films',
      subtitle:
        'Default hub for film rows when nothing is saved on the bookmark',
      default: '',
      hubTypes: ['movie'],
      listOpenDefault: true,
      group: 'Open hubs',
      order: 10,
      pluginId: 'my-list-hub',
      pluginName: 'My List',
    },
    {
      id: 'openDefault.tv',
      type: 'hub_select',
      label: 'Series',
      subtitle:
        'Default hub for series rows when nothing is saved on the bookmark',
      default: '',
      hubTypes: ['tv'],
      listOpenDefault: true,
      group: 'Open hubs',
      order: 10,
      pluginId: 'my-list-hub',
      pluginName: 'My List',
    },
    {
      id: 'openDefault.anime',
      type: 'hub_select',
      label: 'Anime',
      subtitle:
        'Default hub for anime rows when nothing is saved on the bookmark',
      default: '',
      hubTypes: ['anime'],
      listOpenDefault: true,
      group: 'Open hubs',
      order: 10,
      pluginId: 'my-list-hub',
      pluginName: 'My List',
    },
    {
      id: 'openDefault.drama',
      type: 'hub_select',
      label: 'Asian Drama',
      subtitle:
        'Default hub for Asian Drama rows when nothing is saved on the bookmark',
      default: '',
      hubTypes: ['drama'],
      listOpenDefault: true,
      group: 'Open hubs',
      order: 10,
      pluginId: 'my-list-hub',
      pluginName: 'My List',
    },
  ],
}

const DEBRID_PLUGINS: Array<{ id: string; name: string; order: number }> = [
  { id: 'realdebrid', name: 'Real-Debrid', order: 10 },
  { id: 'torbox', name: 'TorBox', order: 20 },
  { id: 'alldebrid', name: 'AllDebrid', order: 30 },
  { id: 'premiumize', name: 'Premiumize', order: 40 },
  { id: 'debrid_link', name: 'Debrid-Link', order: 50 },
]

function debridFallbackFields(): PackSettingsField[] {
  return DEBRID_PLUGINS.map((p) => ({
    id: 'apiKey',
    type: 'password' as const,
    label: 'API key',
    subtitle: `${p.name} — configure in the Forja app`,
    group: p.name,
    order: p.order,
    pluginId: p.id,
    pluginName: p.name,
  }))
}

function parseFieldType(raw: string): PackSettingsFieldType | null {
  const t = raw.trim().toLowerCase()
  if (t === 'toggle') return 'toggle'
  if (t === 'select') return 'select'
  if (t === 'text') return 'text'
  if (t === 'password' || t === 'secret') return 'password'
  if (t === 'multi_select' || t === 'multiselect' || t === 'chips') {
    return 'multi_select'
  }
  if (t === 'hub_select' || t === 'hubselect' || t === 'hub') return 'hub_select'
  return null
}

function parseFieldsFromPlugin(plugin: ManifestPlugin): PackSettingsField[] {
  const pluginId = typeof plugin.id === 'string' ? plugin.id.trim() : ''
  const pluginName =
    typeof plugin.name === 'string' && plugin.name.trim()
      ? plugin.name.trim()
      : pluginId
  if (!pluginId) return []
  const settings = plugin.settings
  if (!settings || typeof settings !== 'object') return []
  const group =
    typeof settings.group === 'string' && settings.group.trim()
      ? settings.group.trim()
      : pluginName
  const order =
    typeof settings.order === 'number' && Number.isFinite(settings.order)
      ? settings.order
      : 100
  const rawFields = settings.fields
  if (!Array.isArray(rawFields)) return []
  const out: PackSettingsField[] = []
  for (const raw of rawFields) {
    if (!raw || typeof raw !== 'object') continue
    const f = raw as Record<string, unknown>
    const id = typeof f.id === 'string' ? f.id.trim() : ''
    const label = typeof f.label === 'string' ? f.label.trim() : ''
    const type = parseFieldType(typeof f.type === 'string' ? f.type : '')
    if (!id || !label || !type) continue
    const field: PackSettingsField = {
      id,
      type,
      label,
      group,
      order,
      pluginId,
      pluginName,
    }
    if (typeof f.subtitle === 'string' && f.subtitle.trim()) {
      field.subtitle = f.subtitle.trim()
    }
    if (type === 'toggle') {
      field.default = f.default === true
    } else if (type === 'multi_select' && Array.isArray(f.default)) {
      field.default = f.default
        .map((e) => String(e).trim())
        .filter(Boolean)
    } else if (f.default != null) {
      field.default = String(f.default)
    }
    if (Array.isArray(f.options)) {
      const options: PackSettingsFieldOption[] = []
      for (const o of f.options) {
        if (!o || typeof o !== 'object') continue
        const row = o as Record<string, unknown>
        const oid = typeof row.id === 'string' ? row.id.trim() : ''
        if (!oid) continue
        const olabel =
          typeof row.label === 'string' && row.label.trim()
            ? row.label.trim()
            : oid
        options.push({ id: oid, label: olabel })
      }
      if (options.length) field.options = options
    }
    const hubRaw = f.hubTypes ?? f.hub_types ?? f.types
    if (Array.isArray(hubRaw)) {
      field.hubTypes = hubRaw
        .map((e) => String(e).trim())
        .filter(Boolean)
    }
    if (f.listOpenDefault === true || f.list_open_default === true) {
      field.listOpenDefault = true
    }
    if (
      (type === 'select' || type === 'multi_select') &&
      !(field.options && field.options.length)
    ) {
      continue
    }
    if (type === 'hub_select' && !(field.hubTypes && field.hubTypes.length)) {
      continue
    }
    out.push(field)
  }
  return out
}

function contribFromPlugin(plugin: ManifestPlugin): {
  addonId: string
  titleHint: string
  fields: PackSettingsField[]
} | null {
  const pluginId = typeof plugin.id === 'string' ? plugin.id.trim() : ''
  if (!pluginId) return null
  if (plugin.enabled === false) return null
  const settings = plugin.settings
  if (!settings || typeof settings !== 'object') return null
  const addonRaw =
    typeof settings.addon === 'string' ? settings.addon.trim() : ''
  const addonId = addonRaw || pluginId
  if (!addonId || HOST_ADDON_IDS.has(addonId)) {
    // Host bucket injection (e.g. connected_services) — not a new Addons row.
    // Still allow fields when caller asks by addon id elsewhere.
    if (HOST_ADDON_IDS.has(addonId) && addonRaw) return null
    if (!addonRaw && HOST_ADDON_IDS.has(pluginId)) return null
  }
  if (HOST_ADDON_IDS.has(addonId)) return null

  const navLabel =
    plugin.nav && typeof plugin.nav === 'object'
      ? typeof plugin.nav.label === 'string'
        ? plugin.nav.label.trim()
        : ''
      : ''
  const fields = parseFieldsFromPlugin(plugin)
  return {
    addonId,
    titleHint: navLabel,
    fields,
  }
}

async function fetchManifestJson(
  manifestUrl: string,
): Promise<ManifestJson | null> {
  const url = manifestUrl.trim()
  if (!url) return null
  try {
    const res = await fetch(url, { cache: 'no-store' })
    if (!res.ok) return null
    return (await res.json()) as ManifestJson
  } catch {
    return null
  }
}

/**
 * Sync hub/debrid Addons rows from enabled pack URLs only (no network).
 * Used so IPTV Portals stays visible when Flutter synced local checkout paths
 * the browser cannot fetch.
 */
export function packAddonBucketsFromUrls(
  packs: ForjaPackRow[],
): PackAddonBucket[] {
  const byAddon = new Map<
    string,
    {
      titleHints: string[]
      fields: PackSettingsField[]
      pluginIds: Set<string>
    }
  >()

  for (const pack of packs) {
    if (pack.enabled === false) continue
    const url =
      typeof pack.manifestUrl === 'string' ? pack.manifestUrl.trim() : ''
    if (!url) continue
    const heuristic = heuristicAddonFromUrl(url)
    if (!heuristic || HOST_ADDON_IDS.has(heuristic.addonId)) continue
    const bucket = byAddon.get(heuristic.addonId) ?? {
      titleHints: [],
      fields: [],
      pluginIds: new Set<string>(),
    }
    if (!bucket.titleHints.includes(heuristic.title)) {
      bucket.titleHints.push(heuristic.title)
    }
    bucket.pluginIds.add(heuristic.pluginId)
    if (heuristic.addonId === 'debrid' && bucket.fields.length === 0) {
      bucket.fields.push(...debridFallbackFields())
      for (const p of DEBRID_PLUGINS) bucket.pluginIds.add(p.id)
    } else if (bucket.fields.length === 0) {
      const fallback = OFFICIAL_FIELD_FALLBACKS[heuristic.pluginId]
      if (fallback) bucket.fields.push(...fallback)
    }
    byAddon.set(heuristic.addonId, bucket)
  }

  return [...byAddon.keys()].sort().map((id) => {
    const b = byAddon.get(id)!
    const pluginCount = b.pluginIds.size || 1
    const title =
      b.titleHints.find((t) => t.trim()) || titleFromAddonId(id)
    return {
      id,
      title,
      subtitle:
        id === 'iptv'
          ? 'Xtream portals and programme guide'
          : pluginCount === 1
            ? 'Pack settings'
            : `${pluginCount} pack settings`,
      href: hrefForAddon(id),
      fields: b.fields,
      pluginCount,
    }
  })
}

/**
 * Pack-contributed Addons rows for enabled packs on the profile.
 * Tries live manifests; always merges URL heuristics + official field schemas
 * so local checkout paths still produce IPTV / Live Sports / … rows.
 */
export async function discoverPackAddonBuckets(
  packs: ForjaPackRow[],
): Promise<PackAddonBucket[]> {
  const byAddon = new Map<
    string,
    {
      titleHints: string[]
      fields: PackSettingsField[]
      pluginIds: Set<string>
    }
  >()

  const enabled = packs.filter((p) => p.enabled !== false)

  await Promise.all(
    enabled.map(async (pack) => {
      const url =
        typeof pack.manifestUrl === 'string' ? pack.manifestUrl.trim() : ''
      if (!url) return
      const manifest = await fetchManifestJson(url)
      const plugins = Array.isArray(manifest?.plugins)
        ? (manifest!.plugins as ManifestPlugin[])
        : []

      for (const plugin of plugins) {
        const hit = contribFromPlugin(plugin)
        if (!hit) continue
        const bucket = byAddon.get(hit.addonId) ?? {
          titleHints: [],
          fields: [],
          pluginIds: new Set<string>(),
        }
        if (hit.titleHint) bucket.titleHints.push(hit.titleHint)
        for (const f of hit.fields) {
          bucket.fields.push(f)
          bucket.pluginIds.add(f.pluginId)
        }
        // Addon row even when fields empty (IPTV bucket).
        const pid =
          typeof plugin.id === 'string' ? plugin.id.trim() : hit.addonId
        if (pid) bucket.pluginIds.add(pid)
        byAddon.set(hit.addonId, bucket)
      }

      // Always merge URL heuristics. Browser cannot fetch local checkout paths
      // (`/Users/…/hubs/iptv/manifest.json`) that Flutter syncs as-is — without
      // this, IPTV / Live Sports / My List / Debrid vanish from web Addons.
      const heuristic = heuristicAddonFromUrl(url)
      if (!heuristic || HOST_ADDON_IDS.has(heuristic.addonId)) return
      const bucket = byAddon.get(heuristic.addonId) ?? {
        titleHints: [],
        fields: [],
        pluginIds: new Set<string>(),
      }
      if (!bucket.titleHints.includes(heuristic.title)) {
        bucket.titleHints.push(heuristic.title)
      }
      bucket.pluginIds.add(heuristic.pluginId)
      if (heuristic.addonId === 'debrid' && bucket.fields.length === 0) {
        bucket.fields.push(...debridFallbackFields())
        for (const p of DEBRID_PLUGINS) bucket.pluginIds.add(p.id)
      } else if (bucket.fields.length === 0) {
        const fallback = OFFICIAL_FIELD_FALLBACKS[heuristic.pluginId]
        if (fallback) bucket.fields.push(...fallback)
      }
      byAddon.set(heuristic.addonId, bucket)
    }),
  )

  const ids = [...byAddon.keys()].sort()
  return ids.map((id) => {
    const b = byAddon.get(id)!
    b.fields.sort((a, c) => {
      const o = a.order - c.order
      if (o !== 0) return o
      return a.pluginName.localeCompare(c.pluginName)
    })
    const pluginCount = b.pluginIds.size || 1
    const title =
      b.titleHints.find((t) => t.trim()) ||
      (pluginCount > 1
        ? titleFromAddonId(id)
        : b.fields[0]?.pluginName || titleFromAddonId(id))
    return {
      id,
      title,
      subtitle:
        id === 'iptv'
          ? 'Xtream portals and programme guide'
          : pluginCount === 1
            ? 'Pack settings'
            : `${pluginCount} pack settings`,
      href: hrefForAddon(id),
      fields: b.fields,
      pluginCount,
    }
  })
}

/** Fields for one addon bucket (detail page). */
export async function loadPackAddonBucket(
  packs: ForjaPackRow[],
  addonId: string,
): Promise<PackAddonBucket | null> {
  const want = addonId.trim()
  if (!want || HOST_ADDON_IDS.has(want)) return null
  const all = await discoverPackAddonBuckets(packs)
  return all.find((b) => b.id === want) ?? null
}

export function defaultValueForField(
  field: PackSettingsField,
): boolean | string | string[] {
  if (field.type === 'toggle') return field.default === true
  if (field.type === 'multi_select') {
    return Array.isArray(field.default) ? [...field.default] : []
  }
  if (typeof field.default === 'string') return field.default
  return ''
}

export function isSecretField(field: PackSettingsField): boolean {
  return field.type === 'password'
}

export type HubSelectOption = {
  pluginId: string
  label: string
  types: string[]
}

const HUB_SELECT_SKIP_TYPES = new Set([
  'list',
  'live_match',
  'live_sport',
  'live',
  'catalog',
  'iptv',
])

/** Browse-hub options for hub_select fields (plugin id + label + types). */
export async function listHubSelectOptions(
  packs: ForjaPackRow[],
): Promise<HubSelectOption[]> {
  const out: HubSelectOption[] = []
  const seen = new Set<string>()
  const enabled = packs.filter((p) => p.enabled !== false)

  await Promise.all(
    enabled.map(async (pack) => {
      const url = pack.manifestUrl.trim()
      if (!url) return
      // Only hub packs contribute browse hubs.
      if (!hubTabIdFromPackManifestUrl(url)) return
      const manifest = await fetchManifestJson(url)
      const plugins = Array.isArray(manifest?.plugins)
        ? (manifest!.plugins as ManifestPlugin[])
        : []
      for (const plugin of plugins) {
        if (plugin.enabled === false) continue
        const pluginId =
          typeof plugin.id === 'string' ? plugin.id.trim() : ''
        if (!pluginId || seen.has(pluginId)) continue
        const caps = (plugin as { capabilities?: unknown }).capabilities
        const hasDetails =
          Array.isArray(caps) &&
          caps.map(String).some((c) => c.trim() === 'details')
        const hasNav =
          plugin.nav != null &&
          typeof plugin.nav === 'object' &&
          Object.keys(plugin.nav).length > 0
        if (!hasDetails || !hasNav) continue
        const typesRaw = (plugin as { types?: unknown }).types
        const types = Array.isArray(typesRaw)
          ? typesRaw.map((t) => String(t).trim()).filter(Boolean)
          : []
        if (types.length && types.every((t) => HUB_SELECT_SKIP_TYPES.has(t))) {
          continue
        }
        if (types.length === 1 && types[0] === 'list') continue
        const navLabel =
          plugin.nav && typeof plugin.nav.label === 'string'
            ? plugin.nav.label.trim()
            : ''
        const name =
          typeof plugin.name === 'string' ? plugin.name.trim() : ''
        const label = navLabel || name || pluginId
        seen.add(pluginId)
        out.push({ pluginId, label, types })
      }
    }),
  )

  out.sort((a, b) => a.label.localeCompare(b.label))
  return out
}
