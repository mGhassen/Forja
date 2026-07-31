export type CatalogPortal = {
  url: string
  username: string
  password: string
  source: string
  /** Reddit thing id (t3_…) — stored alone; never title/body. */
  postId?: string
}

/** Persisted L2 / base64 / paste ref (retry queue when needsRecheck). */
export type DeepRefPortalHit = {
  url: string
  username: string
  password: string
}

export type DeepRefRecord = {
  postId: string
  refType: 'b64_url' | 'b64_text' | 'paste_url'
  refHost: string
  payloadHash: string
  rawRef: string
  payloadText: string | null
  fetchOk: boolean | null
  extractCount: number
  needsRecheck: boolean
  /** Portals extracted from this ref's payload (empty for b64→paste pointer). */
  portals: DeepRefPortalHit[]
}

export type PortalStatus = {
  /** null = not probed (verify step disabled / skipped). */
  alive: boolean | null
  status: string
  expiry: string | null
  maxConnections: string | null
  timezone: string | null
  categoryNames: string[]
  error?: string
}

export type RegionGuess = {
  primary: string
  tags: string[]
  confidence: number
}

export function portalKey(p: CatalogPortal): string {
  return `${p.url}|${p.username}|${p.password}`.toLowerCase()
}
