import { createFileRoute } from '@tanstack/react-router'
import { fetchR2LatestRelease } from '@/lib/r2-latest-release'

export const Route = createFileRoute('/api/latest-release')({
  server: {
    handlers: {
      GET: async () => {
        try {
          const release = await fetchR2LatestRelease()
          return Response.json(release, {
            headers: {
              'Cache-Control': 'public, max-age=60, s-maxage=300',
            },
          })
        } catch (e) {
          const message =
            e instanceof Error ? e.message : 'Latest release unavailable'
          const status = message.includes('not configured') ? 503 : 502
          return Response.json({ error: message }, { status })
        }
      },
    },
  },
})
