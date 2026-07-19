import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig, loadEnv } from 'vite'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import { nitro } from 'nitro/vite'
import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

const adminRoot = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(adminRoot, '../..')
const webRoot = path.resolve(adminRoot, '../web')

/** Same env bridge as apps/web — root `.env` SUPABASE_* unlocks local admin. */
function bridgeEnv(mode: string) {
  const localEnv = loadEnv(mode, adminRoot, '')
  const rootEnv = loadEnv(mode, repoRoot, '')
  const url =
    localEnv.VITE_SUPABASE_URL ||
    rootEnv.VITE_SUPABASE_URL ||
    rootEnv.SUPABASE_URL ||
    ''
  const key =
    localEnv.VITE_SUPABASE_PUBLISHABLE_KEY ||
    rootEnv.VITE_SUPABASE_PUBLISHABLE_KEY ||
    rootEnv.SUPABASE_PUBLISHABLE_KEY ||
    ''
  const turnstile =
    localEnv.VITE_TURNSTILE_SITE_KEY ||
    rootEnv.VITE_TURNSTILE_SITE_KEY ||
    rootEnv.TURNSTILE_SITE_KEY ||
    ''
  if (url && !process.env.VITE_SUPABASE_URL) {
    process.env.VITE_SUPABASE_URL = url
  }
  if (key && !process.env.VITE_SUPABASE_PUBLISHABLE_KEY) {
    process.env.VITE_SUPABASE_PUBLISHABLE_KEY = key
  }
  if (turnstile && !process.env.VITE_TURNSTILE_SITE_KEY) {
    process.env.VITE_TURNSTILE_SITE_KEY = turnstile
  }

  // Server-only Inngest catalog scrape — never VITE_*
  const serviceRole =
    localEnv.SUPABASE_SERVICE_ROLE_KEY || rootEnv.SUPABASE_SERVICE_ROLE_KEY || ''
  if (serviceRole && !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    process.env.SUPABASE_SERVICE_ROLE_KEY = serviceRole
  }
  if (url && !process.env.SUPABASE_URL) {
    process.env.SUPABASE_URL = url
  }
  for (const k of [
    'INNGEST_EVENT_KEY',
    'INNGEST_SIGNING_KEY',
    'INNGEST_DEV',
  ] as const) {
    const v = localEnv[k] || rootEnv[k] || ''
    // Always prefer apps/admin/.env over a stale shell export
    if (v) process.env[k] = v
  }
  // Local default: Dev Server unless explicitly disabled
  if (!process.env.INNGEST_DEV) process.env.INNGEST_DEV = '1'
}

export default defineConfig(({ mode }) => {
  bridgeEnv(mode)

  // Bake server env into SSR bundle (Nitro/Vite otherwise drop non-VITE_ reads)
  const defineEnv: Record<string, string> = {}
  for (const k of [
    'INNGEST_DEV',
    'INNGEST_EVENT_KEY',
    'INNGEST_SIGNING_KEY',
    'SUPABASE_URL',
    'SUPABASE_SERVICE_ROLE_KEY',
    'VITE_SUPABASE_URL',
    'VITE_SUPABASE_PUBLISHABLE_KEY',
  ] as const) {
    const v = process.env[k]
    if (v) defineEnv[`process.env.${k}`] = JSON.stringify(v)
  }

  return {
    define: defineEnv,
    server: {
      port: 4000,
      host: '127.0.0.1',
      fs: {
        allow: [adminRoot, webRoot, repoRoot],
      },
    },
    resolve: {
      tsconfigPaths: true,
    },
    plugins: [tanstackStart(), nitro(), viteReact(), tailwindcss()],
  }
})
