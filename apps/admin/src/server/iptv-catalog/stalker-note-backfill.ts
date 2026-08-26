import type { SupabaseClient } from '@supabase/supabase-js'
import { scrapeExpiresNote } from '@/server/iptv-catalog/extract'
import { processDeepRefRow } from '@/server/iptv-catalog/reddit'
import { getDeepRefRowById } from '@/server/iptv-catalog/supabase-admin'
import type { DeepRefPortalHit } from '@/server/iptv-catalog/types'

function normKey(url: string, username: string): string {
  return `${url.trim().toLowerCase()}|${username.trim().toLowerCase()}`
}

function hitExpires(hit: DeepRefPortalHit): {
  expiry: string | null
  note: string | null
} {
  const expiry = scrapeExpiresNote(hit.expiry) ?? scrapeExpiresNote(hit.note)
  const note = scrapeExpiresNote(hit.note) ?? expiry
  return { expiry, note }
}

function needsNoteOrExpiry(expiry: unknown, note: unknown): boolean {
  return !(
    scrapeExpiresNote(expiry as string | null) &&
    scrapeExpiresNote(note as string | null)
  )
}

/**
 * SQL prefilter for missing scrape expires.
 * Must include '' / Unknown — `is.null` alone under-counted (~7 vs tens of thousands).
 */
const MISSING_EXPIRES_OR =
  'expiry.is.null,expiry.eq.,expiry.ilike.unknown,note.is.null,note.eq.,note.ilike.unknown'

type DeepRefParent = {
  paste_url?: string | null
  base64?: string | null
} | null

function parentHasPasteOrBase64(parent: DeepRefParent): boolean {
  return (
    Boolean(String(parent?.paste_url ?? '').trim()) ||
    Boolean(String(parent?.base64 ?? '').trim())
  )
}

/** Eligible deep_ref id, or null if this junction row does not qualify. */
function eligibleDeepRefId(row: {
  deep_ref_id?: unknown
  expiry?: unknown
  note?: unknown
  iptv_scrape_deep_refs?: unknown
}): string | null {
  if (!needsNoteOrExpiry(row.expiry, row.note)) return null
  const id = String(row.deep_ref_id ?? '').trim()
  if (!id) return null
  if (!parentHasPasteOrBase64(row.iptv_scrape_deep_refs as DeepRefParent)) {
    return null
  }
  return id
}

export type StalkerNoteChunkResult = {
  deepRefs: number
  fetchOk: number
  fetchFailed: number
  junctionsPatched: number
  portalsPatched: number
  /** Ids claimed this chunk (incl. fetch fails) — exclude on next claim. */
  claimedIds: string[]
  done: boolean
}

/**
 * Distinct deep refs with Stalker hits missing expiry/note + paste/base64.
 * Paged — PostgREST max_rows would otherwise cap the count (~1000 junctions → tiny distinct set).
 */
export async function countStalkerNoteBackfillPending(
  sb: SupabaseClient,
): Promise<number> {
  const pageSize = 500
  let offset = 0
  const seen = new Set<string>()
  for (;;) {
    const to = offset + pageSize - 1
    const { data, error } = await sb
      .from('iptv_scrape_deep_ref_portals')
      .select(
        'deep_ref_id, expiry, note, iptv_scrape_deep_refs!inner(paste_url, base64)',
      )
      .eq('platform', 'stalker')
      .or(MISSING_EXPIRES_OR)
      .order('created_at', { ascending: true })
      .order('id', { ascending: true })
      .range(offset, to)
    if (error) throw error
    if (!data?.length) break
    for (const row of data) {
      const id = eligibleDeepRefId(row)
      if (id) seen.add(id)
    }
    if (data.length < pageSize) break
    offset += pageSize
  }
  return seen.size
}

/**
 * Next deep_ref ids that still need note/expiry backfill.
 * [excludeIds] = already tried this run (incl. paste failures).
 * Pages until [take] distinct ids or the stalker set is exhausted.
 */
export async function claimStalkerNoteDeepRefIds(
  sb: SupabaseClient,
  take: number,
  excludeIds: string[] = [],
): Promise<string[]> {
  const want = Math.max(0, Math.floor(take))
  if (want === 0) return []
  const exclude = new Set(excludeIds.map((id) => id.trim()).filter(Boolean))

  const pageSize = Math.max(want * 4, 200)
  let offset = 0
  const out: string[] = []
  const seen = new Set<string>()

  while (out.length < want) {
    const to = offset + pageSize - 1
    const { data, error } = await sb
      .from('iptv_scrape_deep_ref_portals')
      .select(
        'deep_ref_id, expiry, note, created_at, iptv_scrape_deep_refs!inner(paste_url, base64)',
      )
      .eq('platform', 'stalker')
      .or(MISSING_EXPIRES_OR)
      .order('created_at', { ascending: true })
      .order('id', { ascending: true })
      .range(offset, to)
    if (error) throw error
    if (!data?.length) break

    for (const row of data) {
      const id = eligibleDeepRefId(row)
      if (!id || seen.has(id) || exclude.has(id)) continue
      seen.add(id)
      out.push(id)
      if (out.length >= want) return out
    }
    if (data.length < pageSize) break
    offset += pageSize
  }
  return out
}

