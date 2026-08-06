import { supabase } from '@/lib/supabase'

export type DeepRefReprocessResult = {
  ok: boolean
  deepRefId: string
  fetchOk: boolean | null
  extractCount: number
  needsRecheck: boolean
  hitCount: number
  promoted: number
  wasExisting: number
  skipped: number
  l2FetchOk: number
  l2FetchFail: number
  error?: string
}

/** Re-fetch paste (or decode base64), extract portals, upsert junction + catalog. */
export async function reprocessDeepRefForAdmin(
  deepRefId: string,
): Promise<DeepRefReprocessResult> {
  const {
    data: { session },
  } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Not signed in')

  const res = await fetch('/api/iptv-deep-ref-reprocess', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${session.access_token}`,
    },
    body: JSON.stringify({ deepRefId }),
  })
  const json = (await res.json().catch(() => ({}))) as DeepRefReprocessResult & {
    error?: string
  }
  if (!res.ok) {
    throw new Error(json.error || `Reprocess failed (${res.status})`)
  }
  return json
}
