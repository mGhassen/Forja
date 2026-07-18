/**
 * Public CDN URLs for Forja release installers (Cloudflare R2).
 *
 * Versioned: {RELEASE_CDN_URL}/v{version}/{filename}
 * Latest:    {RELEASE_CDN_URL}/latest/{filename}
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

/**
 * Rewrite a GitHub asset URL to the release CDN `latest/` object when
 * VITE_RELEASE_CDN_URL is set (site download buttons / landing CTAs).
 */
export function preferReleaseStorageUrl(
  _version: string,
  filename: string,
  githubDownloadUrl: string,
): string {
  const cdn = import.meta.env.VITE_RELEASE_CDN_URL as string | undefined
  if (!cdn?.trim()) return githubDownloadUrl
  return releaseCdnLatestUrl(cdn.trim(), filename)
}
