import { createFileRoute } from '@tanstack/react-router'
import { authedAdmin } from '@/server/admin-request'
import { fetchPosthogPersonsByDistinctIds } from '@/server/posthog-persons'

export const Route = createFileRoute('/api/posthog-persons')({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const auth = await authedAdmin(request)
        if (auth.error) return auth.error

        const body = (await request.json().catch(() => ({}))) as {
          ids?: unknown
        }
        const ids = Array.isArray(body.ids)
          ? body.ids.filter((id): id is string => typeof id === 'string')
          : []

        const result = await fetchPosthogPersonsByDistinctIds(ids)
        if (result.error && Object.keys(result.persons).length === 0) {
          return Response.json(result, { status: 502 })
        }
        return Response.json(result)
      },
    },
  },
})
