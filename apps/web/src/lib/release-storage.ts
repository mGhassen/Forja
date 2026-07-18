/**
 * Public CDN URLs for Forja release installers (Cloudflare R2).
 * Objects: {RELEASE_CDN_URL}/v{version}/{filename}
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

/** Rewrite a GitHub asset URL to the release CDN when VITE_RELEASE_CDN_URL is set. */
export function preferReleaseStorageUrl(
  version: string,
  filename: string,
  githubDownloadUrl: string,
): string {
  const cdn = import.meta.env.VITE_RELEASE_CDN_URL as string | undefined
  if (!cdn?.trim()) return githubDownloadUrl
  return releaseCdnPublicUrl(cdn.trim(), version, filename)
}
