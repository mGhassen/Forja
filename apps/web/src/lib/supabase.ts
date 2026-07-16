import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '@/lib/database.types'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined

const looksLikePlaceholder =
  !url ||
  !anonKey ||
  url.includes('your-project') ||
  anonKey === 'your-anon-key' ||
  anonKey.startsWith('your-')

/** True only when real project credentials are present (not .env.example placeholders). */
export const supabaseConfigured = !looksLikePlaceholder

export const supabase: SupabaseClient<Database> = createClient<Database>(
  looksLikePlaceholder ? 'https://placeholder.supabase.co' : url!,
  looksLikePlaceholder ? 'placeholder' : anonKey!,
)
