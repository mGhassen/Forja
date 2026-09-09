import { defineApiRoute } from '@/lib/api-route'
import { authedAdmin } from '@/server/admin-request'
import {
  assertSafePackUrl,
  normalizePluginPackUrl,
} from '@/lib/plugin-pack-url'

function json(data: unknown, status = 200) {
  return Response.json(data, { status })
}

async function upstreamExists(url: string): Promise<boolean> {
  try {
    const head = await fetch(url, { method: 'HEAD', cache: 'no-store' })
    if (head.ok) return true
    if (head.status === 405 || head.status === 403) {
      const get = await fetch(url, {
        method: 'GET',
        cache: 'no-store',
        headers: { Range: 'bytes=0-0' },
      })
      return get.ok || get.status === 206
    }
    return false
  } catch {
    return false
  }
}

async function upstreamJson(url: string): Promise<{
  url: string
  data: unknown
}> {
  const primary = normalizePluginPackUrl(url)
  assertSafePackUrl(primary)

  const tryFetch = async (target: string) => {
    const res = await fetch(target, { cache: 'no-store' })
    if (!res.ok) {
      throw new Error(`manifest HTTP ${res.status} for ${target}`)
    }
    const text = await res.text()
    try {
      return { url: target, data: JSON.parse(text) as unknown }
    } catch {
      throw new Error(
        `Response is not JSON (got HTML or text). Use a raw manifest.json URL.`,
      )
    }
  }

  try {
    return await tryFetch(primary)
  } catch (first) {
    // …/vod/main → …/vod/manifest.json (common paste mistake)
    const alt = normalizePluginPackUrl(primary, { forceManifestFile: true })
    if (alt !== primary) {
      try {
        return await tryFetch(alt)
      } catch {
        // keep first error
      }
    }
    throw first
  }
}

export const Route = defineApiRoute('/api/plugin-pack-fetch', {
  POST: async ({ request }) => {
    try {
      const gate = await authedAdmin(request)
      if ('error' in gate && gate.error) return gate.error

      const body = (await request.json().catch(() => ({}))) as {
        url?: string
        mode?: 'json' | 'exists'
      }
      const url = String(body.url ?? '').trim()
      if (!url) return json({ error: 'url required' }, 400)
      const mode = body.mode === 'exists' ? 'exists' : 'json'

      if (mode === 'exists') {
        const target = normalizePluginPackUrl(url)
        assertSafePackUrl(target)
        const exists = await upstreamExists(target)
        return json({ url: target, exists })
      }

      const result = await upstreamJson(url)
      return json(result)
    } catch (e) {
      return json(
        { error: e instanceof Error ? e.message : String(e) },
        502,
      )
    }
  },
})
