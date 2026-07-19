/**
 * Server-side fetch of the permanent R2 changelog archive.
 * Browser uses /api/changelog (same-origin) — CDN has no CORS for the portal.
 */

export const CHANGELOG_FETCH_LIMIT = 20

export type R2ChangelogArchive = {
  versions: string[]
  notes: Record<string, string>
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
  await Promise.all(
    versions.map(async (version) => {
      const res = await fetch(`${base}/changelog/${version}.md`, {
        headers: {
          Accept: 'text/markdown, text/plain, */*',
          'User-Agent': 'forja-web',
        },
      })
      if (!res.ok) return
      const body = (await res.text()).trim()
      if (body) notes[version] = body
    }),
  )

  return {
    versions: versions.filter((v) => notes[v]),
    notes,
  }
}
