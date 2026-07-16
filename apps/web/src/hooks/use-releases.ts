import { useQuery } from '@tanstack/react-query'
import { supabase, supabaseConfigured } from '@/lib/supabase'
import type { Release, ReleaseAsset } from '@/lib/database.types'

export type ReleaseWithAssets = Release & { assets: ReleaseAsset[] }

export type ShowcasePlatformId = 'windows' | 'macos' | 'linux' | 'android_tv'

export type ShowcasePlatform = {
  id: ShowcasePlatformId
  label: string
  tagline: string
  format: string
  /** Matches release_assets.platform values. */
  match: string[]
}

/** Platforms Forja ships today. */
export const SHOWCASE_PLATFORMS: ShowcasePlatform[] = [
  {
    id: 'windows',
    label: 'Windows',
    tagline: 'Windows installer for the full Forja player.',
    format: 'For your PC',
    match: ['windows'],
  },
  {
    id: 'macos',
    label: 'macOS',
    tagline: 'macOS app for Mac.',
    format: 'For your Mac',
    match: ['macos'],
  },
  {
    id: 'linux',
    label: 'Linux',
    tagline: 'Linux build with the same player.',
    format: 'For Linux',
    match: ['linux'],
  },
  {
    id: 'android_tv',
    label: 'Android TV',
    tagline: 'Android TV app for your living-room TV.',
    format: 'For the TV',
    match: ['android_tv', 'android'],
  },
]

const GITHUB_REPO = 'mGhassen/Forja'
const GITHUB_LATEST = `https://api.github.com/repos/${GITHUB_REPO}/releases/latest`

type GhAsset = {
  id: number
  name: string
  browser_download_url: string
  size: number
}

type GhRelease = {
  id: number
  tag_name: string
  body: string | null
  published_at: string
  html_url: string
  assets: GhAsset[]
}

function detectPlatform(name: string): string {
  const lower = name.toLowerCase()
  if (lower.includes('windows') || lower.endsWith('.exe') || lower.endsWith('.msi')) {
    return 'windows'
  }
  if (lower.includes('macos') || lower.includes('darwin') || lower.endsWith('.dmg')) {
    return 'macos'
  }
  if (
    lower.includes('linux') ||
    lower.endsWith('.appimage') ||
    lower.endsWith('.deb') ||
    lower.endsWith('.rpm')
  ) {
    return 'linux'
  }
  if (
    lower.includes('android-tv') ||
    lower.includes('android_tv') ||
    lower.includes('androidtv')
  ) {
    return 'android_tv'
  }
  if (lower.endsWith('.apk') || lower.includes('android')) {
    return 'android_tv'
  }
  if (lower.includes('ios') || lower.endsWith('.ipa')) {
    return 'ios'
  }
  return 'other'
}

function fromGitHub(release: GhRelease): ReleaseWithAssets {
  const version = release.tag_name.replace(/^v/, '')
  const releaseId = `gh-${release.id}`
  return {
    id: releaseId,
    tag: release.tag_name,
    version,
    body: release.body,
    published_at: release.published_at,
    html_url: release.html_url,
    source: 'github',
    synced_at: new Date().toISOString(),
    assets: (release.assets ?? []).map((asset) => ({
      id: `gh-asset-${asset.id}`,
      release_id: releaseId,
      platform: detectPlatform(asset.name),
      name: asset.name,
      download_url: asset.browser_download_url,
      size_bytes: asset.size,
    })),
  }
}

async function fetchGitHubLatest(): Promise<ReleaseWithAssets | null> {
  const res = await fetch(GITHUB_LATEST, {
    headers: {
      Accept: 'application/vnd.github+json',
      'User-Agent': 'forja-web',
    },
  })
  if (!res.ok) {
    throw new Error(`GitHub releases ${res.status}`)
  }
  const release = (await res.json()) as GhRelease
  return fromGitHub(release)
}

async function fetchSupabaseLatest(): Promise<ReleaseWithAssets | null> {
  if (!supabaseConfigured) return null

  const { data, error } = await supabase
    .from('releases')
    .select('*')
    .order('published_at', { ascending: false })
    .limit(1)
    .maybeSingle()

  if (error) throw error
  if (!data) return null

  const release = data as Release

  const { data: assetsData, error: assetsError } = await supabase
    .from('release_assets')
    .select('*')
    .eq('release_id', release.id)

  if (assetsError) throw assetsError

  const assets = (assetsData ?? []) as ReleaseAsset[]
  if (!assets.length) return null

  return { ...release, assets }
}

/**
 * Latest release for download buttons.
 * Prefer GitHub Releases (always public); use Supabase mirror only if it has assets.
 */
export function useLatestRelease() {
  return useQuery({
    queryKey: ['releases', 'latest'],
    queryFn: async (): Promise<ReleaseWithAssets | null> => {
      try {
        const mirrored = await fetchSupabaseLatest()
        if (mirrored?.assets.length) return mirrored
      } catch {
        /* fall through to GitHub */
      }
      return fetchGitHubLatest()
    },
    staleTime: 60_000,
  })
}

export function assetsForPlatform(
  assets: ReleaseAsset[] | undefined,
  platform: ShowcasePlatform,
): ReleaseAsset[] {
  if (!assets?.length) return []
  return assets.filter((a) => platform.match.includes(a.platform))
}

/** Prefer the same installer the app updater would pick for that platform. */
export function primaryAssetForPlatform(
  assets: ReleaseAsset[] | undefined,
  platform: ShowcasePlatform,
): ReleaseAsset | null {
  const list = assetsForPlatform(assets, platform)
  if (!list.length) return null

  const name = (a: ReleaseAsset) => a.name.toLowerCase()
  const find = (ok: (n: string) => boolean) => list.find((a) => ok(name(a)))

  switch (platform.id) {
    case 'windows':
      return (
        find((n) => n.includes('windows') && n.endsWith('.exe')) ??
        list[0] ??
        null
      )
    case 'macos':
      return (
        find((n) => n.includes('arm64') && n.endsWith('.dmg')) ??
        find((n) => n.endsWith('.dmg')) ??
        list[0] ??
        null
      )
    case 'linux':
      return (
        find(
          (n) =>
            n.includes('linux') &&
            (n.endsWith('.appimage') || n.endsWith('.deb')),
        ) ??
        list[0] ??
        null
      )
    case 'android_tv':
      return (
        find((n) => n.includes('android-tv') && n.endsWith('.apk')) ??
        find((n) => n.endsWith('.apk')) ??
        list[0] ??
        null
      )
    default:
      return list[0] ?? null
  }
}

/** Latest primary download URL per showcase platform (null when missing). */
export function primaryDownloadsByPlatform(
  assets: ReleaseAsset[] | undefined,
): Record<ShowcasePlatformId, ReleaseAsset | null> {
  const out = {} as Record<ShowcasePlatformId, ReleaseAsset | null>
  for (const p of SHOWCASE_PLATFORMS) {
    out[p.id] = primaryAssetForPlatform(assets, p)
  }
  return out
}
