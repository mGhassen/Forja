import { startOAuthSignIn as startOAuthSignInShared } from '@forja/auth'
import type { OAuthProviderId } from '@forja/auth'
import { supabase, supabaseConfigured } from '@/lib/supabase'

/** Portal-bound OAuth start (shared @forja/auth + web Supabase client). */
export async function startOAuthSignIn(
  provider: OAuthProviderId,
  options?: { redirectTo?: string },
): Promise<{ error: string | null }> {
  return startOAuthSignInShared(supabase, supabaseConfigured, provider, {
    ...options,
    unavailableMessage:
      "Sign-in isn't available right now. Download Forja and play without an account.",
  })
}
