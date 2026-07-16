import { defineConfig } from 'vite'
import { tanstackStart } from '@tanstack/react-start/plugin/vite'
import { nitro } from 'nitro/vite'
import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
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
})
