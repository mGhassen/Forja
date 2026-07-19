import { createFileRoute } from '@tanstack/react-router'
import { fetchR2ChangelogArchive } from '@/lib/r2-changelog'

export const Route = createFileRoute('/api/changelog')({
  server: {
    handlers: {
      GET: async () => {
        try {
          const archive = await fetchR2ChangelogArchive()
          return Response.json(archive, {
            headers: {
              'Cache-Control': 'public, max-age=60, s-maxage=300',
            },
          })
        } catch (e) {
          const message = e instanceof Error ? e.message : 'Changelog unavailable'
          const status = message.includes('not configured') ? 503 : 502
          return Response.json({ error: message }, { status })
        }
      },
    },
  },
})
