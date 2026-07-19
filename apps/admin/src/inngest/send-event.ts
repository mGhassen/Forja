import { inngest } from '@/inngest/client'

type EventPayload = {
  name: string
  data?: Record<string, unknown>
}

function isLocalDev(): boolean {
  // Never treat Vercel as local — even if INNGEST_DEV leaked into the build.
  if (process.env.VERCEL === '1' || process.env.VERCEL_ENV) return false
  const v = process.env.INNGEST_DEV?.trim()
  return (
    v === '1' ||
    v === 'true' ||
    !!v?.startsWith('http://') ||
    !!v?.startsWith('https://')
  )
}

function localDevBase(): string {
  const v = process.env.INNGEST_DEV?.trim()
  if (v?.startsWith('http://') || v?.startsWith('https://')) {
    return v.replace(/\/$/, '')
  }
  return 'http://127.0.0.1:8288'
}

/**
 * Send to local Dev Server when INNGEST_DEV is set — avoids cloud event-key 502s.
 * Falls back to SDK send (cloud / keyed).
 */
export async function sendInngestEvent(
  event: EventPayload,
): Promise<{ ids: string[] }> {
  if (isLocalDev()) {
    const url = `${localDevBase()}/e/local`
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify([
        { name: event.name, data: event.data ?? {} },
      ]),
    })
    const text = await res.text()
    if (!res.ok) {
      throw new Error(
        `Inngest Dev Server ${res.status} at ${url}. Is \`npx inngest-cli@latest dev -u http://127.0.0.1:4000/api/inngest\` running? ${text.slice(0, 200)}`,
      )
    }
    try {
      const parsed = JSON.parse(text) as { ids?: string[] }
      return { ids: parsed.ids ?? [] }
    } catch {
      return { ids: [] }
    }
  }

  if (!process.env.INNGEST_EVENT_KEY?.trim()) {
    throw new Error(
      'INNGEST_EVENT_KEY missing. For local: set INNGEST_DEV=1 and run Inngest CLI. For prod: set the event key.',
    )
  }

  const ids = await inngest.send({
    name: event.name,
    data: event.data ?? {},
  })
  return { ids: Array.isArray(ids) ? ids.map(String) : [String(ids)] }
}
