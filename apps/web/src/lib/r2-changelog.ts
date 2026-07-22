/**
 * Server-side fetch of the permanent R2 changelog archive.
 * Browser uses /api/changelog (same-origin) — CDN has no CORS for the portal.
 */

import { detectPlatformFromFilename } from '@/lib/r2-latest-release'

export const CHANGELOG_FETCH_LIMIT = 20

/** Ordered showcase platform ids for release tags. */
export const CHANGELOG_PLATFORM_ORDER = [
  'windows',
  'macos',
  'linux',
  'android_tv',
] as const

export type ChangelogPlatformId = (typeof CHANGELOG_PLATFORM_ORDER)[number]

export type R2ChangelogArchive = {
  versions: string[]
  notes: Record<string, string>
  /** Platforms that shipped installers in each version (from `v{ver}/manifest.json`). */
  platformsByVersion: Record<string, ChangelogPlatformId[]>
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

function orderPlatforms(ids: Iterable<string>): ChangelogPlatformId[] {
  const set = new Set(ids)
  return CHANGELOG_PLATFORM_ORDER.filter((id) => set.has(id))
}

async function platformsFromVersionManifest(
  base: string,
  version: string,
): Promise<ChangelogPlatformId[]> {
  const ver = version.replace(/^v/, '')
  const res = await fetch(`${base}/v${ver}/manifest.json`, {
    headers: {
      Accept: 'application/json',
      'User-Agent': 'forja-web',
    },
  })
  if (!res.ok) return []

  const decoded = (await res.json()) as {
    assets?: unknown
    platforms?: Record<string, unknown>
  }

  if (decoded.platforms && typeof decoded.platforms === 'object') {
    return orderPlatforms(Object.keys(decoded.platforms))
  }

  const assets = Array.isArray(decoded.assets) ? decoded.assets : []
  const found = new Set<string>()
  for (const name of assets) {
    if (typeof name !== 'string' || !name.trim()) continue
    const platform = detectPlatformFromFilename(name)
    if (platform === 'other' || platform === 'ios') continue
    found.add(platform)
  }
  return orderPlatforms(found)
}

export async function fetchR2ChangelogArchive(
  limit = CHANGELOG_FETCH_LIMIT,
): Promise<R2ChangelogArchive> {
  const base = cdnBase()
  if (!base) {
    throw new Error('RELEASE_CDN_URL is not configured')
  }

  const indexRes = await fetch(`${base}/changelog/index.json`, {
    headers: {
      Accept: 'application/json',
      'User-Agent': 'forja-web',
    },
  })
  if (!indexRes.ok) {
    throw new Error(`changelog index HTTP ${indexRes.status}`)
  }

  const decoded = (await indexRes.json()) as { versions?: unknown }
  const versionsRaw = Array.isArray(decoded.versions) ? decoded.versions : []
  const versions = versionsRaw
    .filter((v): v is string => typeof v === 'string' && v.trim().length > 0)
    .map((v) => v.trim())
    .slice(0, limit)

  const notes: Record<string, string> = {}
  const platformsByVersion: Record<string, ChangelogPlatformId[]> = {}

  await Promise.all(
    versions.map(async (version) => {
      const [notesRes, platforms] = await Promise.all([
        fetch(`${base}/changelog/${version}.md`, {
          headers: {
            Accept: 'text/markdown, text/plain, */*',
            'User-Agent': 'forja-web',
          },
        }),
        platformsFromVersionManifest(base, version),
      ])
      if (notesRes.ok) {
        const body = (await notesRes.text()).trim()
        if (body) notes[version] = body
      }
      if (platforms.length) platformsByVersion[version] = platforms
    }),
  )

  return {
    versions: versions.filter((v) => notes[v]),
    notes,
    platformsByVersion,
  }
}
