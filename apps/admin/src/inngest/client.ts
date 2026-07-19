import { Inngest } from 'inngest'

const isDev =
  process.env.INNGEST_DEV === '1' ||
  process.env.INNGEST_DEV === 'true' ||
  process.env.INNGEST_DEV === 'http://127.0.0.1:8288' ||
  process.env.INNGEST_DEV === 'http://localhost:8288'

/**
 * Explicit keys — Vite/Nitro often strip bare process.env reads unless bridged
 * in vite.config. Prefer INNGEST_DEV=1 locally (Dev Server :8288).
 */
export const inngest = new Inngest({
  id: 'forja-admin',
  isDev,
  eventKey: process.env.INNGEST_EVENT_KEY,
  signingKey: process.env.INNGEST_SIGNING_KEY,
})
