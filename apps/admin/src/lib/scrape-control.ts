import { supabase } from '@/lib/supabase'

export type ScrapeAction = 'start' | 'stop' | 'mark_stuck'

export async function scrapeControl(
  action: ScrapeAction,
  body?: { runId?: string; maxPages?: number; maxVerify?: number },
): Promise<{ ok: boolean; jobId?: string; count?: number }> {
  const {
    data: { session },
  } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Not signed in')

  const res = await fetch('/api/iptv-catalog-scrape', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${session.access_token}`,
    },
    body: JSON.stringify({ action, ...body }),
  })
  const json = (await res.json().catch(() => ({}))) as {
    error?: string
    ok?: boolean
    jobId?: string
    count?: number
  }
  if (!res.ok) throw new Error(json.error || `Scrape ${action} failed`)
  return {
    ok: true,
    jobId: json.jobId,
    count: json.count,
  }
}
