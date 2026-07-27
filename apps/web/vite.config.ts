import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig, loadEnv } from 'vite'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import { nitro } from 'nitro/vite'
import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

const webRoot = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(webRoot, '../..')
const forjaAuthRoot = path.resolve(repoRoot, 'packages/forja-auth')

/**
 * Prefer apps/web/.env VITE_* keys; fall back to repo-root SUPABASE_* /
 * VITE_SUPABASE_* / RELEASE_CDN_URL so one root .env unlocks web locally.
 * PostHog web key is separate from Flutter POSTHOG_API_KEY — never bridge that.
 */
function bridgeWebEnv(mode: string) {
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
  const releaseCdn =
    webEnv.VITE_RELEASE_CDN_URL ||
    rootEnv.VITE_RELEASE_CDN_URL ||
    rootEnv.RELEASE_CDN_URL ||
    ''
  if (url && !process.env.VITE_SUPABASE_URL) {
    process.env.VITE_SUPABASE_URL = url
  }
  if (key && !process.env.VITE_SUPABASE_PUBLISHABLE_KEY) {
    process.env.VITE_SUPABASE_PUBLISHABLE_KEY = key
  }
  if (releaseCdn && !process.env.VITE_RELEASE_CDN_URL) {
    process.env.VITE_RELEASE_CDN_URL = releaseCdn
  }
  const oauth =
    webEnv.VITE_AUTH_OAUTH_PROVIDERS ||
    rootEnv.VITE_AUTH_OAUTH_PROVIDERS ||
    ''
  if (oauth && !process.env.VITE_AUTH_OAUTH_PROVIDERS) {
    process.env.VITE_AUTH_OAUTH_PROVIDERS = oauth
  }
  // Web PostHog is its own project. Only VITE_POSTHOG_* (web or root), never
  // Flutter POSTHOG_API_KEY.
  const posthogKey =
    webEnv.VITE_POSTHOG_KEY || rootEnv.VITE_POSTHOG_KEY || ''
  const posthogHost =
    webEnv.VITE_POSTHOG_HOST ||
    rootEnv.VITE_POSTHOG_HOST ||
    rootEnv.POSTHOG_HOST ||
    ''
  if (posthogKey && !process.env.VITE_POSTHOG_KEY) {
    process.env.VITE_POSTHOG_KEY = posthogKey
  }
  if (posthogHost && !process.env.VITE_POSTHOG_HOST) {
    process.env.VITE_POSTHOG_HOST = posthogHost
  }
}

export default defineConfig(({ mode }) => {
  bridgeWebEnv(mode)

  return {
    server: {
      port: 3000,
      // Flutter Web login defaults to http://127.0.0.1:3000 (IPv4). Without an
      // explicit host, Vite may bind only [::1] on macOS and the portal looks
      // "down" from the desktop app.
      host: '127.0.0.1',
      fs: {
        allow: [webRoot, repoRoot, forjaAuthRoot],
      },
    },
    resolve: {
      tsconfigPaths: true,
      alias: {
        '@forja/auth/react': path.resolve(forjaAuthRoot, 'src/react/index.ts'),
        '@forja/auth': path.resolve(forjaAuthRoot, 'src/index.ts'),
      },
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
