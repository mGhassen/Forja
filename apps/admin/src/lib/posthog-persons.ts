import { supabase } from '@/lib/supabase'

export type PosthogPersonRuntime = {
  distinctId: string
  appVersion: string | null
  platform: string | null
  osVersion: string | null
  arch: string | null
  lastSeenAt: string | null
  memberNumber: number | null
}

export type PosthogPersonsPayload = {
  configured: boolean
  persons: Record<string, PosthogPersonRuntime>
  error?: string
}

/** Admin-only: batch PostHog person runtime for account UUIDs. */
export async function fetchPosthogPersons(
  ids: string[],
): Promise<PosthogPersonsPayload> {
  if (ids.length === 0) {
    return { configured: true, persons: {} }
  }
  const {
    data: { session },
  } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('Not signed in')

  const res = await fetch('/api/posthog-persons', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${session.access_token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ ids }),
  })
  const json = (await res.json().catch(() => ({}))) as PosthogPersonsPayload
  if (!res.ok) {
    throw new Error(json.error || `PostHog persons failed (${res.status})`)
  }
  return json
}

export function formatRelativeSeen(iso: string | null | undefined): string {
  if (!iso?.trim()) return '—'
  const t = Date.parse(iso)
  if (Number.isNaN(t)) return '—'
  const sec = Math.round((Date.now() - t) / 1000)
  if (sec < 60) return 'just now'
  if (sec < 3600) return `${Math.floor(sec / 60)}m ago`
  if (sec < 86400) return `${Math.floor(sec / 3600)}h ago`
  if (sec < 86400 * 14) return `${Math.floor(sec / 86400)}d ago`
  return new Date(t).toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
  })
}

export function formatClientLabel(
  p: PosthogPersonRuntime | undefined,
): string {
  if (!p) return '—'
  const bits = [p.platform, p.arch].filter(Boolean)
  return bits.length ? bits.join(' · ') : '—'
}
