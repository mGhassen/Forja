import { serve } from 'inngest/remix'
import { inngest } from '@/inngest/client'
import { functions } from '@/inngest/functions'
import { defineApiRoute } from '@/lib/api-route'

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
 * Remix Request/Response adapter on Nitro/Vercel Node (not Edge).
 *
 * streaming:false — Remix streaming is Edge-only; on Node the heartbeat
 * stream routinely truncates → Inngest "unexpected end of JSON input".
 * Classic scrape (checkpointing:false + sleep('0s')) finishes one step per
 * invoke under maxDuration=300 — no stream needed.
 */
const handler = serve({
  client: inngest,
  functions,
  serveOrigin: resolveServeOrigin(),
  streaming: false,
})

export const Route = defineApiRoute('/api/inngest', {
  GET: ({ request }) => handler({ request }),
  POST: ({ request }) => handler({ request }),
  PUT: ({ request }) => handler({ request }),
})
