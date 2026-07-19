import { mapAuthError } from '@/lib/auth/errors'
import { supabase, supabaseConfigured } from '@/lib/supabase'

export type AuthCallbackResult =
  | { status: 'ok'; nextPath: string }
  | { status: 'error'; message: string; nextPath: string }

/**
 * Exchange `?code=` (PKCE OAuth / magic link) for a session.
 * Client-side — TanStack Start SPA has no Guepard-style server cookie adapter.
 */
export async function exchangeAuthCode(options?: {
  search?: string
  defaultNext?: string
  errorPath?: string
}): Promise<AuthCallbackResult> {
  const defaultNext = options?.defaultNext ?? '/account/profiles'
  const errorPath = options?.errorPath ?? '/login'
  const search =
    options?.search ??
    (typeof window !== 'undefined' ? window.location.search : '')
  const params = new URLSearchParams(search)

  const errorParam = params.get('error')
  const errorDescription = params.get('error_description')
  if (errorParam) {
    return {
      status: 'error',
      message: mapAuthError({
        message: errorDescription ?? errorParam,
        code: errorParam,
      }),
      nextPath: `${errorPath}?error=${encodeURIComponent(
        mapAuthError({
          message: errorDescription ?? errorParam,
          code: errorParam,
        }),
      )}`,
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

  if (!supabaseConfigured) {
    return {
      status: 'error',
      message:
        "Sign-in isn't available right now. Download Forja and play without an account.",
      nextPath: errorPath,
    }
  }

  const { error } = await supabase.auth.exchangeCodeForSession(code)
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
