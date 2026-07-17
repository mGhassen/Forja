import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '@/lib/database.types'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const publishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as
  | string
  | undefined

const looksLikePlaceholder =
  !url ||
  !publishableKey ||
  url.includes('your-project') ||
  publishableKey === 'your-publishable-key' ||
  publishableKey.startsWith('your-')

/** True only when real project credentials are present (not .env.example placeholders). */
export const supabaseConfigured = !looksLikePlaceholder

export const supabase: SupabaseClient<Database> = createClient<Database>(
  looksLikePlaceholder ? 'https://placeholder.supabase.co' : url!,
  looksLikePlaceholder ? 'placeholder' : publishableKey!,
  {
    auth: {
      experimental: { passkey: true },
    },
  },
)
