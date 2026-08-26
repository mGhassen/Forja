import { supabase } from '@/lib/supabase'

export type StalkerNoteBackfillRun = {
  id: string
  started_at: string
  status: string
  source?: string | null
}

export type StalkerNoteBackfillResult = {
  ok: boolean
  jobId?: string
  runId?: string
  run?: StalkerNoteBackfillRun
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

export async function countStalkerNoteBackfillPending(): Promise<number> {
  const res = await fetch('/api/iptv-stalker-note-backfill', {
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

export async function startStalkerNoteBackfill(opts: {
  limit: number
  chunkSize?: number
}): Promise<StalkerNoteBackfillResult> {
  const res = await fetch('/api/iptv-stalker-note-backfill', {
    method: 'POST',
    headers: await authHeaders(),
    body: JSON.stringify({
      action: 'start',
      limit: opts.limit,
      chunkSize: opts.chunkSize,
    }),
  })
  const json = (await res.json().catch(() => ({}))) as StalkerNoteBackfillResult & {
    error?: string
  }
  if (!res.ok) throw new Error(json.error || 'Start note backfill failed')
  return {
    ok: true,
    jobId: json.jobId,
    runId: json.runId,
    run: json.run,
    limit: json.limit,
    chunkSize: json.chunkSize,
  }
}

export async function cancelStalkerNoteBackfill(opts?: {
  runId?: string
}): Promise<StalkerNoteBackfillResult> {
  const res = await fetch('/api/iptv-stalker-note-backfill', {
    method: 'POST',
    headers: await authHeaders(),
    body: JSON.stringify({
      action: 'cancel',
      runId: opts?.runId,
    }),
  })
  const json = (await res.json().catch(() => ({}))) as StalkerNoteBackfillResult & {
    error?: string
  }
  if (!res.ok) throw new Error(json.error || 'Cancel note backfill failed')
  return {
    ok: true,
    cancelledInngest: json.cancelledInngest,
  }
}
