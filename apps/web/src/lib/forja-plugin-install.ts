import type { ForjaPackRow } from '@/lib/sync-domains'

const INSTALL_INTENT_KEY = 'forja.plugin_install_intent'

export type PluginInstallIntent = {
  manifestUrl: string
  name?: string
  version?: string
}

export function buildForjaInstallDeepLink(
  manifestUrl: string,
  opts?: { name?: string },
): string {
  const url = new URL('forja://install')
  url.searchParams.set('manifest', manifestUrl.trim())
  const name = opts?.name?.trim()
  if (name) url.searchParams.set('name', name)
  return url.toString()
}

export function tryOpenForjaInstallDeepLink(
  manifestUrl: string,
  opts?: { name?: string },
): void {
  if (typeof window === 'undefined') return
  const trimmed = manifestUrl.trim()
  if (!trimmed) return
  const anchor = document.createElement('a')
  anchor.href = buildForjaInstallDeepLink(trimmed, opts)
  anchor.style.display = 'none'
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()
}

export function rememberPluginInstallIntent(intent: PluginInstallIntent): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(INSTALL_INTENT_KEY, JSON.stringify(intent))
  } catch {
    // ignore
  }
}

export function readPluginInstallIntent(): PluginInstallIntent | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = sessionStorage.getItem(INSTALL_INTENT_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as PluginInstallIntent
    if (!parsed.manifestUrl?.trim()) return null
    return {
      manifestUrl: parsed.manifestUrl.trim(),
      name: parsed.name?.trim() || undefined,
      version: parsed.version?.trim() || undefined,
    }
  } catch {
    return null
  }
}

export function clearPluginInstallIntent(): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.removeItem(INSTALL_INTENT_KEY)
  } catch {
    // ignore
  }
}

export function packRowFromIntent(intent: PluginInstallIntent): ForjaPackRow {
  const manifestUrl = intent.manifestUrl.trim()
  const row: ForjaPackRow = { manifestUrl }
  const name = intent.name?.trim()
  if (name && name !== manifestUrl) row.name = name
  const version = intent.version?.trim()
  if (version) row.version = version
  return row
}

export function isPackInstalled(
  packs: ForjaPackRow[],
  manifestUrl: string,
): boolean {
  const want = manifestUrl.trim()
  return packs.some((pack) => pack.manifestUrl.trim() === want)
}

export function isSafeManifestUrl(raw: string | null | undefined): boolean {
  if (!raw?.trim()) return false
  try {
    const url = new URL(raw.trim())
    if (url.protocol !== 'https:' && url.protocol !== 'http:') return false
    return url.pathname.endsWith('.json')
  } catch {
    return false
  }
}
