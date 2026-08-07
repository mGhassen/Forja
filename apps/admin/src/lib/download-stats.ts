import { supabase } from '@/lib/supabase'

export const DOWNLOAD_STATS_KEY = ['admin', 'download_stats'] as const

export const DOWNLOAD_PLATFORMS = [
  { id: 'windows', label: 'Windows' },
  { id: 'macos', label: 'macOS' },
  { id: 'linux', label: 'Linux' },
  { id: 'android_tv', label: 'Android TV' },
] as const

export type DownloadStats = {
  total: number
  byPlatform: Record<string, number>
  byObject: Array<{ object: string; platform: string; count: number }>
  byVersion: Array<{
    version: string
    count: number
    byPlatform: Record<string, number>
  }>
  dayCount: number
  updatedAt: string | null
  bucket: string
  source: 'r2_rollup'
}

export async function fetchDownloadStats(): Promise<DownloadStats> {
  const {
    data: { session },
  } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Not signed in')

  const res = await fetch('/api/r2-download-stats', {
    headers: { Authorization: `Bearer ${session.access_token}` },
  })
  const json = (await res.json().catch(() => ({}))) as DownloadStats & {
    error?: string
  }
  if (!res.ok) throw new Error(json.error || 'Failed to load download stats')
  return json
}

export async function triggerDownloadRollup(
  action: 'rollup' | 'backfill' = 'rollup',
  days = 30,
): Promise<DownloadStats & { ok: true; action: string; daysWritten?: string[] }> {
  const {
    data: { session },
  } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Not signed in')

  const res = await fetch('/api/r2-download-stats', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${session.access_token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ action, days }),
  })
  const json = (await res.json().catch(() => ({}))) as DownloadStats & {
    error?: string
    ok?: boolean
    action?: string
    daysWritten?: string[]
  }
  if (!res.ok) throw new Error(json.error || 'Failed to run rollup')
  return json as DownloadStats & {
    ok: true
    action: string
    daysWritten?: string[]
  }
}
