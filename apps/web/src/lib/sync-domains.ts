/** Profile settings payload — must match Flutter SyncDomainBridge (lean storage). */

/** Account-level feature flags. Empty `{}` = all off.
 *  Booleans: only store enabled keys. Numeric: omit maxIptvPortals when default 5.
 */
export type AccountFeaturesPayload = {
  /** Reddit / Find Portals scrape in the IPTV tab. */
  iptvScrape?: true
  /** Deal lottery packs from the catalog pool (requires credits). */
  dealPortal?: true
  /** Max Xtream portals per profile. Omit when default 5. */
  maxIptvPortals?: number
}

export type AccountFeaturesExpanded = {
  iptvScrape: boolean
  dealPortal: boolean
  /** Catalog pool deal balance (accounts.iptv_credits). */
  iptvCredits: number
  /** Max portals per profile (features.maxIptvPortals). Default 5. */
  maxIptvPortals: number
  /** accounts.is_admin — unlimited portals when true. */
  isAdmin: boolean
}

export function emptyAccountFeatures(): AccountFeaturesExpanded {
  return {
    iptvScrape: false,
    dealPortal: false,
    iptvCredits: 0,
    maxIptvPortals: 5,
    isAdmin: false,
  }
}

function parseMaxFromFeatures(raw: Record<string, unknown>): number {
  const v = raw.maxIptvPortals
  const n =
    typeof v === 'number'
      ? Math.trunc(v)
      : typeof v === 'string'
        ? Number.parseInt(v, 10)
        : Number.NaN
  if (!Number.isFinite(n)) return 5
  return Math.max(1, Math.min(500, n))
}

export function expandAccountFeatures(
  raw: unknown,
  opts?: {
    iptvCredits?: number
    isAdmin?: boolean
  },
): AccountFeaturesExpanded {
  const base = emptyAccountFeatures()
  const iptvCredits = opts?.iptvCredits
  const isAdmin = opts?.isAdmin === true
  if (!raw || typeof raw !== 'object') {
    return {
      ...base,
      iptvCredits: Number.isFinite(iptvCredits)
        ? Math.max(0, iptvCredits!)
        : 0,
      isAdmin,
    }
  }
  const p = raw as Record<string, unknown>
  const credits = Number.isFinite(iptvCredits)
    ? Math.max(0, Math.trunc(iptvCredits!))
    : 0
  return {
    iptvScrape: p.iptvScrape === true,
    dealPortal: p.dealPortal === true,
    iptvCredits: credits,
    maxIptvPortals: parseMaxFromFeatures(p),
    isAdmin,
  }
}

/** Lean write: omit disabled keys and default maxIptvPortals. */
export function compactAccountFeatures(
  f: AccountFeaturesExpanded | AccountFeaturesPayload | undefined,
): AccountFeaturesPayload {
  if (!f) return {}
  const out: AccountFeaturesPayload = {}
  if (f.iptvScrape === true) out.iptvScrape = true
  if (f.dealPortal === true) out.dealPortal = true
  const max =
    'maxIptvPortals' in f && typeof f.maxIptvPortals === 'number'
      ? f.maxIptvPortals
      : undefined
  if (max != null && max !== 5) {
    out.maxIptvPortals = Math.max(1, Math.min(500, Math.trunc(max)))
  }
  return out
}

export type PreferencesPayload = {
  play_source_torrent_enabled?: boolean
  play_source_stremio_enabled?: boolean
  play_source_nuvio_enabled?: boolean
  play_source_webstreaming_enabled?: boolean
  simple_streaming_resolve_enabled?: boolean
  preferred_audio_lang?: string
  avoid_unsupported_audio?: boolean
  auto_next_episode?: boolean
  auto_skip_intro?: boolean
  iptv_epg_enabled?: boolean
  max_playback_height?: number
  /** Host Addons → IPTV unlocked (RFC-086). Rail default-on via navigation. */
  addon_feature_iptv?: boolean
  /** Host Addons → Live Sports unlocked (RFC-086). */
  addon_feature_live_matches?: boolean
}

