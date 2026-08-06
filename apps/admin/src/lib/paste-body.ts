import { supabase } from '@/lib/supabase'

/** Fetch + decrypt paste body on demand (never read from DB). */
export async function fetchPasteBodyForAdmin(url: string): Promise<string> {
  const {
    data: { session },
  } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Not signed in')

  const res = await fetch('/api/iptv-paste-body', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${session.access_token}`,
    },
    body: JSON.stringify({ url }),
  })
  const json = (await res.json().catch(() => ({}))) as {
    error?: string
    body?: string | null
  }
  if (!res.ok) throw new Error(json.error || `Paste fetch failed (${res.status})`)
  if (!json.body) throw new Error(json.error || 'Empty paste body')
  return json.body
}
