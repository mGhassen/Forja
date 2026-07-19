import type { SupabaseClient } from '@supabase/supabase-js'
import { mapAuthError } from './errors'

export type AuthCallbackResult =
  | { status: 'ok'; nextPath: string }
  | { status: 'error'; message: string; nextPath: string }

const DEFAULT_UNAVAILABLE =
  "Sign-in isn't available right now. Download Forja and play without an account."

/**
 * Exchange `?code=` (PKCE OAuth / magic link) for a session.
 * Client-side — works for both portal and admin SPAs.
 */
export async function exchangeAuthCode(
  client: SupabaseClient,
  configured: boolean,
  options?: {
    search?: string
    defaultNext?: string
    errorPath?: string
    unavailableMessage?: string
  },
): Promise<AuthCallbackResult> {
  const defaultNext = options?.defaultNext ?? '/'
  const errorPath = options?.errorPath ?? '/login'
  const search =
    options?.search ??
    (typeof window !== 'undefined' ? window.location.search : '')
  const params = new URLSearchParams(search)

  const errorParam = params.get('error')
  const errorDescription = params.get('error_description')
  if (errorParam) {
    const message = mapAuthError({
      message: errorDescription ?? errorParam,
      code: errorParam,
    })
    return {
      status: 'error',
      message,
      nextPath: `${errorPath}?error=${encodeURIComponent(message)}`,
    }
  }

  const code = params.get('code')
  const next = params.get('next') || defaultNext

  if (!code) {
    return {
      status: 'error',
      message: 'Missing sign-in code. Start again from Log in.',
      nextPath: errorPath,
    }
  }

  if (!configured) {
    return {
      status: 'error',
      message: options?.unavailableMessage ?? DEFAULT_UNAVAILABLE,
      nextPath: errorPath,
    }
  }

  const { error } = await client.auth.exchangeCodeForSession(code)
  if (error) {
    const message = mapAuthError({
      message: error.message,
      code: error.code,
    })
    return {
      status: 'error',
      message,
      nextPath: `${errorPath}?error=${encodeURIComponent(message)}`,
    }
  }

  return { status: 'ok', nextPath: next }
}
