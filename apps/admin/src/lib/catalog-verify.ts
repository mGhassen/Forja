import { supabase } from '@/lib/supabase'

export type VerifyResult = {
  id: string
  username: string
  alive: boolean
  status: string
  region: string
  expiry: string | null
  max_connections: string | null
  error: string | null
}

export type VerifyResponse = {
  ok: boolean
  checked: number
  alive: number
  dead: number
  results: VerifyResult[]
  error?: string
}

/** Manual player_api check for one candidate or every portal on a host. */
export async function catalogVerify(body: {
  candidateId?: string
  host?: string
}): Promise<VerifyResponse> {
  const {
    data: { session },
  } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Not signed in')

  const res = await fetch('/api/iptv-catalog-verify', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${session.access_token}`,
    },
    body: JSON.stringify(body),
  })
  const json = (await res.json().catch(() => ({}))) as VerifyResponse
  if (!res.ok) throw new Error(json.error || `Verify failed (${res.status})`)
  return json
}
