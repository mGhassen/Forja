/**
 * Public CDN URLs for Forja release installers + changelog (Cloudflare R2).
 *
 * Versioned:  {RELEASE_CDN_URL}/v{version}/{filename}
 * Latest:     {RELEASE_CDN_URL}/latest/{filename}
 * Changelog:  {RELEASE_CDN_URL}/changelog/index.json + changelog/{version}.md
 *
 * The portal loads notes via `/api/changelog` and the latest installer list via
 * `/api/latest-release` (server fetches R2) because the CDN custom domain does
 * not send CORS for browser origins.
 */

export function releaseCdnPublicUrl(
  cdnBase: string,
  version: string,
  filename: string,
): string {
  const base = cdnBase.replace(/\/$/, '')
  const ver = version.replace(/^v/, '')
  return `${base}/v${ver}/${filename}`
}

export function releaseCdnLatestUrl(cdnBase: string, filename: string): string {
  const base = cdnBase.replace(/\/$/, '')
  return `${base}/latest/${filename}`
}
