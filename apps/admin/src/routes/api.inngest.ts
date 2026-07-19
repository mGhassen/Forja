import { createFileRoute } from '@tanstack/react-router'
import { serve } from 'inngest/edge'
import { inngest } from '@/inngest/client'
import { functions } from '@/inngest/functions'

const handler = serve({
  client: inngest,
  functions,
})

export const Route = createFileRoute('/api/inngest')({
  server: {
    handlers: {
      GET: async ({ request }) => handler(request),
      POST: async ({ request }) => handler(request),
      PUT: async ({ request }) => handler(request),
    },
  },
})
