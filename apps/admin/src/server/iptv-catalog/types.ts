export type CatalogPortal = {
  url: string
  username: string
  password: string
  source: string
  /** Product protocol — written to iptv_portals.platform on promote. */
  platform?: 'xtream' | 'm3u' | 'stalker'
  /** Reddit thing id (t3_…) — scrape lineage only; never written to iptv_portals. */
  postId?: string
  /** From note card / get.php — filled on scrape upsert (alive stays null). */
  expiry?: string | null
  /**
   * Scrape note expires (Stalker paste). Copied to iptv_portals.note;
   * Check status does not overwrite.
   */
  note?: string | null
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
 * - platform: xtream | m3u | stalker (product protocol — not get.php type=)
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
  /** Scrape note expires — same as CatalogPortal.note. */
  note?: string | null
  maxConnections?: string | null
  timezone?: string | null
  regionPrimary?: string
  regionTags?: string[]
  regionConfidence?: number
  allowedOutputs?: string | null
}

/** Matches iptv_scrape_deep_ref_portals unique (deep_ref_id, url, username). */
export function deepRefPortalHitKey(h: DeepRefPortalHit): string {
  return `${h.url}|${h.username}`.toLowerCase()
}

/** Collapse type/output/platform variants; keep richest row for DB unique. */
export function dedupeDeepRefPortalHits(
  hits: DeepRefPortalHit[],
): DeepRefPortalHit[] {
  const acc = new Map<string, DeepRefPortalHit>()
  for (const hit of hits) {
    const key = deepRefPortalHitKey(hit)
    const prev = acc.get(key)
    if (!prev) {
      acc.set(key, hit)
      continue
    }
    acc.set(key, {
      ...prev,
      platform: prev.platform || hit.platform,
      type: prev.type || hit.type,
      output: prev.output || hit.output,
      password:
        (hit.password?.length ?? 0) > (prev.password?.length ?? 0)
          ? hit.password
          : prev.password,
      expiry: prev.expiry ?? hit.expiry ?? null,
      note: prev.note ?? hit.note ?? null,
      maxConnections: prev.maxConnections ?? hit.maxConnections ?? null,
      timezone: prev.timezone ?? hit.timezone ?? null,
      regionPrimary: prev.regionPrimary ?? hit.regionPrimary,
      regionTags: prev.regionTags?.length ? prev.regionTags : hit.regionTags,
      regionConfidence:
        (prev.regionConfidence ?? 0) > 0
          ? prev.regionConfidence
          : hit.regionConfidence,
      allowedOutputs: prev.allowedOutputs ?? hit.allowedOutputs ?? null,
    })
  }
  return [...acc.values()]
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
