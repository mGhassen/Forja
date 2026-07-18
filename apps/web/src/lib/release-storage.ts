/**
 * Public Supabase Storage URLs for Forja release installers.
 * Objects: releases/v{version}/{filename}
 */

const BUCKET = 'releases'

export function releaseStoragePublicUrl(
  supabaseUrl: string,
  version: string,
  filename: string,
): string {
  const base = supabaseUrl.replace(/\/$/, '')
  const ver = version.replace(/^v/, '')
  const path = `v${ver}/${filename}`
  return `${base}/storage/v1/object/public/${BUCKET}/${path}`
}

/** Rewrite a GitHub asset URL to Supabase Storage when VITE_SUPABASE_URL is set. */
export function preferReleaseStorageUrl(
  version: string,
  filename: string,
  githubDownloadUrl: string,
): string {
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined
  if (!supabaseUrl?.trim()) return githubDownloadUrl
  return releaseStoragePublicUrl(supabaseUrl.trim(), version, filename)
}
