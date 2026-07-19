/** Profile settings payload — must match Flutter SyncDomainBridge (lean storage). */

/** Account-level feature flags. Empty `{}` = all off. Only store enabled keys. */
export type AccountFeaturesPayload = {
  /** Reddit / Find Portals scrape in the IPTV tab. */
  iptvScrape?: true
}

export type AccountFeaturesExpanded = {
  iptvScrape: boolean
  /** Catalog pool deal balance (accounts.iptv_credits). */
  iptvCredits: number
}

export function emptyAccountFeatures(): AccountFeaturesExpanded {
  return { iptvScrape: false, iptvCredits: 0 }
}

export function expandAccountFeatures(
  raw: unknown,
  iptvCredits?: number,
): AccountFeaturesExpanded {
  const base = emptyAccountFeatures()
  if (!raw || typeof raw !== 'object') {
    return {
      ...base,
      iptvCredits: Number.isFinite(iptvCredits) ? Math.max(0, iptvCredits!) : 0,
    }
  }
  const p = raw as Record<string, unknown>
  const credits = Number.isFinite(iptvCredits)
    ? Math.max(0, Math.trunc(iptvCredits!))
    : 0
  return {
    iptvScrape: p.iptvScrape === true,
    iptvCredits: credits,
  }
}

/** Lean write: omit disabled keys entirely. */
export function compactAccountFeatures(
  f: AccountFeaturesExpanded | AccountFeaturesPayload | undefined,
): AccountFeaturesPayload {
  if (!f) return {}
  const out: AccountFeaturesPayload = {}
  if (f.iptvScrape === true) out.iptvScrape = true
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

export type ConnectedServicesPayload = {
  /** @deprecated Provider order is device-local — never write to cloud. */
  providers?: ProvidersPayload
  stremio?: StremioPayload
  nuvio?: NuvioPayload
}

export type NavigationPayload = {
  visibleIds?: string[]
  defaultTab?: string
}

/** Shell tabs editable on web / synced — mirrors Flutter PlatformDefaults.defaultNavIds. */
export const SYNCABLE_NAV_TABS = [
  { id: 'search', label: 'Search' },
  { id: 'home', label: 'Home' },
  { id: 'asian_drama', label: 'Asian Drama' },
  { id: 'anime', label: 'Anime' },
  { id: 'iptv', label: 'IPTV' },
  { id: 'live_matches', label: 'Live Matches' },
  { id: 'mylist', label: 'My List' },
] as const

export const DEFAULT_NAV_VISIBLE_IDS: string[] = SYNCABLE_NAV_TABS.map(
  (t) => t.id,
)

export const DEFAULT_NAV_TAB = 'home'

const SYNCABLE_NAV_ID_SET = new Set<string>(DEFAULT_NAV_VISIBLE_IDS)

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
  key: keyof ProfileSettingsPayload | 'stremio' | 'nuvio' | 'iptv'
  title: string
  description: string
  href: string
}

export const REMOTE_SETTING_SECTIONS: RemoteSettingSection[] = [
  {
    key: 'iptv',
    title: 'IPTV',
    description:
      'Assign Xtream portals for this profile (user_iptv_portals).',
    href: '/account/settings/iptv',
  },
  {
    key: 'playback',
    title: 'Playback',
    description:
      'Play sources (torrent / Stremio / Nuvio / web), auto next, audio language, and quality cap.',
    href: '/account/settings/playback',
  },
  {
    key: 'navigation',
    title: 'Features',
    description: 'Which shell tabs are visible and which opens by default.',
    href: '/account/settings/navigation',
  },
  {
    key: 'stremio',
    title: 'Stremio addons',
    description: 'Addon manifest URLs installed on your account.',
    href: '/account/settings/stremio',
  },
  {
    key: 'nuvio',
    title: 'Nuvio addons',
    description: 'Nuvio scraper manifest URLs installed on your account.',
    href: '/account/settings/nuvio',
  },
]

export function emptyProfileSettingsPayload(): ProfileSettingsPayload {
  return {
    playback: emptyPreferencesPayload(),
    connectedServices: {
      stremio: emptyStremioPayload(),
      nuvio: emptyNuvioPayload(),
    },
    navigation: emptyNavigationPayload(),
  }
}

export function emptyNavigationPayload(): Required<NavigationPayload> {
  return {
    visibleIds: [...DEFAULT_NAV_VISIBLE_IDS],
    defaultTab: DEFAULT_NAV_TAB,
  }
}

/** Normalize cloud/UI nav: only syncable tabs; Settings is always on-device, never stored. */
export function normalizeNavigationPayload(
  n: NavigationPayload | undefined,
): Required<NavigationPayload> {
  const raw = (n?.visibleIds ?? []).filter((id) => SYNCABLE_NAV_ID_SET.has(id))
  const seen = new Set<string>()
  const ordered: string[] = []
  for (const id of raw) {
    if (seen.has(id)) continue
    seen.add(id)
    ordered.push(id)
  }
  const visibleIds = ordered.length ? ordered : [...DEFAULT_NAV_VISIBLE_IDS]
  let defaultTab = (n?.defaultTab ?? DEFAULT_NAV_TAB).trim() || DEFAULT_NAV_TAB
  if (defaultTab !== 'settings' && !visibleIds.includes(defaultTab)) {
    defaultTab = visibleIds.includes(DEFAULT_NAV_TAB)
      ? DEFAULT_NAV_TAB
      : (visibleIds[0] ?? DEFAULT_NAV_TAB)
  }
  return { visibleIds, defaultTab }
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
    max_playback_height: 0,
  }
}

export function emptyStremioPayload(): StremioPayload {
  return { addons: [] }
}

export function emptyNuvioPayload(): NuvioPayload {
  return { addons: [] }
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

function compactNavigation(n: NavigationPayload | undefined): NavigationPayload | undefined {
  if (!n) return undefined
  const normalized = normalizeNavigationPayload(n)
  const out: NavigationPayload = {
    visibleIds: normalized.visibleIds,
  }
  if (normalized.defaultTab) out.defaultTab = normalized.defaultTab
  return out
}

/** Compact before DB write: full playback; stremio/nuvio under connectedServices.
 * Provider order is device-local — never persist. Never write iptv (portals/M3U). */
export function compactProfileSettingsPayload(
  full: ProfileSettingsPayload,
): ProfileSettingsPayload {
  const playback = compactPlayback(full.playback)
  const stremio = compactStremio(full.connectedServices?.stremio)
  const nuvio = compactNuvio(full.connectedServices?.nuvio)
  const navigation = compactNavigation(full.navigation)

  const connectedServices: ConnectedServicesPayload = {}
  if (stremio) connectedServices.stremio = stremio
  if (nuvio) connectedServices.nuvio = nuvio

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

  void p.films

  return {
    playback: { ...base.playback, ...p.playback },
    connectedServices: { stremio, nuvio },
    navigation: normalizeNavigationPayload(p.navigation),
  }
}

/** @deprecated films no longer synced */
export type FilmRef = { tmdbId: number; mediaType: 'movie' | 'tv' }
