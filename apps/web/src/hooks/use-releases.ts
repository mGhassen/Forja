import { useQuery } from '@tanstack/react-query'
import { compareSemverDesc } from '@/lib/changelog-docs'
import type { R2ChangelogArchive } from '@/lib/r2-changelog'
import type { R2LatestRelease } from '@/lib/r2-latest-release'
import { detectPlatformFromFilename } from '@/lib/r2-latest-release'

/** Release row used by download + changelog UI (R2-backed). */
export type ReleaseAsset = {
  id: string
  release_id: string
  platform: string
  /** Semver of the release that published this asset (per-platform latest). */
  version?: string
  name: string
  download_url: string
  size_bytes: number | null
}

export type Release = {
  id: string
  tag: string
  version: string
  body: string | null
  published_at: string
  html_url: string | null
  source: string
  synced_at: string
}

export type ReleaseWithAssets = Release & {
  assets: ReleaseAsset[]
  /** Changelog markdown keyed by version (download page uses selected platform). */
  notesByVersion?: Record<string, string>
  /** Latest version per showcase platform id. */
  platformVersions?: Record<string, string>
}

export type ShowcasePlatformId = 'windows' | 'macos' | 'linux' | 'android_tv'

export type ShowcasePlatform = {
  id: ShowcasePlatformId
  label: string
  tagline: string
  format: string
  /** Matches release asset platform values. */
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

/** Changelog menu shows at most this many stable releases. */
export const CHANGELOG_MENU_LIMIT = 20

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
  text = text
    .split('\n')
    .filter((line) => {
      const t = line.trim()
      if (!t) return true
      if (/github\.com\/\S+/i.test(t) && !/^[-*]\s+\*\*(Add|Change|Fix|Remove):/i.test(t)) {
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

async function fetchLatestReleaseFromApi(): Promise<ReleaseWithAssets | null> {
  const res = await fetch('/api/latest-release', {
    headers: { Accept: 'application/json' },
  })
  if (!res.ok) {
    throw new Error(`Latest release ${res.status}`)
  }
  const release = (await res.json()) as R2LatestRelease | null
  if (!release?.version || !release.assets?.length) return null
  return {
    ...release,
    notesByVersion: release.notesByVersion ?? {},
    platformVersions: release.platformVersions ?? {},
    assets: release.assets.map((asset) => ({
      ...asset,
      platform: asset.platform || detectPlatformFromFilename(asset.name),
      version: asset.version || release.version,
    })),
  }
}

/**
 * Changelog entries from R2 `changelog/` (via /api/changelog).
 */
export function mergeChangelogReleases(
  r2Notes: Record<string, string>,
): ReleaseWithAssets[] {
  return Object.entries(r2Notes)
    .map(([version, markdown]) => fromR2Changelog(version, markdown))
    .sort((a, b) => compareSemverDesc(a.version, b.version))
    .slice(0, CHANGELOG_MENU_LIMIT)
}

/**
 * Latest release for download buttons — version/assets from R2
 * `latest/manifest.json` (via /api/latest-release); URLs point at CDN `latest/`.
 */
export function useLatestRelease() {
  return useQuery({
    queryKey: ['releases', 'latest'],
    queryFn: async (): Promise<ReleaseWithAssets | null> =>
      fetchLatestReleaseFromApi(),
    staleTime: 60_000,
  })
}

/**
 * Changelog entries from R2 `changelog/` (via /api/changelog).
 */
export function useAllReleases() {
  return useQuery({
    queryKey: ['releases', 'changelog'],
    queryFn: async (): Promise<ReleaseWithAssets[]> => {
      const r2Notes = await fetchR2ChangelogNotes()
      return mergeChangelogReleases(r2Notes)
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

/** Version string for a showcase platform from merged latest release. */
export function versionForPlatform(
  release: ReleaseWithAssets | null | undefined,
  platformId: ShowcasePlatformId,
): string | null {
  const fromMap = release?.platformVersions?.[platformId]
  if (fromMap) return fromMap
  const platform = SHOWCASE_PLATFORMS.find((p) => p.id === platformId)
  if (!platform) return null
  return primaryAssetForPlatform(release?.assets, platform)?.version ?? null
}

/** Changelog markdown for a showcase platform's latest version. */
export function notesForPlatform(
  release: ReleaseWithAssets | null | undefined,
  platformId: ShowcasePlatformId,
): string | null {
  const version = versionForPlatform(release, platformId)
  if (!version) return null
  return release?.notesByVersion?.[version] ?? null
}