export type ProvidersPayload = {
  stream_provider_order?: string[]
  anime_provider_order?: string[]
  asian_drama_provider_order?: string[]
}

export type StremioAddonRow = {
  baseUrl: string
  name?: string
  description?: string
  /** `vod` = Sources / Home / Search; `live` = Live Matches Stremio server */
  features?: Array<'vod' | 'live'>
  /** Master on/off — omit / true = enabled; false = installed but skipped */
  enabled?: boolean
}

export type StremioPayload = {
  addons: StremioAddonRow[]
}

export type NuvioAddonRow = {
  manifestUrl: string
  name?: string
}

export type NuvioPayload = {
  addons: NuvioAddonRow[]
}

export type ForjaPackRow = {
  manifestUrl: string
  name?: string
  version?: string
  addedAt?: string
}

export type ForjaPayload = {
  packs: ForjaPackRow[]
  /** Packs onboarding completed (Install or Skip). Missing ⇒ false. */
  onboarded?: boolean
}

export type ConnectedServicesPayload = {
  /** @deprecated Provider order is device-local — never write to cloud. */
  providers?: ProvidersPayload
  stremio?: StremioPayload
  nuvio?: NuvioPayload
  forja?: ForjaPayload
}

export type NavigationPayload = {
  visibleIds?: string[]
  /** Full Settings → Features order (visible + hidden). */
  tabOrder?: string[]
  defaultTab?: string
}

/** Host-owned shell tabs (Addons / Features). Catalog hubs are opaque pack
 * `nav.tabId` values synced from the app — never bake hub inventory here
 * (RFC-081). */
export const HOST_CORE_NAV_TABS = [
  { id: 'iptv', label: 'IPTV' },
  { id: 'live_matches', label: 'Live Matches' },
] as const

export const HOST_CORE_NAV_IDS: string[] = HOST_CORE_NAV_TABS.map((t) => t.id)

/** @deprecated Use [HOST_CORE_NAV_TABS] — name kept for older imports. */
export const SYNCABLE_NAV_TABS = HOST_CORE_NAV_TABS

/** Fresh profile: no feature tabs on (matches Flutter PlatformDefaults). */
export const DEFAULT_NAV_VISIBLE_IDS: string[] = []

/** Startup when no feature tab is visible. */
export const DEFAULT_NAV_TAB = 'settings'

/** Flutter `archivedNavIds` — never show or persist on web Features. */
export const ARCHIVED_NAV_IDS = new Set([
  'search',
  'discover',
  'similar',
  'downloader',
  'magnet',
  'audiobooks',
  'books',
  'music',
  'comics',
  'manga',
  'jellyfin',
  'anime_arabic',
])

/** Display-only hints when a pack tab id is already in cloud — not an inventory. */
const NAV_LABEL_HINTS: Record<string, string> = {
  iptv: 'IPTV',
  live_matches: 'Live Matches',
  home: 'Home',
  anime: 'Anime',
  asian_drama: 'Asian Drama',
  mylist: 'My List',
}

export function navTabLabel(id: string): string {
  if (id === 'settings') return 'Settings'
  const hint = NAV_LABEL_HINTS[id]
  if (hint) return hint
  return id
    .split(/[_-]+/)
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ')
}

function isPersistedNavId(id: string): boolean {
  const t = id.trim()
  if (!t || t === 'settings') return false
  if (ARCHIVED_NAV_IDS.has(t)) return false
  return true
}

export type M3uChannelRow = {
  n: string
  u: string
  l?: string
  g?: string
  ti?: string
  tn?: string
}

/** Local/UI playlist; never written to cloud (device-local only). */
export type M3uPlaylistRow = {
  id: string
  name: string
  sourceUrl: string | null
  addedAt: number
  updatedAt: number
  channels?: M3uChannelRow[]
}

