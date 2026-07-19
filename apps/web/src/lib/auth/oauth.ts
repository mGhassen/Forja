import type { Provider } from '@supabase/supabase-js'
import type { OAuthProviderId } from '@/lib/auth/config'
import { mapAuthError } from '@/lib/auth/errors'
import { supabase, supabaseConfigured } from '@/lib/supabase'

function toProvider(id: OAuthProviderId): Provider {
  return id as Provider
}

/** Start OAuth; browser navigates away. Returns error if it cannot start. */
export async function startOAuthSignIn(
  provider: OAuthProviderId,
  options?: { redirectTo?: string },
): Promise<{ error: string | null }> {
  if (!supabaseConfigured) {
    return {
      error:
        "Sign-in isn't available right now. Download Forja and play without an account.",
    }
  }
  const redirectTo =
    options?.redirectTo ??
    (typeof window !== 'undefined'
      ? `${window.location.origin}/auth/callback`
      : undefined)
  const { error } = await supabase.auth.signInWithOAuth({
    provider: toProvider(provider),
    options: { redirectTo },
  })
  if (error) {
    return {
      error: mapAuthError({ message: error.message, code: error.code }),
    }
  }
  return { error: null }
}
