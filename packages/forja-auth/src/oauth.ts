import type { Provider, SupabaseClient } from '@supabase/supabase-js'
import type { OAuthProviderId } from './config'
import { mapAuthError } from './errors'

const DEFAULT_UNAVAILABLE =
  "Sign-in isn't available right now. Download Forja and play without an account."

function toProvider(id: OAuthProviderId): Provider {
  return id as Provider
}

/** Start OAuth; browser navigates away. Returns error if it cannot start. */
export async function startOAuthSignIn(
  client: SupabaseClient,
  configured: boolean,
  provider: OAuthProviderId,
  options?: { redirectTo?: string; unavailableMessage?: string },
): Promise<{ error: string | null }> {
  if (!configured) {
    return { error: options?.unavailableMessage ?? DEFAULT_UNAVAILABLE }
  }
  const redirectTo =
    options?.redirectTo ??
    (typeof window !== 'undefined'
      ? `${window.location.origin}/auth/callback`
      : undefined)
  const { error } = await client.auth.signInWithOAuth({
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