export type ProfileSettingsPayload = {
  playback?: PreferencesPayload
  connectedServices?: ConnectedServicesPayload
  navigation?: NavigationPayload
}

/**
 * UI-merged portal row.
 * Display name is always `portalName` → user_iptv_portals.portal_name.
 */
export type IptvPortalRow = {
  portalId?: string
  url: string
  username: string
  password: string
  source?: string
  /** xtream | m3u | stalker — default xtream when omitted. */
  platform?: 'xtream' | 'm3u' | 'stalker'
  /** Per-profile display name (user_iptv_portals.portal_name). */
  portalName: string
  /** @deprecated use portalName */
  label?: string
  /** @deprecated ignored — names live on user_iptv_portals only */
  name?: string
  expiry?: string
  max?: string
  active?: string
  favorite?: boolean
}

export function portalDisplayLabel(
  portal: Pick<IptvPortalRow, 'portalName' | 'label' | 'username'>,
): string {
  const portalName = (portal.portalName ?? portal.label)?.trim()
  if (portalName) return portalName
  const user = portal.username?.trim()
  return user || 'Portal'
}

export function portalKey(row: Pick<IptvPortalRow, 'url' | 'username' | 'password'>): string {
  return `${row.url}|${row.username}|${row.password}`.toLowerCase()
}

export const MAX_PLAYBACK_HEIGHT_OPTIONS = [
  { label: 'Auto', value: 0 },
  { label: '4K (2160p)', value: 2160 },
  { label: '1440p', value: 1440 },
  { label: '1080p', value: 1080 },
  { label: '720p', value: 720 },
  { label: '480p', value: 480 },
] as const

export const AUDIO_LANGUAGE_OPTIONS = [
  'None',
  'English',
  'French',
  'Spanish',
  'German',
  'Italian',
  'Portuguese',
  'Arabic',
  'Japanese',
  'Korean',
  'Chinese',
] as const

export type RemoteSettingSection = {
  key: keyof ProfileSettingsPayload | 'stremio' | 'nuvio' | 'forja' | 'iptv' | 'addons'
  title: string
  description: string
  href: string
}

export const REMOTE_SETTING_SECTIONS: RemoteSettingSection[] = [
  {
    key: 'addons',
    title: 'Addons',
    description:
      'Host product surfaces (Playback, IPTV, Live Sports, torrent, Stremio, Nuvio). Detail routes under /addons.',
    href: '/account/settings/addons',
  },
  {
    key: 'iptv',
    title: 'IPTV portals',
    description:
      'Assign Xtream portals for this profile (user_iptv_portals). Open from Addons → IPTV.',
    href: '/account/settings/iptv',
  },
  {
    key: 'playback',
    title: 'Playback',
    description:
      'Play sources, auto next, audio language, quality cap — Addons → Playback.',
    href: '/account/settings/playback',
  },
  {
    key: 'navigation',
    title: 'Features',
    description: 'Which shell tabs are visible and which opens by default.',
    href: '/account/settings/navigation',
  },
  {
    key: 'forja',
    title: 'Forja Packs',
    description: 'Engine plugin pack manifest URLs (Settings → Forja Packs in the app).',
    href: '/account/settings/forja',
  },
  {
    key: 'stremio',
    title: 'Stremio addons',
    description: 'Addon manifest URLs — Addons → Stremio.',
    href: '/account/settings/stremio',
  },
  {
    key: 'nuvio',
    title: 'Nuvio scrapers',
    description: 'Nuvio scraper manifest URLs — Addons → Nuvio.',
    href: '/account/settings/nuvio',
  },
]

export function emptyProfileSettingsPayload(): ProfileSettingsPayload {
  return {
    playback: emptyPreferencesPayload(),
    connectedServices: {
      stremio: emptyStremioPayload(),
      nuvio: emptyNuvioPayload(),
      forja: emptyForjaPayload(),
    },
    navigation: emptyNavigationPayload(),
  }
}

