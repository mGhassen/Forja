import type { EmailOtpType, SupabaseClient } from '@supabase/supabase-js'
import { mapAuthError } from './errors'

export type AuthCallbackResult =
  | { status: 'ok'; nextPath: string }
  | { status: 'error'; message: string; nextPath: string }

const DEFAULT_UNAVAILABLE =
  "Sign-in isn't available right now. Download Forja and play without an account."

const EMAIL_OTP_TYPES = new Set<string>([
  'signup',
  'invite',
  'magiclink',
  'recovery',
  'email_change',
  'email',
])

/** Relative app path only — blocks open redirects. */
export function safeAuthNextPath(raw: string | null, fallback: string): string {
  if (!raw) return fallback
  if (!raw.startsWith('/') || raw.startsWith('//')) return fallback
  return raw
}

function isEmailOtpType(value: string): value is EmailOtpType {
  return EMAIL_OTP_TYPES.has(value)
}

/**
 * Finish an auth redirect into a session:
 * - `?code=` — PKCE (OAuth / older ConfirmationURL redirects)
 * - `?token_hash=&type=` — email confirm / invite (session without PKCE verifier)
 *
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

  const next = safeAuthNextPath(params.get('next'), defaultNext)
  const code = params.get('code')
  const tokenHash = params.get('token_hash')
  const typeRaw = params.get('type')

  if (!code && !tokenHash) {
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

  if (tokenHash) {
    if (!typeRaw || !isEmailOtpType(typeRaw)) {
      return {
        status: 'error',
        message: 'That confirmation link is invalid. Request a new one.',
        nextPath: errorPath,
      }
    }
    const { data, error } = await client.auth.verifyOtp({
      token_hash: tokenHash,
      type: typeRaw,
    })
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
    if (!data.session) {
      return {
        status: 'error',
        message: 'Email confirmed, but sign-in failed. Log in with your password.',
        nextPath: errorPath,
      }
    }
    return { status: 'ok', nextPath: next }
  }

  const { data, error } = await client.auth.exchangeCodeForSession(code!)
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
  if (!data.session) {
    return {
      status: 'error',
      message: 'Sign-in did not create a session. Try logging in.',
      nextPath: errorPath,
    }
  }

  return { status: 'ok', nextPath: next }
}