/** Re-fetch paste + patch Stalker expiry/note on junction + linked pool rows. */
export async function processStalkerNoteDeepRefChunk(
  sb: SupabaseClient,
  deepRefIds: string[],
): Promise<StalkerNoteChunkResult> {
  let fetchOk = 0
  let fetchFailed = 0
  let junctionsPatched = 0
  let portalsPatched = 0

  for (const deepRefId of deepRefIds) {
    const row = await getDeepRefRowById(sb, deepRefId)
    if (!row) continue

    const processed = await processDeepRefRow(row, 500, { force: true })
    if (processed.ref.fetchOk === false) {
      fetchFailed++
      continue
    }
    fetchOk++

    const byKey = new Map<
      string,
      { expiry: string | null; note: string | null }
    >()
    for (const hit of processed.ref.portals ?? []) {
      if (hit.platform !== 'stalker') continue
      const { expiry, note } = hitExpires(hit)
      if (!expiry && !note) continue
      byKey.set(normKey(hit.url, hit.username), { expiry, note })
    }
    if (byKey.size === 0) continue

    const { data: junctions, error: jErr } = await sb
      .from('iptv_scrape_deep_ref_portals')
      .select('id, url, username, portal_id, expiry, note')
      .eq('deep_ref_id', deepRefId)
      .eq('platform', 'stalker')
    if (jErr) throw jErr

    for (const j of junctions ?? []) {
      const key = normKey(String(j.url ?? ''), String(j.username ?? ''))
      const found = byKey.get(key)
      if (!found) continue

      const nextExpiry =
        scrapeExpiresNote(j.expiry as string | null) ?? found.expiry
      const nextNote =
        scrapeExpiresNote(j.note as string | null) ?? found.note ?? nextExpiry
      if (!nextExpiry && !nextNote) continue

      const sameExpiry =
        (scrapeExpiresNote(j.expiry as string | null) ?? null) === nextExpiry
      const sameNote =
        (scrapeExpiresNote(j.note as string | null) ?? null) === nextNote
      if (sameExpiry && sameNote) continue

      const patch: Record<string, string | null> = {}
      if (!sameExpiry && nextExpiry) patch.expiry = nextExpiry
      if (!sameNote && nextNote) patch.note = nextNote
      if (Object.keys(patch).length === 0) continue

      const { error: upJ } = await sb
        .from('iptv_scrape_deep_ref_portals')
        .update(patch)
        .eq('id', j.id)
      if (upJ) throw upJ
      junctionsPatched++

      const portalId = String(j.portal_id ?? '').trim()
      if (!portalId) continue

      const { data: portal, error: pErr } = await sb
        .from('iptv_portals')
        .select('id, expiry, note')
        .eq('id', portalId)
        .maybeSingle()
      if (pErr) throw pErr
      if (!portal) continue

      const portalPatch: Record<string, string | null> = {}
      if (!scrapeExpiresNote(portal.expiry as string | null) && nextExpiry) {
        portalPatch.expiry = nextExpiry
      }
      if (!scrapeExpiresNote(portal.note as string | null) && nextNote) {
        portalPatch.note = nextNote
      }
      if (Object.keys(portalPatch).length === 0) continue

      const { error: upP } = await sb
        .from('iptv_portals')
        .update({
          ...portalPatch,
          updated_at: new Date().toISOString(),
        })
        .eq('id', portalId)
      if (upP) throw upP
      portalsPatched++
    }
  }

  return {
    deepRefs: deepRefIds.length,
    fetchOk,
    fetchFailed,
    junctionsPatched,
    portalsPatched,
    claimedIds: deepRefIds,
    done: deepRefIds.length === 0,
  }
}

/** @deprecated Prefer Inngest note-backfill job — sync one chunk only. */
export async function backfillStalkerNotesChunk(
  sb: SupabaseClient,
  opts?: { limit?: number },
): Promise<StalkerNoteChunkResult> {
  const limit = Math.min(80, Math.max(1, Math.floor(opts?.limit ?? 25)))
  const ids = await claimStalkerNoteDeepRefIds(sb, limit)
  if (ids.length === 0) {
    return {
      deepRefs: 0,
      fetchOk: 0,
      fetchFailed: 0,
      junctionsPatched: 0,
      portalsPatched: 0,
      claimedIds: [],
      done: true,
    }
  }
  const result = await processStalkerNoteDeepRefChunk(sb, ids)
  return { ...result, done: ids.length < limit }
}
