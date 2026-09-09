/** Normalize GitHub HTML links → raw.githubusercontent.com pack URLs. */

const BRANCHY_TAIL = new Set(['main', 'master', 'develop', 'dev', 'trunk', 'head'])

export function assertSafePackUrl(url: string): URL {
  let u: URL
  try {
    u = new URL(url)
  } catch {
    throw new Error('Invalid pack URL')
  }
  if (u.protocol !== 'https:' && u.protocol !== 'http:') {
    throw new Error('Pack URL must be http(s)')
  }
  const host = u.hostname.toLowerCase()
  if (
    host === 'localhost' ||
    host === '127.0.0.1' ||
    host === '::1' ||
    host.endsWith('.local') ||
    host.endsWith('.internal')
  ) {
    throw new Error('Local pack URLs are not allowed')
  }
  if (
    /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|169\.254\.)/.test(host) ||
    host === '0.0.0.0' ||
    host === 'metadata.google.internal'
  ) {
    throw new Error('Private network pack URLs are not allowed')
  }
  return u
}

/**
 * Convert github.com blob/tree links to raw.githubusercontent.com.
 * If the path has no file extension, append / replace toward `manifest.json`.
 */
export function normalizePluginPackUrl(
  input: string,
  opts?: { forceManifestFile?: boolean },
): string {
  const trimmed = input.trim()
  if (!trimmed) return trimmed

  let u: URL
  try {
    u = new URL(trimmed)
  } catch {
    return trimmed
  }

  const host = u.hostname.toLowerCase()
  let owner = ''
  let repo = ''
  let ref = ''
  let pathParts: string[] = []

  if (host === 'github.com' || host === 'www.github.com') {
    const parts = u.pathname.split('/').filter(Boolean)
    if (
      parts.length >= 4 &&
      (parts[2] === 'blob' || parts[2] === 'tree')
    ) {
      owner = parts[0]!
      repo = parts[1]!
      ref = parts[3]!
      pathParts = parts.slice(4)
    } else {
      return trimmed
    }
  } else if (host === 'raw.githubusercontent.com') {
    const parts = u.pathname.split('/').filter(Boolean)
    if (parts.length < 3) return trimmed
    owner = parts[0]!
    repo = parts[1]!
    ref = parts[2]!
    pathParts = parts.slice(3)
  } else {
    if (opts?.forceManifestFile) {
      return forceManifestPath(u)
    }
    return trimmed
  }

  pathParts = ensureManifestPath(pathParts, opts?.forceManifestFile === true)
  return `https://raw.githubusercontent.com/${owner}/${repo}/${ref}/${pathParts.join('/')}`
}

function ensureManifestPath(
  parts: string[],
  force: boolean,
): string[] {
  const segs = [...parts]
  if (segs.length === 0) return ['manifest.json']

  const last = segs[segs.length - 1]!
  const isManifest = /^manifest\.json$/i.test(last)
  if (isManifest) return segs

  const hasExt = /\.[a-z0-9]+$/i.test(last)
  if (hasExt && !force) return segs

  if (!hasExt && BRANCHY_TAIL.has(last.toLowerCase()) && segs.length > 1) {
    segs[segs.length - 1] = 'manifest.json'
    return segs
  }

  if (!hasExt) {
    segs.push('manifest.json')
    return segs
  }

  if (force) {
    segs[segs.length - 1] = 'manifest.json'
  }
  return segs
}

function forceManifestPath(u: URL): string {
  const parts = u.pathname.split('/').filter(Boolean)
  if (parts.length === 0) {
    u.pathname = '/manifest.json'
    return u.toString()
  }
  const last = parts[parts.length - 1]!
  if (/^manifest\.json$/i.test(last)) return u.toString()
  if (/\.[a-z0-9]+$/i.test(last) && !BRANCHY_TAIL.has(last.toLowerCase())) {
    parts[parts.length - 1] = 'manifest.json'
  } else if (BRANCHY_TAIL.has(last.toLowerCase()) && parts.length > 1) {
    parts[parts.length - 1] = 'manifest.json'
  } else if (!/\.[a-z0-9]+$/i.test(last)) {
    parts.push('manifest.json')
  } else {
    parts[parts.length - 1] = 'manifest.json'
  }
  u.pathname = `/${parts.join('/')}`
  return u.toString()
}
