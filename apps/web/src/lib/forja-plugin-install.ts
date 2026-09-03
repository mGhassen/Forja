import type { ForjaPackRow } from '@/lib/sync-domains'

const INSTALL_INTENT_KEY = 'forja.plugin_install_intent'
const BATCH_INSTALL_INTENT_KEY = 'forja.plugin_batch_install_intent'

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

/** Batch deep link — app brings to front and shows the install picker. */
export function buildForjaBatchInstallDeepLink(
  items: PluginInstallIntent[],
): string {
  const url = new URL('forja://install')
  url.searchParams.set('batch', '1')
  url.searchParams.set(
    'packs',
    JSON.stringify(
      items.map((item) => {
        const row: { m: string; n?: string } = {
          m: item.manifestUrl.trim(),
        }
        const name = item.name?.trim()
        if (name) row.n = name
        return row
      }),
    ),
  )
  return url.toString()
}

function tryOpenForjaDeepLink(href: string): Promise<boolean> {
  if (typeof window === 'undefined') return Promise.resolve(false)
  if (!href.trim()) return Promise.resolve(false)

  return new Promise((resolve) => {
    let settled = false
    const finish = (opened: boolean) => {
      if (settled) return
      settled = true
      cleanup()
      resolve(opened)
    }

    const onHide = () => finish(true)

    const cleanup = () => {
      document.removeEventListener('visibilitychange', onVis)
      window.removeEventListener('pagehide', onHide)
      window.removeEventListener('blur', onHide)
      window.clearTimeout(timer)
    }

    const onVis = () => {
      if (document.hidden) onHide()
    }

    document.addEventListener('visibilitychange', onVis)
    window.addEventListener('pagehide', onHide)
    window.addEventListener('blur', onHide)

    const anchor = document.createElement('a')
    anchor.href = href
    anchor.style.display = 'none'
    document.body.appendChild(anchor)
    anchor.click()
    anchor.remove()

    const timer = window.setTimeout(() => finish(false), 1600)
  })
}

export function tryOpenForjaInstallDeepLink(
  manifestUrl: string,
  opts?: { name?: string },
): Promise<boolean> {
  const trimmed = manifestUrl.trim()
  if (!trimmed) return Promise.resolve(false)
  return tryOpenForjaDeepLink(buildForjaInstallDeepLink(trimmed, opts))
}

export function tryOpenForjaBatchInstallDeepLink(
  items: PluginInstallIntent[],
): Promise<boolean> {
  const cleaned = items
    .map((item) => ({
      manifestUrl: item.manifestUrl.trim(),
      name: item.name?.trim() || undefined,
      version: item.version?.trim() || undefined,
    }))
    .filter((item) => item.manifestUrl.length > 0)
  if (cleaned.length === 0) return Promise.resolve(false)
  if (cleaned.length === 1) {
    return tryOpenForjaInstallDeepLink(cleaned[0]!.manifestUrl, {
      name: cleaned[0]!.name,
    })
  }
  return tryOpenForjaDeepLink(buildForjaBatchInstallDeepLink(cleaned))
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

export type PluginBatchInstallIntent = {
  selections: PluginInstallIntent[]
}

export function rememberPluginBatchInstallIntent(
  intent: PluginBatchInstallIntent,
): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.setItem(BATCH_INSTALL_INTENT_KEY, JSON.stringify(intent))
  } catch {
    // ignore
  }
}

export function readPluginBatchInstallIntent(): PluginBatchInstallIntent | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = sessionStorage.getItem(BATCH_INSTALL_INTENT_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as PluginBatchInstallIntent
    if (!Array.isArray(parsed.selections) || parsed.selections.length === 0) {
      return null
    }
    const selections = parsed.selections
      .map((item) => ({
        manifestUrl: item.manifestUrl?.trim() ?? '',
        name: item.name?.trim() || undefined,
        version: item.version?.trim() || undefined,
      }))
      .filter((item) => item.manifestUrl.length > 0)
    if (selections.length === 0) return null
    return { selections }
  } catch {
    return null
  }
}

export function clearPluginBatchInstallIntent(): void {
  if (typeof window === 'undefined') return
  try {
    sessionStorage.removeItem(BATCH_INSTALL_INTENT_KEY)
  } catch {
    // ignore
  }
}

export function installPayloadFromPack(pack: {
  manifestUrl: string
  name?: string
  version?: string
}): PluginInstallIntent {
  return {
    manifestUrl: pack.manifestUrl.trim(),
    name: pack.name,
    version: pack.version,
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
