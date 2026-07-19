import type { ReactNode } from 'react'
import {
  ForjaAuthProvider,
  useAuth,
  CAPTCHA_REQUIRED_MESSAGE,
  type ForjaAuthHost,
  type ForjaMfaFactor,
  type ForjaPasskey,
  type OAuthProviderId,
  type SignOutScope,
} from '@forja/auth/react'
import {
  isDesktopHandoffPending,
  lockDesktopHandoff,
} from '@/lib/desktop-auth-callback'
import {
  isPasswordRecoveryLockActive,
  setPasswordRecoveryLock,
  supabase,
  supabaseConfigured,
} from '@/lib/supabase'

export {
  useAuth,
  CAPTCHA_REQUIRED_MESSAGE,
  type ForjaMfaFactor,
  type ForjaPasskey,
  type SignOutScope,
}
export type { OAuthProviderId }

/** Never expose env keys, paths, or backend names to end users. */
export const AUTH_UNAVAILABLE_MESSAGE =
  "Sign-in isn't available right now. Download Forja and play without an account."

const host: ForjaAuthHost = {
  client: supabase,
  configured: supabaseConfigured,
  unavailableMessage: AUTH_UNAVAILABLE_MESSAGE,
  features: {
    passkeys: true,
    signup: true,
    deleteAccount: true,
    passwordRecovery: true,
    visibilityRefresh: true,
  },
  passwordRecovery: {
    setLock: setPasswordRecoveryLock,
    isLockActive: isPasswordRecoveryLockActive,
  },
  pauseSessionRefresh: {
    shouldPause: isDesktopHandoffPending,
    onDetectPause: lockDesktopHandoff,
  },
}

/** Portal AuthProvider — full shared @forja/auth + desktop handoff pause. */
export function AuthProvider({ children }: { children: ReactNode }) {
  return <ForjaAuthProvider host={host}>{children}</ForjaAuthProvider>
}
