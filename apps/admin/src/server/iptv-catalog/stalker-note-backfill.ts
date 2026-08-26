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

export type StalkerNoteBackfillResult = {
  deepRefs: number
  junctionsPatched: number
  portalsPatched: number
  fetchFailed: number
  done: boolean
}

/**
 * Re-fetch paste for deep refs that have Stalker hits missing expiry/note.
 * Patches junction + linked iptv_portals only — does not replace portal rows.
 */
export async function backfillStalkerNotesChunk(
  sb: SupabaseClient,
  opts?: { limit?: number },
): Promise<StalkerNoteBackfillResult> {
  const limit = Math.min(80, Math.max(1, Math.floor(opts?.limit ?? 25)))

  const { data: needRows, error: needErr } = await sb
    .from('iptv_scrape_deep_ref_portals')
    .select(
      'deep_ref_id, expiry, note, iptv_scrape_deep_refs!inner(paste_url, base64)',
    )
    .eq('platform', 'stalker')
    .or('expiry.is.null,note.is.null')
    .limit(limit * 60)
  if (needErr) throw needErr

  const deepRefIds: string[] = []
  const seen = new Set<string>()
  for (const row of needRows ?? []) {
    const id = String(row.deep_ref_id ?? '').trim()
    if (!id || seen.has(id)) continue
    const hasExpiry = Boolean(scrapeExpiresNote(row.expiry as string | null))
    const hasNote = Boolean(scrapeExpiresNote(row.note as string | null))
    if (hasExpiry && hasNote) continue
    const parent = row.iptv_scrape_deep_refs as unknown as {
      paste_url?: string | null
      base64?: string | null
    } | null
    const pasteUrl = String(parent?.paste_url ?? '').trim()
    const b64 = String(parent?.base64 ?? '').trim()
    if (!pasteUrl && !b64) continue
    seen.add(id)
    deepRefIds.push(id)
    if (deepRefIds.length >= limit) break
  }

  let junctionsPatched = 0
  let portalsPatched = 0
  let fetchFailed = 0

  for (const deepRefId of deepRefIds) {
    const row = await getDeepRefRowById(sb, deepRefId)
    if (!row) continue

    const processed = await processDeepRefRow(row, 500, { force: true })
    if (processed.ref.fetchOk === false) {
      fetchFailed++
      continue
    }

    const byKey = new Map<string, { expiry: string | null; note: string | null }>()
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
    junctionsPatched,
    portalsPatched,
    fetchFailed,
    done: deepRefIds.length < limit,
  }
}
