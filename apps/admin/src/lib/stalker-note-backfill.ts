import { supabase } from '@/lib/supabase'

export type StalkerNoteBackfillResponse = {
  ok: boolean
  deepRefs: number
  junctionsPatched: number
  portalsPatched: number
  fetchFailed: number
  done: boolean
  error?: string
}

/** Re-fetch paste → fill Stalker expiry + note on junction / pool rows. */
export async function stalkerNoteBackfill(body?: {
  limit?: number
}): Promise<StalkerNoteBackfillResponse> {
  const {
    data: { session },
  } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Not signed in')

  const res = await fetch('/api/iptv-stalker-note-backfill', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${session.access_token}`,
    },
    body: JSON.stringify(body ?? {}),
  })
  const json = (await res.json()) as StalkerNoteBackfillResponse
  if (!res.ok) {
    throw new Error(json.error || `Backfill failed (${res.status})`)
  }
  return json
}
