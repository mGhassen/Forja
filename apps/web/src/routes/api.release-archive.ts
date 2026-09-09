import { createFileRoute } from '@tanstack/react-router'
import { fetchR2ReleaseArchive } from '@/lib/r2-release-archive'

export const Route = createFileRoute('/api/release-archive')({
  server: {
    handlers: {
      GET: async () => {
        try {
          const archive = await fetchR2ReleaseArchive()
          return Response.json(archive, {
            headers: {
              'Cache-Control': 'public, max-age=60, s-maxage=300',
            },
          })
        } catch (e) {
          const message =
            e instanceof Error ? e.message : 'Release archive unavailable'
          const status = message.includes('not configured') ? 503 : 502
          return Response.json({ error: message }, { status })
        }
      },
    },
  },
})
