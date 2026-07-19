import { useQuery } from '@tanstack/react-query'
import type { Release, ReleaseAsset } from '@/lib/database.types'
import { compareSemverDesc } from '@/lib/changelog-docs'
import type { R2ChangelogArchive } from '@/lib/r2-changelog'
import { preferReleaseStorageUrl } from '@/lib/release-storage'

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
/** Changelog menu shows at most this many stable releases. */
export const CHANGELOG_MENU_LIMIT = 20

/** Optional: enrich R2 notes with GitHub published_at / assets. */
const GITHUB_RELEASES = `https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=100`

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
  draft?: boolean
  prerelease?: boolean
  assets: GhAsset[]
}

const FULL_CHANGELOG_LINE =
  /^\s*(?:\*\*)?Full Changelog(?:\*\*)?\s*:\s*\S+\s*$/gim
const GITHUB_URL_LINE =
  /^\s*(?:[-*]\s+)?(?:\*\*)?(?:See\s+)?(?:the\s+)?(?:changelog|release notes)?(?:\*\*)?\s*:?\s*https?:\/\/github\.com\/\S+\s*$/gim

/**
 * Strip GitHub auto-generated compare links and other github.com-only lines
 * so the web UI never pushes people to GitHub.
 */
export function cleanReleaseBody(raw: string | null | undefined): string {
  if (!raw) return ''
  let text = raw.replace(/\r\n/g, '\n').trim()
  if (!text) return ''

  text = text.replace(FULL_CHANGELOG_LINE, '').trim()
  text = text.replace(GITHUB_URL_LINE, '').trim()
  // Drop any remaining bare github.com URLs inside otherwise empty-looking lines.
  text = text
    .split('\n')
    .filter((line) => {
      const t = line.trim()
      if (!t) return true
      if (/github\.com\/\S+/i.test(t) && !/^[-*]\s+\*\*(Add|Change|Fix|Remove):/i.test(t)) {
        // Keep bullet notes that merely mention GitHub; drop link-only lines.
        const withoutUrl = t.replace(/https?:\/\/github\.com\/\S+/gi, '').replace(/\*\*/g, '').trim()
        if (!withoutUrl || /^full changelog:?$/i.test(withoutUrl)) return false
      }
      return true
    })
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()

  return text
}

/** True when cleaned markdown still has user-facing change bullets. */
export function hasChangelogBullets(raw: string | null | undefined): boolean {
  const cleaned = cleanReleaseBody(raw)
  if (!cleaned) return false
  return cleaned.split('\n').some((line) => /^[-*]\s+/.test(line.trim()))
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
      // Installers on R2 (`latest/` + versioned); GitHub stays discovery-only.
      download_url: preferReleaseStorageUrl(
        version,
        asset.name,
        asset.browser_download_url,
      ),
      size_bytes: asset.size,
    })),
  }
}

const GH_HEADERS = {
  Accept: 'application/vnd.github+json',
  'User-Agent': 'forja-web',
} as const

async function fetchGitHubLatest(): Promise<ReleaseWithAssets | null> {
  const res = await fetch(GITHUB_LATEST, { headers: GH_HEADERS })
  if (!res.ok) {
    throw new Error(`GitHub releases ${res.status}`)
  }
  const release = (await res.json()) as GhRelease
  return fromGitHub(release)
}

async function fetchGitHubReleases(): Promise<ReleaseWithAssets[]> {
  const res = await fetch(GITHUB_RELEASES, { headers: GH_HEADERS })
  if (!res.ok) {
    throw new Error(`GitHub releases ${res.status}`)
  }
  const list = (await res.json()) as GhRelease[]
  if (!Array.isArray(list)) return []
  return list.filter((r) => !r.draft && !r.prerelease).map(fromGitHub)
}

function fromR2Changelog(version: string, markdown: string): ReleaseWithAssets {
  return {
    id: `r2-${version}`,
    tag: `v${version}`,
    version,
    body: markdown,
    published_at: '',
    html_url: null,
    source: 'r2',
    synced_at: new Date().toISOString(),
    assets: [],
  }
}

async function fetchR2ChangelogNotes(): Promise<Record<string, string>> {
  const res = await fetch('/api/changelog', {
    headers: { Accept: 'application/json' },
  })
  if (!res.ok) {
    throw new Error(`changelog API ${res.status}`)
  }
  const archive = (await res.json()) as R2ChangelogArchive
  return archive.notes ?? {}
}

/**
 * Prefer R2 `changelog/` notes when they have bullets; otherwise keep the
 * GitHub release body (after clean). Union both sources by version.
 */
export function mergeChangelogReleases(
  github: ReleaseWithAssets[],
  r2Notes: Record<string, string>,
): ReleaseWithAssets[] {
  const byVersion = new Map<string, ReleaseWithAssets>()

  for (const release of github) {
    byVersion.set(release.version, { ...release, assets: [...release.assets] })
  }

  for (const [version, markdown] of Object.entries(r2Notes)) {
    const existing = byVersion.get(version)
    const r2HasNotes = hasChangelogBullets(markdown)
    if (existing) {
      const ghHasNotes = hasChangelogBullets(existing.body)
      if (r2HasNotes || !ghHasNotes) {
        existing.body = markdown
        if (existing.source === 'github') {
          existing.source = 'github+r2'
        }
      }
      continue
    }
    byVersion.set(version, fromR2Changelog(version, markdown))
  }

  return [...byVersion.values()]
    .sort((a, b) => compareSemverDesc(a.version, b.version))
    .slice(0, CHANGELOG_MENU_LIMIT)
}

/**
 * Latest release for download buttons — version/assets from GitHub;
 * download URLs point at Supabase Storage when configured.
 */
export function useLatestRelease() {
  return useQuery({
    queryKey: ['releases', 'latest'],
    queryFn: async (): Promise<ReleaseWithAssets | null> => fetchGitHubLatest(),
    staleTime: 60_000,
  })
}

/**
 * Changelog entries from R2 `changelog/` (via /api/changelog).
 * GitHub optionally fills published_at / assets when reachable.
 */
export function useAllReleases() {
  return useQuery({
    queryKey: ['releases', 'changelog'],
    queryFn: async (): Promise<ReleaseWithAssets[]> => {
      const r2Notes = await fetchR2ChangelogNotes()
      const r2Only = mergeChangelogReleases([], r2Notes)

      const controller = new AbortController()
      const timer = setTimeout(() => controller.abort(), 8_000)
      try {
        const res = await fetch(GITHUB_RELEASES, {
          headers: GH_HEADERS,
          signal: controller.signal,
        })
        if (!res.ok) return r2Only
        const list = (await res.json()) as GhRelease[]
        if (!Array.isArray(list)) return r2Only
        const github = list.filter((r) => !r.draft && !r.prerelease).map(fromGitHub)
        return mergeChangelogReleases(github, r2Notes)
      } catch {
        return r2Only
      } finally {
        clearTimeout(timer)
      }
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