export function emptyNavigationPayload(): Required<NavigationPayload> {
  return {
    visibleIds: [],
    // Host-core rows only — hub tabs appear when the app syncs pack `nav` ids.
    tabOrder: [...HOST_CORE_NAV_IDS],
    defaultTab: DEFAULT_NAV_TAB,
  }
}

function mergeNavTabOrder(stored: string[], extras: string[]): string[] {
  const seen = new Set<string>()
  const out: string[] = []
  for (const id of [...stored, ...extras]) {
    if (!isPersistedNavId(id) || seen.has(id)) continue
    seen.add(id)
    out.push(id)
  }
  return out
}

/** Normalize cloud/UI nav. Empty `visibleIds` is intentional. Pack hub tab ids
 * pass through opaquely; only archived host ids are stripped. Settings is
 * never stored. */
export function normalizeNavigationPayload(
  n: NavigationPayload | undefined,
): Required<NavigationPayload> {
  const raw = (n?.visibleIds ?? []).filter(isPersistedNavId)
  const seen = new Set<string>()
  const visibleIds: string[] = []
  for (const id of raw) {
    if (seen.has(id)) continue
    seen.add(id)
    visibleIds.push(id)
  }
  let defaultTab = (n?.defaultTab ?? DEFAULT_NAV_TAB).trim() || DEFAULT_NAV_TAB
  if (defaultTab !== 'settings' && !visibleIds.includes(defaultTab)) {
    defaultTab = visibleIds.length > 0 ? visibleIds[0]! : 'settings'
  }
  const storedTabOrder = (n?.tabOrder ?? []).filter(isPersistedNavId)
  const tabOrder = mergeNavTabOrder(storedTabOrder, [
    ...visibleIds,
    ...HOST_CORE_NAV_IDS,
  ])
  return { visibleIds, tabOrder, defaultTab }
}

export function emptyPreferencesPayload(): Required<PreferencesPayload> {
  return {
    play_source_torrent_enabled: true,
    play_source_stremio_enabled: true,
    play_source_nuvio_enabled: true,
    play_source_webstreaming_enabled: true,
    simple_streaming_resolve_enabled: true,
    preferred_audio_lang: 'None',
    avoid_unsupported_audio: true,
    auto_next_episode: true,
    auto_skip_intro: false,
    iptv_epg_enabled: true,
    max_playback_height: 2160,
    addon_feature_iptv: false,
    addon_feature_live_matches: false,
  }
}

export function emptyStremioPayload(): StremioPayload {
  return { addons: [] }
}

export function emptyNuvioPayload(): NuvioPayload {
  return { addons: [] }
}

export function emptyForjaPayload(): ForjaPayload {
  return { packs: [] }
}

/** Persist full playback prefs (incl. play_source_* modes) — never strip to empty. */
function compactPlayback(p: PreferencesPayload | undefined): PreferencesPayload | undefined {
  if (!p) return undefined
  const d = emptyPreferencesPayload()
  return { ...d, ...p }
}

function compactStremio(s: StremioPayload | undefined): StremioPayload | undefined {
  if (!s?.addons?.length) return undefined
  const addons = s.addons
    .map((a) => {
      const baseUrl = a.baseUrl?.trim()
      if (!baseUrl) return null
      const row: StremioAddonRow = { baseUrl }
      const name = a.name?.trim()
      if (name) row.name = name
      const description = a.description?.trim()
      if (description) row.description = description
      if (a.features?.length) row.features = [...a.features]
      if (a.enabled === false) row.enabled = false
      return row
    })
    .filter((a): a is StremioAddonRow => a != null)
  return addons.length ? { addons } : undefined
}

