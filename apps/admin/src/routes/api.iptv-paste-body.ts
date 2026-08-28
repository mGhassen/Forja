import { defineApiRoute } from '@/lib/api-route'
import { fetchPasteBody } from '@/server/iptv-catalog/reddit'
import { authedAdmin } from '@/server/admin-request'

const PASTE_HOSTS = [
  'paste.sh',
  'pastebin.com',
  'justpaste.it',
  'controlc.com',
  'pastes.dev',
  'text.is',
  'rentry.co',
]

function json(data: unknown, status = 200) {
  return Response.json(data, { status })
}

function isAllowedPasteUrl(url: string): boolean {
  try {
    const u = new URL(url)
    if (u.protocol !== 'http:' && u.protocol !== 'https:') return false
    const host = u.hostname.toLowerCase()
    return PASTE_HOSTS.some((h) => host === h || host.endsWith(`.${h}`))
  } catch {
    return false
  }
}

export const Route = defineApiRoute('/api/iptv-paste-body', {
  POST: async ({ request }) => {
        try {
          const gate = await authedAdmin(request)
          if ('error' in gate && gate.error) return gate.error

          const body = (await request.json().catch(() => ({}))) as {
            url?: string
          }
          const url = String(body.url ?? '').trim()
          if (!url) return json({ error: 'url required' }, 400)
          if (!isAllowedPasteUrl(url)) {
            return json({ error: 'unsupported paste host' }, 400)
          }

          const text = await fetchPasteBody(url)
          if (!text) return json({ error: 'paste fetch failed', body: null }, 502)
          return json({ body: text })
        } catch (e) {
          return json(
            { error: e instanceof Error ? e.message : String(e) },
            500,
          )
        }
      },
})
