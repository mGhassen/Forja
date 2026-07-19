import { Inngest } from 'inngest'

function onVercel(): boolean {
  return process.env.VERCEL === '1' || !!process.env.VERCEL_ENV
}

function localDevMode(): boolean {
  // Production must never talk to 127.0.0.1:8288
  if (onVercel()) return false
  const v = process.env.INNGEST_DEV?.trim()
  return (
    v === '1' ||
    v === 'true' ||
    !!v?.startsWith('http://127.') ||
    !!v?.startsWith('http://localhost')
  )
}

/**
 * On Vercel: always cloud (needs INNGEST_EVENT_KEY + INNGEST_SIGNING_KEY).
 * Local: INNGEST_DEV=1 → Dev Server.
 */
export const inngest = new Inngest({
  id: 'forja-admin',
  isDev: localDevMode(),
  eventKey: process.env.INNGEST_EVENT_KEY,
  signingKey: process.env.INNGEST_SIGNING_KEY,
})
