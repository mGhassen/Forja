import {
  exchangeAuthCode as exchangeAuthCodeShared,
  type AuthCallbackResult,
} from '@forja/auth'
import { supabase, supabaseConfigured } from '@/lib/supabase'

export type { AuthCallbackResult }

/** Portal-bound PKCE exchange (default next → account profiles). */
export async function exchangeAuthCode(options?: {
  search?: string
  defaultNext?: string
  errorPath?: string
}): Promise<AuthCallbackResult> {
  return exchangeAuthCodeShared(supabase, supabaseConfigured, {
    defaultNext: '/account/profiles',
    errorPath: '/login',
    ...options,
    unavailableMessage:
      "Sign-in isn't available right now. Download Forja and play without an account.",
  })
}
