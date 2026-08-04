import { createFileRoute } from '@tanstack/react-router'
import { serve } from 'inngest/remix'
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

/**
 * Remix adapter (Request/Response + streaming). Edge adapter cannot stream —
 * without streaming, a long multi-step invoke dies at Vercel maxDuration with
 * "No step output" / FUNCTION_INVOCATION_TIMEOUT.
 *
 * defaultMaxRuntime: checkpoint budget per HTTP invoke (<< Vercel 300s).
 */
const handler = serve({
  client: inngest,
  functions,
  serveOrigin: resolveServeOrigin(),
  streaming: true,
  defaultMaxRuntime: 45_000,
})

export const Route = createFileRoute('/api/inngest')({
  server: {
    handlers: {
      GET: async ({ request }) => handler({ request }),
      POST: async ({ request }) => handler({ request }),
      PUT: async ({ request }) => handler({ request }),
    },
  },
})
