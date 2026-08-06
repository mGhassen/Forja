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
 * Remix adapter (Request/Response + streaming). Heartbeats keep the Vercel
 * connection alive while a single step runs (paste fetch / bulk insert).
 * Scrape itself uses checkpointing:false + sleep('0s') so each HTTP invoke
 * finishes one step — never return fat portal arrays from step.run (that
 * truncated the stream body → unexpected end of JSON input).
 *
 * defaultMaxRuntime only applies when checkpointing is on; kept for other fns.
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
