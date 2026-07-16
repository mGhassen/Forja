/** Sync domain payloads - must match Flutter `SyncDomainBridge` export/import. */

export const SYNC_DOMAINS = {
  iptv: 'iptv',
  preferences: 'preferences',
  providers: 'providers',
  stremio: 'stremio',
} as const

export type SyncDomain = (typeof SYNC_DOMAINS)[keyof typeof SYNC_DOMAINS]

export type IptvPortalRow = {
  url: string
  username: string
  password: string
  source?: string
  /** User-chosen portal name (matches Flutter `VerifiedPortal.label`). */
  label?: string
  /** Xtream account name from the provider (Flutter `VerifiedPortal.name`). */
  name?: string
  expiry?: string
  max?: string
  active?: string
}

/** Prefer user label, then provider name, then username. */
export function portalDisplayLabel(
  portal: Pick<IptvPortalRow, 'label' | 'name' | 'username'>,
): string {
  const label = portal.label?.trim()
  if (label) return label
  const name = portal.name?.trim()
  if (name) return name
  const user = portal.username?.trim()
  return user || 'Portal'
}

export type M3uChannelRow = {
  n: string
  u: string
  l?: string
  g?: string
  ti?: string
  tn?: string
}

export type M3uPlaylistRow = {
  id: string
  name: string
  sourceUrl: string | null
  addedAt: number
  updatedAt: number
  channels: M3uChannelRow[]
}

export type IptvPayload = {
  portals: IptvPortalRow[]
  favoriteKeys?: string[]
  m3uPlaylists?: M3uPlaylistRow[]
}

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
  domain: SyncDomain
  title: string
  description: string
  href: string
}

export const REMOTE_SETTING_SECTIONS: RemoteSettingSection[] = [
  {
    domain: SYNC_DOMAINS.iptv,
    title: 'IPTV portals',
    description: 'Xtream portals and M3U playlists - synced to every signed-in device.',
    href: '/account/settings/iptv',
  },
  {
    domain: SYNC_DOMAINS.preferences,
    title: 'Playback',
    description: 'Play sources, auto next episode, audio language, and quality cap.',
    href: '/account/settings/playback',
  },
  {
    domain: SYNC_DOMAINS.providers,
    title: 'Provider order',
    description: 'Priority for film and series, anime, and Asian drama hosts.',
    href: '/account/settings/providers',
  },
  {
    domain: SYNC_DOMAINS.stremio,
    title: 'Stremio addons',
    description: 'Addon manifest URLs installed on your account.',
    href: '/account/settings/stremio',
  },
]

export function portalKey(row: Pick<IptvPortalRow, 'url' | 'username' | 'password'>): string {
  return `${row.url}|${row.username}|${row.password}`.toLowerCase()
}

export function emptyIptvPayload(): IptvPayload {
  return { portals: [], favoriteKeys: [], m3uPlaylists: [] }
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
