import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig, loadEnv } from 'vite'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import { nitro } from 'nitro/vite'
import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

const webRoot = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(webRoot, '../..')

/**
 * Prefer apps/web/.env VITE_* keys; fall back to repo-root SUPABASE_* /
 * VITE_SUPABASE_* so one root .env can unlock web auth locally.
 */
function bridgeSupabaseEnv(mode: string) {
  const webEnv = loadEnv(mode, webRoot, '')
  const rootEnv = loadEnv(mode, repoRoot, '')
  const url =
    webEnv.VITE_SUPABASE_URL ||
    rootEnv.VITE_SUPABASE_URL ||
    rootEnv.SUPABASE_URL ||
    ''
  const key =
    webEnv.VITE_SUPABASE_PUBLISHABLE_KEY ||
    rootEnv.VITE_SUPABASE_PUBLISHABLE_KEY ||
    rootEnv.SUPABASE_PUBLISHABLE_KEY ||
    ''
  if (url && !process.env.VITE_SUPABASE_URL) {
    process.env.VITE_SUPABASE_URL = url
  }
  if (key && !process.env.VITE_SUPABASE_PUBLISHABLE_KEY) {
    process.env.VITE_SUPABASE_PUBLISHABLE_KEY = key
  }
}

export default defineConfig(({ mode }) => {
  bridgeSupabaseEnv(mode)

  return {
    server: {
      port: 3000,
    },
    resolve: {
      tsconfigPaths: true,
    },
    plugins: [
      // Start plugin must come before react()
      tanstackStart(),
      // Required for Vercel — emits serverless functions instead of static-only dist
      nitro(),
      viteReact(),
      tailwindcss(),
    ],
  }
})
