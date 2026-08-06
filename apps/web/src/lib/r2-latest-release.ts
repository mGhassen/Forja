/**
 * Server-side fetch of R2 `latest/manifest.json`.
 * Browser uses /api/latest-release — CDN has no CORS for the portal.
 *
 * Manifest is per-platform: partial releases merge into `platforms` and keep
 * other platforms' previous latest installers.
 */

import {
  releaseCdnLatestUrl,
} from '@/lib/release-storage'

export type R2PlatformEntry = {
  version: string
  published_at?: string
  assets: string[]
  /** AFTVnews Downloader short codes keyed by arch (android_tv only). */
  downloader_codes?: Record<string, string>
}

export type R2LatestManifest = {
  version?: string
  published_at?: string
  assets?: string[]
  platforms?: Record<string, R2PlatformEntry>
}

export type R2LatestReleaseAsset = {
  id: string
  release_id: string
  platform: string
  /** Semver of the release that published this asset (per-platform). */
  version: string
  name: string
  download_url: string
  size_bytes: number | null
  /** AFTVnews Downloader numeric code for this APK (Android TV). */
  downloader_code?: string | null
}


export type R2LatestRelease = {
  id: string
  tag: string
  /** Max version across platforms (legacy / glance). */
  version: string
  body: string | null
  published_at: string
  html_url: string | null
  source: 'r2'
  synced_at: string
  assets: R2LatestReleaseAsset[]
  /** Changelog markdown keyed by version (for platform-specific What's new). */
  notesByVersion: Record<string, string>
  /** Latest version per showcase platform id. */
  platformVersions: Record<string, string>
}

function cdnBase(): string | null {
  const raw = (
    process.env.RELEASE_CDN_URL ||
    process.env.VITE_RELEASE_CDN_URL ||
    ''
  ).trim()
  if (!raw) return null
  return raw.replace(/\/$/, '')
}

/** Semver embedded in installer filenames (`Forja-1.3.35-macos-arm64.dmg`). */
export function versionFromFilename(name: string): string | null {
  const match = name.match(/(?:^|[^0-9])(\d+\.\d+\.\d+)(?:[^0-9]|$)/)
  return match?.[1] ?? null
}

export function detectPlatformFromFilename(name: string): string {
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

/** Architecture slot matching R2 upload / Downloader codes (arm64, …). */
export function detectArchFromFilename(name: string): string {
  const lower = name.toLowerCase()
  if (lower.includes('armeabi-v7a') || lower.includes('armeabi_v7a')) {
    return 'armeabi-v7a'
  }
  if (lower.includes('arm64') || lower.includes('aarch64')) return 'arm64'
  if (
    lower.includes('x86_64') ||
    lower.includes('x86-64') ||
    lower.includes('amd64')
  ) {
    return 'x86_64'
  }
  if (/\bx86\b/.test(lower) || lower.includes('i686')) return 'x86'
  return 'default'
}

function normalizeDownloaderCodes(
  raw: unknown,
): Record<string, string> | undefined {
  if (!raw || typeof raw !== 'object') return undefined
  const out: Record<string, string> = {}
  for (const [arch, code] of Object.entries(raw as Record<string, unknown>)) {
    if (typeof arch !== 'string' || !arch.trim()) continue
    const s = typeof code === 'number' ? String(code) : typeof code === 'string' ? code.trim() : ''
    if (!s || !/^\d+$/.test(s)) continue
    out[arch.trim()] = s
  }
  return Object.keys(out).length ? out : undefined
}

function normalizePlatforms(
  manifest: R2LatestManifest,
): Record<
  string,
  {
    version: string
    published_at?: string
    assets: string[]
    downloader_codes?: Record<string, string>
  }
> {
  const out: Record<
    string,
    {
      version: string
      published_at?: string
      assets: string[]
      downloader_codes?: Record<string, string>
    }
  > = {}

  if (manifest.platforms && typeof manifest.platforms === 'object') {
    for (const [key, entry] of Object.entries(manifest.platforms)) {
      if (!entry || typeof entry !== 'object') continue
      const version =
        typeof entry.version === 'string' ? entry.version.replace(/^v/, '').trim() : ''
      const assets = Array.isArray(entry.assets)
        ? entry.assets.filter((a): a is string => typeof a === 'string' && a.trim().length > 0)
        : []
      if (!version || !assets.length) continue
      const codes = normalizeDownloaderCodes(entry.downloader_codes)
      out[key] = {
        version,
        published_at:
          typeof entry.published_at === 'string' ? entry.published_at : undefined,
        assets,
        ...(codes ? { downloader_codes: codes } : {}),
      }
    }
  }

  if (Object.keys(out).length > 0) return out

  // Legacy flat manifest: one version for every asset.
  const version =
    typeof manifest.version === 'string' ? manifest.version.replace(/^v/, '').trim() : ''
  const assets = Array.isArray(manifest.assets)
    ? manifest.assets.filter((a): a is string => typeof a === 'string' && a.trim().length > 0)
    : []
  if (!version || !assets.length) return out

  for (const name of assets) {
    const platform = detectPlatformFromFilename(name)
    if (platform === 'other' || platform === 'ios') continue
    const bucket = out[platform] ?? {
      version,
      published_at:
        typeof manifest.published_at === 'string' ? manifest.published_at : undefined,
      assets: [] as string[],
    }
    bucket.assets.push(name)
    out[platform] = bucket
  }
  return out
}

export function fromR2Manifest(
  base: string,
  manifest: R2LatestManifest,
  notesByVersion: Record<string, string> = {},
): R2LatestRelease | null {
  const platforms = normalizePlatforms(manifest)
  if (!Object.keys(platforms).length) return null

  const platformVersions: Record<string, string> = {}
  const assets: R2LatestReleaseAsset[] = []
  let maxVersion = ''
  let publishedAt =
    typeof manifest.published_at === 'string' && manifest.published_at.trim()
      ? manifest.published_at.trim()
      : new Date().toISOString()

  for (const [platform, entry] of Object.entries(platforms)) {
    platformVersions[platform] = entry.version
    if (!maxVersion || compareSemver(entry.version, maxVersion) > 0) {
      maxVersion = entry.version
    }
    if (entry.published_at) publishedAt = entry.published_at
    for (let i = 0; i < entry.assets.length; i++) {
      const name = entry.assets[i]
      const fileVersion = versionFromFilename(name) ?? entry.version
      const arch = detectArchFromFilename(name)
      const code = entry.downloader_codes?.[arch]
      assets.push({
        id: `r2-asset-${platform}-${fileVersion}-${i}`,
        release_id: `r2-${fileVersion}`,
        platform,
        version: fileVersion,
        name,
        download_url: releaseCdnLatestUrl(base, name),
        size_bytes: null,
        downloader_code: code ?? null,
      })
    }
  }

  if (!maxVersion || !assets.length) return null

  const body = notesByVersion[maxVersion] ?? null

  return {
    id: `r2-${maxVersion}`,
    tag: `v${maxVersion}`,
    version: maxVersion,
    body,
    published_at: publishedAt,
    html_url: null,
    source: 'r2',
    synced_at: new Date().toISOString(),
    assets,
    notesByVersion,
    platformVersions,
  }
}

function compareSemver(a: string, b: string): number {
  const pa = a.replace(/^v/, '').split('.').map((x) => parseInt(x, 10) || 0)
  const pb = b.replace(/^v/, '').split('.').map((x) => parseInt(x, 10) || 0)
  for (let i = 0; i < 3; i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0)
    if (d !== 0) return d
  }
  return 0
}