function compactNuvio(s: NuvioPayload | undefined): NuvioPayload | undefined {
  if (!s?.addons?.length) return undefined
  const addons = s.addons
    .map((a) => {
      const manifestUrl = a.manifestUrl?.trim()
      if (!manifestUrl) return null
      const row: NuvioAddonRow = { manifestUrl }
      const name = a.name?.trim()
      if (name) row.name = name
      return row
    })
    .filter((a): a is NuvioAddonRow => a != null)
  return addons.length ? { addons } : undefined
}

function compactForja(s: ForjaPayload | undefined): ForjaPayload | undefined {
  const packs = (s?.packs ?? [])
    .map((a) => {
      const manifestUrl = a.manifestUrl?.trim()
      if (!manifestUrl) return null
      const row: ForjaPackRow = { manifestUrl }
      const name = a.name?.trim()
      if (name && name !== manifestUrl) row.name = name
      const version = a.version?.trim()
      if (version) row.version = version
      const addedAt = a.addedAt?.trim()
      if (addedAt) row.addedAt = addedAt
      return row
    })
    .filter((a): a is ForjaPackRow => a != null)
  const onboarded = s?.onboarded === true
  if (!packs.length && !onboarded) return undefined
  const out: ForjaPayload = { packs }
  if (onboarded) out.onboarded = true
  return out
}

function compactNavigation(n: NavigationPayload | undefined): NavigationPayload | undefined {
  if (!n) return undefined
  const normalized = normalizeNavigationPayload(n)
  const out: NavigationPayload = {
    visibleIds: normalized.visibleIds,
    tabOrder: normalized.tabOrder,
  }
  if (normalized.defaultTab) out.defaultTab = normalized.defaultTab
  return out
}

/** Compact before DB write: full playback; stremio/nuvio/forja under connectedServices.
 * Provider order is device-local — never persist. Never write iptv (portals/M3U). */
export function compactProfileSettingsPayload(
  full: ProfileSettingsPayload,
): ProfileSettingsPayload {
  const playback = compactPlayback(full.playback)
  const stremio = compactStremio(full.connectedServices?.stremio)
  const nuvio = compactNuvio(full.connectedServices?.nuvio)
  const forja = compactForja(full.connectedServices?.forja)
  const navigation = compactNavigation(full.navigation)

  const connectedServices: ConnectedServicesPayload = {}
  if (stremio) connectedServices.stremio = stremio
  if (nuvio) connectedServices.nuvio = nuvio
  if (forja) connectedServices.forja = forja

  const out: ProfileSettingsPayload = {}
  if (playback) out.playback = playback
  if (Object.keys(connectedServices).length) out.connectedServices = connectedServices
  if (navigation) out.navigation = navigation
  return out
}

/** Expand lean cloud payload to full in-memory defaults. */
export function expandProfileSettingsPayload(raw: unknown): ProfileSettingsPayload {
  const base = emptyProfileSettingsPayload()
  if (!raw || typeof raw !== 'object') return base
  const p = raw as ProfileSettingsPayload & { films?: unknown; iptv?: unknown }

  // Ignore legacy connectedServices.providers — device-local only.
  void p.connectedServices?.providers
  // Ignore legacy payload.iptv — portals/M3U are not in profile_settings.
  void p.iptv

  const stremio = {
    addons: p.connectedServices?.stremio?.addons ?? [],
  }
  const nuvio = {
    addons: p.connectedServices?.nuvio?.addons ?? [],
  }
  const forja = {
    packs: p.connectedServices?.forja?.packs ?? [],
    ...(p.connectedServices?.forja?.onboarded === true
      ? { onboarded: true as const }
      : {}),
  }

  void p.films

  return {
    playback: { ...base.playback, ...p.playback },
    connectedServices: { stremio, nuvio, forja },
    navigation: normalizeNavigationPayload(p.navigation),
  }
}

/** @deprecated films no longer synced */
export type FilmRef = { tmdbId: number; mediaType: 'movie' | 'tv' }
