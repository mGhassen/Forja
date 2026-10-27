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

function readHashParams(hash: string): URLSearchParams {
  return new URLSearchParams(hash.replace(/^#/, ''))
}

/**
 * Default / misconfigured confirm emails land on Site URL with
 * `#access_token=…&type=signup` (or `?code=` / `?token_hash=`). Supabase then
 * consumes the hash on `/` and leaves the user on `/#` with no profiles hop.
 * Move those onto `/auth/callback` *before* `createClient` (keep recovery on
 * `/reset-password`).
 *
 * @returns true when `location.replace` was called (page will reload).
 */
export function relocateAuthRedirectToCallback(options?: {
  callbackPath?: string
  defaultNext?: string
  /** Injected for tests. Defaults to `window.location`. */
  location?: Pick<Location, 'pathname' | 'search' | 'hash' | 'replace'>
}): boolean {
  if (typeof window === 'undefined' && !options?.location) return false
  const loc = options?.location ?? window.location
  const callbackPath = options?.callbackPath ?? '/auth/callback'
  const defaultNext = options?.defaultNext ?? '/account/profiles'

  const path = loc.pathname
  if (path === callbackPath || path.endsWith(callbackPath)) return false
  if (path === '/reset-password' || path.endsWith('/reset-password')) {
    return false
  }

  const hashParams = readHashParams(loc.hash)
  const query = new URLSearchParams(loc.search)
  const type = hashParams.get('type') ?? query.get('type')
  if (type === 'recovery') return false

  const hasImplicit = hashParams.has('access_token')
  const hasTokenHash = query.has('token_hash')
  const hasCode = query.has('code')
  const hasError = query.has('error') || hashParams.has('error')
  if (!hasImplicit && !hasTokenHash && !hasCode && !hasError) return false

  const nextQuery = new URLSearchParams(query)
  if (!nextQuery.has('next') && (hasImplicit || hasTokenHash || hasCode)) {
    nextQuery.set('next', defaultNext)
  }
  const qs = nextQuery.toString()
  const keepHash =
    hasImplicit || hashParams.has('error') || hashParams.has('error_description')
      ? loc.hash
      : ''
  loc.replace(`${callbackPath}${qs ? `?${qs}` : ''}${keepHash}`)
  return true
}

/**
 * Finish an auth redirect into a session:
 * - `?code=` — PKCE (OAuth / older ConfirmationURL redirects)
 * - `?token_hash=&type=` — email confirm / invite (session without PKCE verifier)
 * - `#access_token=&refresh_token=` — implicit Site URL / ConfirmationURL hash
 *
 * Client-side — works for both portal and admin SPAs.
 */
export async function exchangeAuthCode(
  client: SupabaseClient,
  configured: boolean,
  options?: {
    search?: string
    hash?: string
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
  const hash =
    options?.hash ??
    (typeof window !== 'undefined' ? window.location.hash : '')
  const params = new URLSearchParams(search)
  const hashParams = readHashParams(hash)

  const errorParam = params.get('error') ?? hashParams.get('error')
  const errorDescription =
    params.get('error_description') ?? hashParams.get('error_description')
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

  const next = safeAuthNextPath(
    params.get('next') ?? hashParams.get('next'),
    defaultNext,
  )
  const code = params.get('code')
  const tokenHash = params.get('token_hash')
  const typeRaw = params.get('type') ?? hashParams.get('type')
  const accessToken = hashParams.get('access_token')
  const refreshToken = hashParams.get('refresh_token')

  if (!code && !tokenHash && !(accessToken && refreshToken)) {
    // detectSessionInUrl may have already consumed the hash — session is enough.
    if (configured) {
      const { data } = await client.auth.getSession()
      if (data.session) {
        return { status: 'ok', nextPath: next }
      }
    }
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

  if (accessToken && refreshToken) {
    const { data, error } = await client.auth.setSession({
      access_token: accessToken,
      refresh_token: refreshToken,
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
    if (typeof window !== 'undefined' && window.location.hash) {
      const clean =
        window.location.pathname + window.location.search
      window.history.replaceState(null, '', clean)
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
