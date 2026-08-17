import { inngest } from '@/inngest/client'

type EventPayload = {
  name: string
  data?: Record<string, unknown>
}

function onVercel(): boolean {
  return process.env.VERCEL === '1' || !!process.env.VERCEL_ENV
}

function useLocalDevServer(): boolean {
  if (onVercel()) return false
  const v = process.env.INNGEST_DEV?.trim()
  return (
    v === '1' ||
    v === 'true' ||
    !!v?.startsWith('http://127.') ||
    !!v?.startsWith('http://localhost')
  )
}

function localDevBase(): string {
  const v = process.env.INNGEST_DEV?.trim()
  if (v?.startsWith('http://') || v?.startsWith('https://')) {
    return v.replace(/\/$/, '')
  }
  return 'http://127.0.0.1:8288'
}

function serveOrigin(): string {
  const fromEnv = process.env.INNGEST_SERVE_ORIGIN?.trim()
  if (fromEnv) return fromEnv.replace(/\/$/, '')
  return 'https://admin.forjahq.xyz'
}

/**
 * Push current serve() functions to Inngest Cloud (out-of-band PUT sync).
 * Event send does NOT register functions — without this, new jobs get
 * events with no runs.
 */
export async function syncInngestApp(): Promise<void> {
  if (useLocalDevServer()) return
  const url = `${serveOrigin()}/api/inngest`
  let res: Response
  try {
    res = await fetch(url, { method: 'PUT' })
  } catch (e) {
    const why = e instanceof Error ? e.message : String(e)
    throw new Error(`Inngest sync unreachable (${url}): ${why}`)
  }
  const text = await res.text()
  if (!res.ok) {
    throw new Error(
      `Inngest sync ${res.status} at ${url}. ${text.slice(0, 240)}`,
    )
  }
}

/**
 * Local (INNGEST_DEV): POST Dev Server /e/local.
 * Vercel/prod: Inngest Cloud via SDK (needs INNGEST_EVENT_KEY).
 */
export async function sendInngestEvent(
  event: EventPayload,
): Promise<{ ids: string[] }> {
  if (useLocalDevServer()) {
    const url = `${localDevBase()}/e/local`
    let res: Response
    try {
      res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify([
          { name: event.name, data: event.data ?? {} },
        ]),
      })
    } catch (e) {
      const why = e instanceof Error ? e.message : String(e)
      throw new Error(
        `Inngest Dev Server unreachable (${url}): ${why}. Run: npx inngest-cli@latest dev -u http://127.0.0.1:4000/api/inngest`,
      )
    }
    const text = await res.text()
    if (!res.ok) {
      throw new Error(
        `Inngest Dev Server ${res.status} at ${url}. ${text.slice(0, 200)}`,
      )
    }
    try {
      const parsed = JSON.parse(text) as { ids?: string[] }
      return { ids: parsed.ids ?? [] }
    } catch {
      return { ids: [] }
    }
  }

  const eventKey = process.env.INNGEST_EVENT_KEY?.trim()
  if (!eventKey) {
    throw new Error(
      'INNGEST_EVENT_KEY missing on this host. Set it in Vercel → forja-admin → Environment Variables (Inngest dashboard → Event keys). Do not set INNGEST_DEV on Vercel.',
    )
  }

  try {
    const ids = await inngest.send({
      name: event.name,
      data: event.data ?? {},
    })
    return { ids: Array.isArray(ids) ? ids.map(String) : [String(ids)] }
  } catch (e) {
    const why = e instanceof Error ? e.message : String(e)
    throw new Error(
      `Inngest Cloud send failed: ${why}. Check INNGEST_EVENT_KEY / app sync to https://admin.forjahq.xyz/api/inngest`,
    )
  }
}
