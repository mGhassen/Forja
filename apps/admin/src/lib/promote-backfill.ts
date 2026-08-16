import { supabase } from '@/lib/supabase'

export type PromoteBackfillRun = {
  id: string
  started_at: string
  status: string
  source?: string | null
}

export type PromoteBackfillResult = {
  ok: boolean
  jobId?: string
  runId?: string
  run?: PromoteBackfillRun
  limit?: number
  chunkSize?: number
  pending?: number
  cancelledInngest?: boolean
}

async function authHeaders(): Promise<HeadersInit> {
  const {
    data: { session },
  } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Not signed in')
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${session.access_token}`,
  }
}

export async function countPromoteBackfillPending(): Promise<number> {
  const res = await fetch('/api/iptv-promote-backfill', {
    method: 'POST',
    headers: await authHeaders(),
    body: JSON.stringify({ action: 'count' }),
  })
  const json = (await res.json().catch(() => ({}))) as {
    error?: string
    pending?: number
  }
  if (!res.ok) throw new Error(json.error || 'Count pending failed')
  return Number(json.pending ?? 0)
}

export async function startPromoteBackfill(opts: {
  limit: number
  chunkSize?: number
}): Promise<PromoteBackfillResult> {
  const res = await fetch('/api/iptv-promote-backfill', {
    method: 'POST',
    headers: await authHeaders(),
    body: JSON.stringify({
      action: 'start',
      limit: opts.limit,
      chunkSize: opts.chunkSize,
    }),
  })
  const json = (await res.json().catch(() => ({}))) as PromoteBackfillResult & {
    error?: string
  }
  if (!res.ok) throw new Error(json.error || 'Start promote backfill failed')
  return {
    ok: true,
    jobId: json.jobId,
    runId: json.runId,
    run: json.run,
    limit: json.limit,
    chunkSize: json.chunkSize,
  }
}

export async function cancelPromoteBackfill(opts?: {
  runId?: string
}): Promise<PromoteBackfillResult> {
  const res = await fetch('/api/iptv-promote-backfill', {
    method: 'POST',
    headers: await authHeaders(),
    body: JSON.stringify({
      action: 'cancel',
      runId: opts?.runId,
    }),
  })
  const json = (await res.json().catch(() => ({}))) as PromoteBackfillResult & {
    error?: string
  }
  if (!res.ok) throw new Error(json.error || 'Cancel promote backfill failed')
  return {
    ok: true,
    cancelledInngest: json.cancelledInngest,
  }
}
