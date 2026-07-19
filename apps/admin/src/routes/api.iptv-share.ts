import { createFileRoute } from '@tanstack/react-router'

const RENTRY_BASE = 'https://rentry.co'
const RENTRY_EDIT_CODE = 'ForjaIptvShare1'
const UA = 'Forja/1.2 (https://github.com/forja-forja/forja)'

type RentrySession = {
  csrf: string
  cookie: string | null
}

function extractCookie(setCookie: string | null): string | null {
  if (!setCookie) return null
  const semi = setCookie.indexOf(';')
  return semi >= 0 ? setCookie.slice(0, semi) : setCookie
}

async function rentrySession(): Promise<RentrySession> {
  const resp = await fetch(`${RENTRY_BASE}/`, {
    headers: { 'User-Agent': UA },
  })
  if (!resp.ok) {
    throw new Error(`Share service unavailable (${resp.status})`)
  }
  const html = await resp.text()
  const csrf = html.match(/csrfmiddlewaretoken" value="([^"]+)"/)?.[1]
  if (!csrf) {
    throw new Error('Share service unavailable (missing CSRF token)')
  }
  const cookie = extractCookie(resp.headers.get('set-cookie'))
  return { csrf, cookie }
}

async function rentryCreate(code: string, text: string): Promise<void> {
  const session = await rentrySession()
  const body = new URLSearchParams({
    csrfmiddlewaretoken: session.csrf,
    url: code,
    edit_code: RENTRY_EDIT_CODE,
    text,
  })
  const resp = await fetch(`${RENTRY_BASE}/api/new`, {
    method: 'POST',
    headers: {
      'User-Agent': UA,
      'Content-Type': 'application/x-www-form-urlencoded',
      ...(session.cookie ? { Cookie: session.cookie } : {}),
    },
    body,
  })
  if (!resp.ok) {
    throw new Error(`Share upload failed (${resp.status})`)
  }
  const decoded = (await resp.json()) as {
    status?: string | number
    errors?: string
  }
  const status = `${decoded.status ?? ''}`
  if (status === '400') {
    const errors = `${decoded.errors ?? ''}`.toLowerCase()
    if (errors.includes('already in use')) {
      throw new Error('already in use')
    }
  }
  if (status !== '200') {
    throw new Error(`Share upload failed (${status})`)
  }
}

async function rentryFetch(code: string): Promise<string | null> {
  const session = await rentrySession()
  const body = new URLSearchParams({
    csrfmiddlewaretoken: session.csrf,
    edit_code: RENTRY_EDIT_CODE,
  })
  const resp = await fetch(
    `${RENTRY_BASE}/api/fetch/${code.toLowerCase()}`,
    {
      method: 'POST',
      headers: {
        'User-Agent': UA,
        'Content-Type': 'application/x-www-form-urlencoded',
        ...(session.cookie ? { Cookie: session.cookie } : {}),
      },
      body,
    },
  )
  if (!resp.ok) return null
  const decoded = (await resp.json()) as {
    status?: string | number
    content?: { text?: string }
  }
  if (`${decoded.status}` !== '200') return null
  return decoded.content?.text ?? null
}

function json(data: unknown, status = 200) {
  return Response.json(data, { status })
}

export const Route = createFileRoute('/api/iptv-share')({
  server: {
    handlers: {
      POST: async ({ request }) => {
        try {
          const body = (await request.json()) as {
            action?: string
            code?: string
            text?: string
          }
          const action = body.action
          const code = (body.code ?? '')
            .trim()
            .toUpperCase()
            .replace(/[^A-Z0-9]/g, '')

          if (action === 'create') {
            const text = body.text?.trim() ?? ''
            if (code.length !== 8 || !text) {
              return json({ error: 'Invalid share payload' }, 400)
            }
            await rentryCreate(code, text)
            return json({ ok: true, code })
          }

          if (action === 'fetch') {
            if (code.length !== 8) {
              return json({ error: 'Invalid share code' }, 400)
            }
            const text = await rentryFetch(code)
            if (!text) return json({ error: 'Share code not found' }, 404)
            return json({ ok: true, text })
          }

          return json({ error: 'Unknown action' }, 400)
        } catch (error) {
          const message =
            error instanceof Error ? error.message : 'Share service failed'
          const status = message.toLowerCase().includes('already in use')
            ? 409
            : 502
          return json({ error: message }, status)
        }
      },
    },
  },
})
