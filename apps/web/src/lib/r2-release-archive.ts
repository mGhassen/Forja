/**
 * Server-side fetch of the last N versioned installer trees on R2.
 * Browser uses /api/release-archive — CDN has no CORS for the portal.
 *
 * Retention matches release CI (`RELEASE_STORAGE_KEEP`, default 3): only the
 * newest version prefixes still have installers. Changelog index lists many
 * more versions (notes stay forever); we probe until we collect `keep` trees.
 */

import {
  assetsFromManifest,
  type R2LatestManifest,
  type R2LatestReleaseAsset,
} from '@/lib/r2-latest-release'

/** Matches `RELEASE_STORAGE_KEEP` default in upload_release_to_r2.py. */
export const RELEASE_ARCHIVE_KEEP = 3

/** How many changelog index entries to probe for live installer trees. */
const ARCHIVE_PROBE_LIMIT = 12

export type R2ReleaseArchive = {
  /** Semver prefixes still hosting installers (newest first), up to KEEP. */
  versions: string[]
  /** All installers under those prefixes (CDN `v{ver}/…` URLs). */
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

async function fetchVersionManifest(
  base: string,
  version: string,
): Promise<R2LatestManifest | null> {
  const ver = version.replace(/^v/, '')
  const res = await fetch(`${base}/v${ver}/manifest.json`, {
    headers: {
      Accept: 'application/json',
      'User-Agent': 'forja-web',
    },
  })
  if (res.status === 404) return null
  if (!res.ok) return null
  return (await res.json()) as R2LatestManifest
}

export async function fetchR2ReleaseArchive(
  keep = RELEASE_ARCHIVE_KEEP,
): Promise<R2ReleaseArchive> {
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
  const candidates = (
    Array.isArray(decoded.versions) ? decoded.versions : []
  )
    .filter((v): v is string => typeof v === 'string' && v.trim().length > 0)
    .map((v) => v.trim().replace(/^v/, ''))
    .slice(0, ARCHIVE_PROBE_LIMIT)

  const versions: string[] = []
  const assets: R2LatestReleaseAsset[] = []

  for (const version of candidates) {
    if (versions.length >= keep) break
    const manifest = await fetchVersionManifest(base, version)
    if (!manifest) continue
    const parsed = assetsFromManifest(base, manifest, 'versioned')
    if (!parsed?.assets.length) continue
    versions.push(version)
    assets.push(...parsed.assets)
  }

  return { versions, assets }
}
