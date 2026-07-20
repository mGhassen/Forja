/**
 * Server-side fetch of R2 `latest/manifest.json`.
 * Browser uses /api/latest-release — CDN has no CORS for the portal.
 */

import {
  releaseCdnLatestUrl,
} from '@/lib/release-storage'

export type R2LatestManifest = {
  version: string
  published_at?: string
  assets: string[]
}

export type R2LatestReleaseAsset = {
  id: string
  release_id: string
  platform: string
  name: string
  download_url: string
  size_bytes: number | null
}

export type R2LatestRelease = {
  id: string
  tag: string
  version: string
  body: string | null
  published_at: string
  html_url: string | null
  source: 'r2'
  synced_at: string
  assets: R2LatestReleaseAsset[]
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

export function fromR2Manifest(
  base: string,
  manifest: R2LatestManifest,
  body: string | null = null,
): R2LatestRelease {
  const version = manifest.version.replace(/^v/, '')
  const releaseId = `r2-${version}`
  const filenames = (manifest.assets ?? []).filter(
    (n): n is string => typeof n === 'string' && n.trim().length > 0,
  )

  return {
    id: releaseId,
    tag: `v${version}`,
    version,
    body,
    published_at: manifest.published_at?.trim() || new Date().toISOString(),
    html_url: null,
    source: 'r2',
    synced_at: new Date().toISOString(),
    assets: filenames.map((name, i) => ({
      id: `r2-asset-${version}-${i}`,
      release_id: releaseId,
      platform: detectPlatformFromFilename(name),
      name,
      download_url: releaseCdnLatestUrl(base, name),
      size_bytes: null,
    })),
  }
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
  const version = typeof decoded.version === 'string' ? decoded.version.trim() : ''
  if (!version) {
    throw new Error('release manifest missing version')
  }
  const assets = Array.isArray(decoded.assets) ? decoded.assets : []
  if (!assets.length) return null

  const body = await fetchChangelogBody(base, version)
  return fromR2Manifest(
    base,
    {
      version,
      published_at:
        typeof decoded.published_at === 'string' ? decoded.published_at : undefined,
      assets: assets.filter((a): a is string => typeof a === 'string'),
    },
    body,
  )
}
