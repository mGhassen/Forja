/** Profile settings payload — must match Flutter SyncDomainBridge (lean storage). */

export type PreferencesPayload = {
  play_source_torrent_enabled?: boolean
  play_source_stremio_enabled?: boolean
  play_source_webstreaming_enabled?: boolean
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

export type ConnectedServicesPayload = {
  providers?: ProvidersPayload
  stremio?: StremioPayload
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

/** Cloud M3U row — metadata only (no channels[]). Portals live in user_iptv_portals. */
export type M3uPlaylistCloudRow = {
  id: string
  name: string
  sourceUrl: string
  addedAt: number
  updatedAt: number
}

export type M3uChannelRow = {
  n: string
  u: string
  l?: string
  g?: string
  ti?: string
  tn?: string
}

/** Local/UI playlist; channels are device-local and never written to cloud. */
export type M3uPlaylistRow = {
  id: string
  name: string
  sourceUrl: string | null
  addedAt: number
  updatedAt: number
  channels?: M3uChannelRow[]
}

/** Settings-only IPTV slice: M3U URLs. Portal assignments are user_iptv_portals. */
export type IptvSettingsPayload = {
  m3uPlaylists?: M3uPlaylistCloudRow[]
}

export type ProfileSettingsPayload = {
  playback?: PreferencesPayload
  connectedServices?: ConnectedServicesPayload
  navigation?: NavigationPayload
  iptv?: IptvSettingsPayload
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

export const DEFAULT_STREAM_PROVIDER_ORDER = [
  'videasy',
  'vidlink',
  'vidsrc',
  'vidsrcwin',
  'vixsrc',
  'vidnest',
  'vidzee',
  'vidrock',
  'vidfast',
  '2embed',
  'autoembed',
  'vidlove',
  'vidsrcsbs',
  '111movies',
  'moviesapi',
  'service111477',
  'webstreamr',
] as const

export const DEFAULT_ANIME_PROVIDER_ORDER = [
  'miruro:bee',
  'allanime:Default',
  'allanime:Yt-mp4',
  'allanime:S-mp4',
  'allanime:Luf-Mp4',
  'vidnest:hianime',
  'vidnest:animepahe',
  'megaplay',
  'vidwish',
  'miruro:zoro',
  'miruro:kiwi',
  'miruro:ally',
  'miruro:hop',
  'miruro:bonk',
  'miruro:moo',
] as const

export const DEFAULT_ASIAN_DRAMA_PROVIDER_ORDER = [
  'kisskh.co',
  'kisskh.nl',
  'kisskh.ovh',
  'kisskh.la',
  'kisskh.do',
] as const

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
  key: keyof ProfileSettingsPayload | 'providers' | 'stremio'
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
      'Play sources (torrent / Stremio / web), auto next, audio language, and quality cap.',
    href: '/account/settings/playback',
  },
  {
    key: 'navigation',
    title: 'Navigation',
    description: 'Which shell tabs are visible and which opens by default.',
    href: '/account/settings/navigation',
  },
  {
    key: 'providers',
    title: 'Provider order',
    description: 'Priority for film and series, anime, and Asian drama hosts.',
    href: '/account/settings/providers',
  },
  {
    key: 'stremio',
    title: 'Stremio addons',
    description: 'Addon manifest URLs installed on your account.',
    href: '/account/settings/stremio',
  },
]

export function emptyProfileSettingsPayload(): ProfileSettingsPayload {
  return {
    playback: emptyPreferencesPayload(),
    connectedServices: {
      providers: emptyProvidersPayload(),
      stremio: emptyStremioPayload(),
    },
    navigation: emptyNavigationPayload(),
    iptv: emptyIptvSettingsPayload(),
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
    if (seen.add(id)) ordered.push(id)
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

export function emptyIptvSettingsPayload(): IptvSettingsPayload {
  return { m3uPlaylists: [] }
}

export function emptyPreferencesPayload(): Required<PreferencesPayload> {
  return {
    play_source_torrent_enabled: true,
    play_source_stremio_enabled: true,
    play_source_webstreaming_enabled: true,
    preferred_audio_lang: 'None',
    avoid_unsupported_audio: true,
    auto_next_episode: true,
    auto_skip_intro: false,
    iptv_epg_enabled: true,
    max_playback_height: 0,
  }
}

export function emptyProvidersPayload(): Required<ProvidersPayload> {
  return {
    stream_provider_order: [...DEFAULT_STREAM_PROVIDER_ORDER],
    anime_provider_order: [...DEFAULT_ANIME_PROVIDER_ORDER],
    asian_drama_provider_order: [...DEFAULT_ASIAN_DRAMA_PROVIDER_ORDER],
  }
}

export function emptyStremioPayload(): StremioPayload {
  return { addons: [] }
}

function arraysEqual(a: string[] | undefined, b: readonly string[]): boolean {
  if (!a || a.length !== b.length) return false
  return a.every((v, i) => v === b[i])
}

/** Persist full playback prefs (incl. play_source_* modes) — never strip to empty. */
function compactPlayback(p: PreferencesPayload | undefined): PreferencesPayload | undefined {
  if (!p) return undefined
  const d = emptyPreferencesPayload()
  return { ...d, ...p }
}

function compactProviders(p: ProvidersPayload | undefined): ProvidersPayload | undefined {
  if (!p) return undefined
  const out: ProvidersPayload = {}
  if (
    p.stream_provider_order &&
    !arraysEqual(p.stream_provider_order, DEFAULT_STREAM_PROVIDER_ORDER)
  ) {
    out.stream_provider_order = p.stream_provider_order
  }
  if (
    p.anime_provider_order &&
    !arraysEqual(p.anime_provider_order, DEFAULT_ANIME_PROVIDER_ORDER)
  ) {
    out.anime_provider_order = p.anime_provider_order
  }
  if (
    p.asian_drama_provider_order &&
    !arraysEqual(p.asian_drama_provider_order, DEFAULT_ASIAN_DRAMA_PROVIDER_ORDER)
  ) {
    out.asian_drama_provider_order = p.asian_drama_provider_order
  }
  return Object.keys(out).length ? out : undefined
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

function compactNavigation(n: NavigationPayload | undefined): NavigationPayload | undefined {
  if (!n) return undefined
  const normalized = normalizeNavigationPayload(n)
  const out: NavigationPayload = {
    visibleIds: normalized.visibleIds,
  }
  if (normalized.defaultTab) out.defaultTab = normalized.defaultTab
  return out
}

/** M3U URL metadata only — portal assignments are user_iptv_portals. */
function compactIptv(i: IptvSettingsPayload | undefined): IptvSettingsPayload | undefined {
  if (!i) return undefined
  const m3uPlaylists = (i.m3uPlaylists ?? [])
    .map((pl) => {
      const sourceUrl =
        typeof pl.sourceUrl === 'string' ? pl.sourceUrl.trim() : ''
      if (!sourceUrl) return null
      return {
        id: pl.id,
        name: pl.name,
        sourceUrl,
        addedAt: pl.addedAt,
        updatedAt: pl.updatedAt,
      } satisfies M3uPlaylistCloudRow
    })
    .filter((pl): pl is M3uPlaylistCloudRow => pl != null)

  if (!m3uPlaylists.length) return undefined
  return { m3uPlaylists }
}

/** Compact before DB write: full playback; omit default provider orders; M3U only under iptv. */
export function compactProfileSettingsPayload(
  full: ProfileSettingsPayload,
): ProfileSettingsPayload {
  const playback = compactPlayback(full.playback)
  const providers = compactProviders(full.connectedServices?.providers)
  const stremio = compactStremio(full.connectedServices?.stremio)
  const navigation = compactNavigation(full.navigation)
  const iptv = compactIptv(full.iptv)

  const connectedServices: ConnectedServicesPayload = {}
  if (providers) connectedServices.providers = providers
  if (stremio) connectedServices.stremio = stremio

  const out: ProfileSettingsPayload = {}
  if (playback) out.playback = playback
  if (Object.keys(connectedServices).length) out.connectedServices = connectedServices
  if (navigation) out.navigation = navigation
  if (iptv) out.iptv = iptv
  return out
}

/** Expand lean cloud payload to full in-memory defaults. */
export function expandProfileSettingsPayload(raw: unknown): ProfileSettingsPayload {
  const base = emptyProfileSettingsPayload()
  if (!raw || typeof raw !== 'object') return base
  const p = raw as ProfileSettingsPayload & { films?: unknown }

  const providers = {
    ...base.connectedServices!.providers!,
    ...p.connectedServices?.providers,
  }
  const stremio = {
    addons: p.connectedServices?.stremio?.addons ?? [],
  }

  const m3uPlaylists = (p.iptv?.m3uPlaylists ?? [])
    .map((pl) => {
      const sourceUrl =
        typeof pl.sourceUrl === 'string' ? pl.sourceUrl.trim() : ''
      if (!sourceUrl) return null
      return {
        id: pl.id,
        name: pl.name,
        sourceUrl,
        addedAt: pl.addedAt,
        updatedAt: pl.updatedAt,
      } satisfies M3uPlaylistCloudRow
    })
    .filter((pl): pl is M3uPlaylistCloudRow => pl != null)

  void p.films

  return {
    playback: { ...base.playback, ...p.playback },
    connectedServices: { providers, stremio },
    navigation: normalizeNavigationPayload(p.navigation),
    iptv: { m3uPlaylists },
  }
}

/** @deprecated legacy alias */
export type IptvPayload = IptvSettingsPayload
export function emptyIptvPayload(): IptvPayload {
  return emptyIptvSettingsPayload()
}

/** @deprecated films no longer synced */
export type FilmRef = { tmdbId: number; mediaType: 'movie' | 'tv' }
