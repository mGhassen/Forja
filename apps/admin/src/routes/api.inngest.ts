import { createFileRoute } from '@tanstack/react-router'
import { serve } from 'inngest/edge'
import { inngest } from '@/inngest/client'
import { functions } from '@/inngest/functions'

/** Custom domain — *.vercel.app is Deployment-Protected (Inngest gets 401). */
const PROD_SERVE_ORIGIN = 'https://admin.forjahq.xyz'

function resolveServeOrigin(): string | undefined {
  const fromEnv = process.env.INNGEST_SERVE_ORIGIN?.trim()
  if (fromEnv) return fromEnv
  if (process.env.VERCEL === '1' || !!process.env.VERCEL_ENV) {
    return PROD_SERVE_ORIGIN
  }
  return undefined
}

const handler = serve({
  client: inngest,
  functions,
  serveOrigin: resolveServeOrigin(),
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
