export type CatalogPortal = {
  url: string
  username: string
  password: string
  source: string
  /** Reddit thing id (t3_…) — stored alone; never title/body. */
  postId?: string
  /** From note card / get.php — filled on scrape upsert (alive stays null). */
  expiry?: string | null
  maxConnections?: string | null
  timezone?: string | null
  regionPrimary?: string
  regionTags?: string[]
  regionConfidence?: number
  /** Allowed outputs line (e.g. m3u8,ts,rtmp) — also seeds deep_ref.output. */
  allowedOutputs?: string | null
}

/**
 * Portal hit under a deep ref.
 * - platform: xtream | m3u | stalker
 * - type / output: get.php query params (e.g. type=m3u_plus&output=m3u8)
 */
export type DeepRefPortalHit = {
  platform: 'xtream' | 'm3u' | 'stalker'
  type: string
  output: string
  url: string
  username: string
  password: string
  expiry?: string | null
  maxConnections?: string | null
  timezone?: string | null
  regionPrimary?: string
  regionTags?: string[]
  regionConfidence?: number
  allowedOutputs?: string | null
}

/**
 * One Reddit find: base64 (if any) + paste.sh URL (if any).
 * Never two rows for the same find.
 */
export type DeepRefRecord = {
  postId: string
  /** Raw base64 from the post (empty if paste URL was plain text in post). */
  base64: string
  /** Decoded / found paste URL (empty if base64 was inline credential text). */
  pasteUrl: string
  /** Fetched paste body (capped) for re-extract. */
  pasteBody: string | null
  payloadHash: string
  refHost: string
  fetchOk: boolean | null
  extractCount: number
  needsRecheck: boolean
  portals: DeepRefPortalHit[]
}

/** DB row waiting for process phase (paste fetch and/or portal extract). */
export type PendingDeepRefRow = {
  id: string
  post_id: string
  base64: string
  paste_url: string
  paste_body: string | null
  payload_hash: string
  ref_host: string
  fetch_ok: boolean | null
  extract_count: number
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
