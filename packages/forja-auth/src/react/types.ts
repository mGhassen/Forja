import type { Factor, Session, SupabaseClient, User } from '@supabase/supabase-js'
import type { ReactNode } from 'react'
import type { OAuthProviderId } from '../config'

export type SignOutScope = 'local' | 'global'

export type AuthResult = {
  error: string | null
  needsEmailConfirmation?: boolean
  needsMfa?: boolean
}

export type ForjaPasskey = {
  id: string
  friendlyName: string | null
  createdAt: string
  lastUsedAt: string | null
}

export type ForjaMfaFactor = {
  id: string
  friendlyName: string | null
  status: Factor['status']
}

export type ForjaAuthFeatures = {
  passkeys?: boolean
  signup?: boolean
  deleteAccount?: boolean
  passwordRecovery?: boolean
  /** Focus/visibility refreshSession (30d inactivity). Default true. */
  visibilityRefresh?: boolean
}

export type ForjaAuthHost = {
  client: SupabaseClient
  configured: boolean
  unavailableMessage: string
  features?: ForjaAuthFeatures
  /** App-owned recovery lock (blocks data APIs). */
  passwordRecovery?: {
    setLock: (active: boolean) => void
    isLockActive: () => boolean
  }
  /** e.g. desktop handoff — pause portal RT rotation. */
  pauseSessionRefresh?: {
    shouldPause: () => boolean
    onDetectPause?: () => void
  }
}

export type ForjaAuthContextValue = {
  session: Session | null
  user: User | null
  loading: boolean
  configured: boolean
  requiresMfa: boolean
  isPasswordRecovery: boolean
  signIn: (
    email: string,
    password: string,
    options?: { captchaToken?: string },
  ) => Promise<AuthResult>
  signInWithPasskey: (options?: {
    captchaToken?: string
  }) => Promise<AuthResult>
  signInWithOAuth: (provider: OAuthProviderId) => Promise<AuthResult>
  signUp: (
    email: string,
    password: string,
    options?: { captchaToken?: string },
  ) => Promise<AuthResult>
  verifySignupOtp: (email: string, token: string) => Promise<AuthResult>
  requestPasswordReset: (
    email: string,
    options?: { captchaToken?: string },
  ) => Promise<AuthResult>
  updatePassword: (password: string) => Promise<AuthResult>
  registerPasskey: () => Promise<{
    error: string | null
    passkey: ForjaPasskey | null
  }>
  listPasskeys: () => Promise<{
    error: string | null
    passkeys: ForjaPasskey[]
  }>
  deletePasskey: (passkeyId: string) => Promise<{ error: string | null }>
  refreshMfaStatus: () => Promise<boolean>
  listMfaFactors: () => Promise<{
    error: string | null
    factors: ForjaMfaFactor[]
  }>
  enrollMfaTotp: () => Promise<{
    error: string | null
    factorId: string | null
    qrCode: string | null
    secret: string | null
  }>
  challengeAndVerifyMfa: (
    factorId: string,
    code: string,
  ) => Promise<AuthResult>
  unenrollMfa: (factorId: string) => Promise<{ error: string | null }>
  signOut: (options?: { scope?: SignOutScope }) => Promise<void>
  deleteAccount: (confirmEmail: string) => Promise<{ error: string | null }>
}

export type ForjaAuthProviderProps = {
  host: ForjaAuthHost
  children: ReactNode
}
