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

/**
 * When true, the recovery JWT may only talk to Auth (set password / sign out).
 * PostgREST, Storage, and Edge Functions are blocked — recovery is not a login.
 */
let passwordRecoveryLock = false

export function setPasswordRecoveryLock(active: boolean) {
  passwordRecoveryLock = active
}

export function isPasswordRecoveryLockActive() {
  return passwordRecoveryLock
}

function requestUrl(input: RequestInfo | URL): string {
  if (typeof input === 'string') return input
  if (input instanceof URL) return input.href
  return input.url
}

/** Allow Auth endpoints only; deny data APIs while resetting a password. */
function isAllowedDuringPasswordRecovery(target: string): boolean {
  // Session exchange, verify, refresh, logout, update user (password).
  if (target.includes('/auth/v1/')) return true
  // Explicit deny for account data planes.
  if (
    target.includes('/rest/v1/') ||
    target.includes('/storage/v1/') ||
    target.includes('/functions/v1/') ||
    target.includes('/realtime/v1/')
  ) {
    return false
  }
  // Unknown host/path — deny while locked (safer default).
  return false
}

const recoveryGuardedFetch: typeof fetch = async (input, init) => {
  if (!passwordRecoveryLock) {
    return fetch(input, init)
  }
  const target = requestUrl(input)
  if (isAllowedDuringPasswordRecovery(target)) {
    return fetch(input, init)
  }
  return new Response(
    JSON.stringify({
      message:
        'Password recovery session can only change the password. Sign in after resetting.',
      code: 'password_recovery_hold',
    }),
    {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    },
  )
}

export const supabase: SupabaseClient<Database> = createClient<Database>(
  looksLikePlaceholder ? 'https://placeholder.supabase.co' : url!,
  looksLikePlaceholder ? 'placeholder' : publishableKey!,
  {
    auth: {
      experimental: { passkey: true },
    },
    global: {
      fetch: recoveryGuardedFetch,
    },
  },
)