async function fetchChangelogBody(
  base: string,
  version: string,
): Promise<string | null> {
  const ver = version.replace(/^v/, '')
  const res = await fetch(`${base}/changelog/${ver}.md`, {
    headers: {
      Accept: 'text/markdown, text/plain, */*',
      'User-Agent': 'forja-web',
    },
  })
  if (!res.ok) return null
  const body = (await res.text()).trim()
  return body || null
}

export async function fetchR2LatestRelease(): Promise<R2LatestRelease | null> {
  const base = cdnBase()
  if (!base) {
    throw new Error('RELEASE_CDN_URL is not configured')
  }

  const res = await fetch(`${base}/latest/manifest.json`, {
    headers: {
      Accept: 'application/json',
      'User-Agent': 'forja-web',
    },
  })
  if (res.status === 404) return null
  if (!res.ok) {
    throw new Error(`release manifest HTTP ${res.status}`)
  }

  const decoded = (await res.json()) as Partial<R2LatestManifest>
  const platforms = normalizePlatforms(decoded as R2LatestManifest)
  if (!Object.keys(platforms).length) return null

  // Include filename semvers so split-arch releases (e.g. macOS arm64 ≠ Intel)
  // still get their changelog bodies, not only the platform bucket version.
  const uniqueVersions = [
    ...new Set(
      Object.values(platforms).flatMap((p) => [
        p.version,
        ...p.assets
          .map((name) => versionFromFilename(name))
          .filter((v): v is string => !!v),
      ]),
    ),
  ]
  const notesEntries = await Promise.all(
    uniqueVersions.map(async (version) => {
      const body = await fetchChangelogBody(base, version)
      return [version, body] as const
    }),
  )
  const notesByVersion: Record<string, string> = {}
  for (const [version, body] of notesEntries) {
    if (body) notesByVersion[version] = body
  }

  return fromR2Manifest(
    base,
    {
      version:
        typeof decoded.version === 'string' ? decoded.version : undefined,
      published_at:
        typeof decoded.published_at === 'string' ? decoded.published_at : undefined,
      assets: Array.isArray(decoded.assets)
        ? decoded.assets.filter((a): a is string => typeof a === 'string')
        : undefined,
      platforms: decoded.platforms as R2LatestManifest['platforms'],
    },
    notesByVersion,
  )
}
