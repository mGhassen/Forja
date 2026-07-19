import type { ReactNode } from 'react'
import {
  ForjaAuthProvider,
  useAuth,
  CAPTCHA_REQUIRED_MESSAGE,
  type ForjaAuthHost,
  type ForjaMfaFactor,
  type OAuthProviderId,
  type SignOutScope,
} from '@forja/auth/react'
import { supabase, supabaseConfigured } from '@/lib/supabase'

export {
  useAuth,
  CAPTCHA_REQUIRED_MESSAGE,
  type ForjaMfaFactor,
  type SignOutScope,
}
export type { OAuthProviderId }

export const AUTH_UNAVAILABLE_MESSAGE =
  "Sign-in isn't available right now. Check VITE_SUPABASE_* in apps/admin/.env."

const host: ForjaAuthHost = {
  client: supabase,
  configured: supabaseConfigured,
  unavailableMessage: AUTH_UNAVAILABLE_MESSAGE,
  features: {
    passkeys: false,
    signup: false,
    deleteAccount: false,
    passwordRecovery: false,
    visibilityRefresh: true,
  },
}

/** Admin AuthProvider — same @forja/auth package as the portal. */
export function AuthProvider({ children }: { children: ReactNode }) {
  return <ForjaAuthProvider host={host}>{children}</ForjaAuthProvider>
}
