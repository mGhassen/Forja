import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import type { Factor, Session, User } from '@supabase/supabase-js'
import {
  checkRequiresMfa,
  mapAuthError,
  startOAuthSignIn,
  type OAuthProviderId,
} from '@/lib/auth'
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

export type { OAuthProviderId }
export type SignOutScope = 'local' | 'global'

/** Never expose env keys, paths, or backend names to end users. */
export const AUTH_UNAVAILABLE_MESSAGE =
  "Sign-in isn't available right now. Download Forja and play without an account."

export const CAPTCHA_REQUIRED_MESSAGE =
  'Complete the captcha check, then try again.'

/** Survives refresh so a recovery session cannot wander into the app as a normal login. */
const PASSWORD_RECOVERY_STORAGE_KEY = 'forja.password_recovery'

function urlIndicatesPasswordRecovery(): boolean {
  if (typeof window === 'undefined') return false
  const hash = new URLSearchParams(window.location.hash.replace(/^#/, ''))
  if (hash.get('type') === 'recovery') return true
  const query = new URLSearchParams(window.location.search)
  if (query.get('type') === 'recovery') return true
  // PKCE recovery redirects to `/reset-password?code=…` without `type=` in the URL.
  // That path is only used for password reset in this app.
  if (
    window.location.pathname.endsWith('/reset-password') &&
    query.has('code')
  ) {
    return true
  }
  return false
}

function readStoredPasswordRecovery(): boolean {
  if (typeof window === 'undefined') return false
  try {
    return sessionStorage.getItem(PASSWORD_RECOVERY_STORAGE_KEY) === '1'
  } catch {
    return false
  }
}

function persistPasswordRecovery(active: boolean) {
  if (typeof window === 'undefined') return
  try {
    if (active) sessionStorage.setItem(PASSWORD_RECOVERY_STORAGE_KEY, '1')
    else sessionStorage.removeItem(PASSWORD_RECOVERY_STORAGE_KEY)
  } catch {
    // ignore quota / private mode
  }
}

export type ForjaPasskey = {
  id: string
  friendlyName: string | null
  createdAt: string
  lastUsedAt: string | null
}

type AuthResult = {
  error: string | null
  /** True when the user was created but must confirm email before a session exists. */
  needsEmailConfirmation?: boolean
  /** Password/OAuth/passkey succeeded but TOTP challenge is still required. */
  needsMfa?: boolean
}

export type ForjaMfaFactor = {
  id: string
  friendlyName: string | null
  status: Factor['status']
}

type AuthContextValue = {
  session: Session | null
  user: User | null
  loading: boolean
  configured: boolean
  /** True when session is AAL1 but MFA is enrolled (must verify TOTP). */
  requiresMfa: boolean
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
  /** Confirm signup with the OTP emailed after sign-up. */
  verifySignupOtp: (email: string, token: string) => Promise<AuthResult>
  /** Email a password-reset link that opens `/reset-password` with a recovery session. */
  requestPasswordReset: (
    email: string,
    options?: { captchaToken?: string },
  ) => Promise<AuthResult>
  /**
   * True after the user opens the recovery link (PASSWORD_RECOVERY).
   * Required before `updatePassword` on `/reset-password`.
   * While true, `session` / `user` are hidden from the app — recovery is not a login.
   */
  isPasswordRecovery: boolean
  /** Set a new password while in a recovery session, then sign out. */
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
  /** Refresh whether the current session still needs an MFA challenge. */
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
  /**
   * `local` — this browser only (default; keeps desktop session).
   * `global` — revoke refresh tokens on all devices.
   */
  signOut: (options?: { scope?: SignOutScope }) => Promise<void>
  deleteAccount: (confirmEmail: string) => Promise<{ error: string | null }>
}

const AuthContext = createContext<AuthContextValue | null>(null)

function mapPasskey(item: {
  id: string
  friendly_name?: string
  created_at: string
  last_used_at?: string
}): ForjaPasskey {
  return {
    id: item.id,
    friendlyName: item.friendly_name ?? null,
    createdAt: item.created_at,
    lastUsedAt: item.last_used_at ?? null,
  }
}

function markPasswordRecovery(
  setFlag: (value: boolean) => void,
  active: boolean,
) {
  persistPasswordRecovery(active)
  setPasswordRecoveryLock(active)
  setFlag(active)
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const [requiresMfa, setRequiresMfa] = useState(false)
  const [isPasswordRecovery, setIsPasswordRecovery] = useState(() => {
    if (urlIndicatesPasswordRecovery()) {
      persistPasswordRecovery(true)
      setPasswordRecoveryLock(true)
      return true
    }
    const stored = readStoredPasswordRecovery()
    if (stored) setPasswordRecoveryLock(true)
    return stored
  })

  const refreshMfaStatus = useCallback(async (): Promise<boolean> => {
    if (!supabaseConfigured) {
      setRequiresMfa(false)
      return false
    }
    const needed = await checkRequiresMfa(supabase)
    setRequiresMfa(needed)
    return needed
  }, [])

  useEffect(() => {
    if (!supabaseConfigured) {
      setLoading(false)
      return
    }

    let mounted = true

    // Catch recovery tokens in the URL before they are stripped by the client.
    if (urlIndicatesPasswordRecovery()) {
      markPasswordRecovery(setIsPasswordRecovery, true)
    }

    // Subscribe first so PASSWORD_RECOVERY from the email redirect is not missed.
    const { data: sub } = supabase.auth.onAuthStateChange((event, next) => {
      if (!mounted) return
      if (event === 'PASSWORD_RECOVERY' || urlIndicatesPasswordRecovery()) {
        markPasswordRecovery(setIsPasswordRecovery, true)
      }
      if (event === 'SIGNED_OUT') {
        markPasswordRecovery(setIsPasswordRecovery, false)
        setRequiresMfa(false)
      }
      setSession(next)
      setLoading(false)
      if (next && event !== 'PASSWORD_RECOVERY') {
        void checkRequiresMfa(supabase).then((needed) => {
          if (mounted) setRequiresMfa(needed)
        })
      } else if (!next) {
        setRequiresMfa(false)
      }
    })

    void supabase.auth.getSession().then(async ({ data }) => {
      if (!mounted) return
      setSession(data.session)
      setLoading(false)
      if (data.session) {
        setRequiresMfa(await checkRequiresMfa(supabase))
      }
    })

    // Reset Auth inactivity clock (7d) when the tab becomes visible again.
    // Skip during desktop handoff — rotating the refresh token here races the
    // app's setSession and yields refresh_token_already_used on both sides.
    if (isDesktopHandoffPending()) {
      lockDesktopHandoff()
    }
    let lastRefresh = 0
    const refreshIfVisible = () => {
      if (!mounted || isPasswordRecoveryLockActive()) return
      if (isDesktopHandoffPending()) return
      if (document.visibilityState !== 'visible') return
      const now = Date.now()
      if (now - lastRefresh < 30_000) return
      lastRefresh = now
      void supabase.auth.refreshSession().then(({ data }) => {
        if (mounted && data.session) setSession(data.session)
      })
    }
    document.addEventListener('visibilitychange', refreshIfVisible)
    window.addEventListener('focus', refreshIfVisible)
    if (!isDesktopHandoffPending()) {
      refreshIfVisible()
    }

    return () => {
      mounted = false
      sub.subscription.unsubscribe()
      document.removeEventListener('visibilitychange', refreshIfVisible)
      window.removeEventListener('focus', refreshIfVisible)
    }
  }, [])

  const signIn = useCallback(
    async (
      email: string,
      password: string,
      options?: { captchaToken?: string },
    ): Promise<AuthResult> => {
      if (!supabaseConfigured) {
        if (import.meta.env.DEV) {
          console.warn(
            '[auth] Sign-in unavailable - set VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY in apps/web/.env',
          )
        }
        return { error: AUTH_UNAVAILABLE_MESSAGE }
      }
      const { error } = await supabase.auth.signInWithPassword({
        email,
        password,
        options: options?.captchaToken
          ? { captchaToken: options.captchaToken }
          : undefined,
      })
      if (error) {
        return {
          error: mapAuthError({ message: error.message, code: error.code }),
        }
      }
      const needsMfa = await refreshMfaStatus()
      return { error: null, needsMfa }
    },
    [refreshMfaStatus],
  )

  const signInWithPasskey = useCallback(
    async (options?: { captchaToken?: string }): Promise<AuthResult> => {
      if (!supabaseConfigured) {
        return { error: AUTH_UNAVAILABLE_MESSAGE }
      }
      const { error } = await supabase.auth.signInWithPasskey({
        options: options?.captchaToken
          ? { captchaToken: options.captchaToken }
          : undefined,
      })
      if (error) {
        return {
          error: mapAuthError({ message: error.message, code: error.code }),
        }
      }
      const needsMfa = await refreshMfaStatus()
      return { error: null, needsMfa }
    },
    [refreshMfaStatus],
  )

  const signInWithOAuth = useCallback(
    async (provider: OAuthProviderId): Promise<AuthResult> => {
      const { error } = await startOAuthSignIn(provider)
      return { error }
    },
    [],
  )

  const signUp = useCallback(
    async (
      email: string,
      password: string,
      options?: { captchaToken?: string },
    ): Promise<AuthResult> => {
      if (!supabaseConfigured) {
        if (import.meta.env.DEV) {
          console.warn(
            '[auth] Sign-up unavailable - set VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY in apps/web/.env',
          )
        }
        return { error: AUTH_UNAVAILABLE_MESSAGE }
      }
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          ...(options?.captchaToken
            ? { captchaToken: options.captchaToken }
            : {}),
        },
      })
      if (error) {
        return {
          error: mapAuthError({ message: error.message, code: error.code }),
        }
      }
      const needsEmailConfirmation = Boolean(data.user) && !data.session
      return { error: null, needsEmailConfirmation }
    },
    [],
  )

  const verifySignupOtp = useCallback(
    async (email: string, token: string): Promise<AuthResult> => {
      if (!supabaseConfigured) {
        return { error: AUTH_UNAVAILABLE_MESSAGE }
      }
      const { error } = await supabase.auth.verifyOtp({
        email,
        token: token.trim(),
        type: 'signup',
      })
      if (error) {
        return {
          error: mapAuthError({ message: error.message, code: error.code }),
        }
      }
      const needsMfa = await refreshMfaStatus()
      return { error: null, needsMfa }
    },
    [refreshMfaStatus],
  )

  const requestPasswordReset = useCallback(
    async (
      email: string,
      options?: { captchaToken?: string },
    ): Promise<AuthResult> => {
      if (!supabaseConfigured) {
        if (import.meta.env.DEV) {
          console.warn(
            '[auth] Password reset unavailable - set VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY in apps/web/.env',
          )
        }
        return { error: AUTH_UNAVAILABLE_MESSAGE }
      }
      const redirectTo = `${window.location.origin}/reset-password`
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo,
        ...(options?.captchaToken
          ? { captchaToken: options.captchaToken }
          : {}),
      })
      return {
        error: error
          ? mapAuthError({ message: error.message, code: error.code })
          : null,
      }
    },
    [],
  )

  const updatePassword = useCallback(
    async (password: string): Promise<AuthResult> => {
      if (!supabaseConfigured) {
        return { error: AUTH_UNAVAILABLE_MESSAGE }
      }
      if (!isPasswordRecovery) {
        return {
          error:
            'Open the reset link from your email first. Request a new one if it expired.',
        }
      }
      const { error: updateError } = await supabase.auth.updateUser({
        password,
      })
      if (updateError) {
        return {
          error: mapAuthError({
            message: updateError.message,
            code: updateError.code,
          }),
        }
      }

      markPasswordRecovery(setIsPasswordRecovery, false)
      await supabase.auth.signOut({ scope: 'local' })
      return { error: null }
    },
    [isPasswordRecovery],
  )

  const registerPasskey = useCallback(async (): Promise<{
    error: string | null
    passkey: ForjaPasskey | null
  }> => {
    if (!supabaseConfigured) {
      return { error: AUTH_UNAVAILABLE_MESSAGE, passkey: null }
    }
    if (isPasswordRecovery) {
      return {
        error: 'Finish resetting your password before managing passkeys.',
        passkey: null,
      }
    }
    const { data, error } = await supabase.auth.registerPasskey()
    if (error) return { error: error.message, passkey: null }
    if (!data) return { error: 'Could not register passkey.', passkey: null }
    return { error: null, passkey: mapPasskey(data) }
  }, [isPasswordRecovery])

  const listPasskeys = useCallback(async (): Promise<{
    error: string | null
    passkeys: ForjaPasskey[]
  }> => {
    if (!supabaseConfigured) {
      return { error: AUTH_UNAVAILABLE_MESSAGE, passkeys: [] }
    }
    if (isPasswordRecovery) {
      return {
        error: 'Finish resetting your password before managing passkeys.',
        passkeys: [],
      }
    }
    const { data, error } = await supabase.auth.passkey.list()
    if (error) return { error: error.message, passkeys: [] }
    return {
      error: null,
      passkeys: (data ?? []).map(mapPasskey),
    }
  }, [isPasswordRecovery])

  const deletePasskey = useCallback(
    async (passkeyId: string): Promise<{ error: string | null }> => {
      if (!supabaseConfigured) {
        return { error: AUTH_UNAVAILABLE_MESSAGE }
      }
      if (isPasswordRecovery) {
        return {
          error: 'Finish resetting your password before managing passkeys.',
        }
      }
      const { error } = await supabase.auth.passkey.delete({ passkeyId })
      return { error: error?.message ?? null }
    },
    [isPasswordRecovery],
  )

  const listMfaFactors = useCallback(async (): Promise<{
    error: string | null
    factors: ForjaMfaFactor[]
  }> => {
    if (!supabaseConfigured) {
      return { error: AUTH_UNAVAILABLE_MESSAGE, factors: [] }
    }
    const { data, error } = await supabase.auth.mfa.listFactors()
    if (error) {
      return {
        error: mapAuthError({ message: error.message, code: error.code }),
        factors: [],
      }
    }
    const factors = (data?.totp ?? []).map((f) => ({
      id: f.id,
      friendlyName: f.friendly_name ?? null,
      status: f.status,
    }))
    return { error: null, factors }
  }, [])

  const enrollMfaTotp = useCallback(async (): Promise<{
    error: string | null
    factorId: string | null
    qrCode: string | null
    secret: string | null
  }> => {
    if (!supabaseConfigured) {
      return {
        error: AUTH_UNAVAILABLE_MESSAGE,
        factorId: null,
        qrCode: null,
        secret: null,
      }
    }
    const { data, error } = await supabase.auth.mfa.enroll({
      factorType: 'totp',
      friendlyName: 'Forja authenticator',
    })
    if (error || !data) {
      return {
        error: mapAuthError({
          message: error?.message,
          code: error?.code,
          fallback: 'Could not start authenticator setup.',
        }),
        factorId: null,
        qrCode: null,
        secret: null,
      }
    }
    return {
      error: null,
      factorId: data.id,
      qrCode: data.totp.qr_code,
      secret: data.totp.secret,
    }
  }, [])

  const challengeAndVerifyMfa = useCallback(
    async (factorId: string, code: string): Promise<AuthResult> => {
      if (!supabaseConfigured) {
        return { error: AUTH_UNAVAILABLE_MESSAGE }
      }
      const { data: challenge, error: challengeError } =
        await supabase.auth.mfa.challenge({ factorId })
      if (challengeError || !challenge) {
        return {
          error: mapAuthError({
            message: challengeError?.message,
            code: challengeError?.code,
            fallback: 'Could not start verification.',
          }),
        }
      }
      const { error } = await supabase.auth.mfa.verify({
        factorId,
        challengeId: challenge.id,
        code: code.trim(),
      })
      if (error) {
        return {
          error: mapAuthError({ message: error.message, code: error.code }),
        }
      }
      await refreshMfaStatus()
      return { error: null, needsMfa: false }
    },
    [refreshMfaStatus],
  )

  const unenrollMfa = useCallback(
    async (factorId: string): Promise<{ error: string | null }> => {
      if (!supabaseConfigured) {
        return { error: AUTH_UNAVAILABLE_MESSAGE }
      }
      const { error } = await supabase.auth.mfa.unenroll({ factorId })
      if (error) {
        return {
          error: mapAuthError({ message: error.message, code: error.code }),
        }
      }
      await refreshMfaStatus()
      return { error: null }
    },
    [refreshMfaStatus],
  )

  const signOut = useCallback(
    async (options?: { scope?: SignOutScope }) => {
      if (!supabaseConfigured) return
      markPasswordRecovery(setIsPasswordRecovery, false)
      setRequiresMfa(false)
      // Default local so signing out of the portal does not kill the desktop app.
      await supabase.auth.signOut({ scope: options?.scope ?? 'local' })
    },
    [],
  )

  const deleteAccount = useCallback(
    async (confirmEmail: string): Promise<{ error: string | null }> => {
      if (!supabaseConfigured) {
        return { error: AUTH_UNAVAILABLE_MESSAGE }
      }
      if (isPasswordRecovery) {
        return {
          error: 'Finish resetting your password before deleting the account.',
        }
      }
      const {
        data: { session },
      } = await supabase.auth.getSession()
      if (!session?.access_token) {
        return { error: 'You must be signed in to delete your account.' }
      }

      const { data, error } = await supabase.functions.invoke('delete-account', {
        body: { confirmEmail },
      })

      if (error) {
        const message =
          typeof data === 'object' &&
          data &&
          'error' in data &&
          typeof (data as { error: unknown }).error === 'string'
            ? (data as { error: string }).error
            : error.message
        return { error: message || 'Could not delete account.' }
      }

      if (
        data &&
        typeof data === 'object' &&
        'error' in data &&
        typeof (data as { error: unknown }).error === 'string'
      ) {
        return { error: (data as { error: string }).error }
      }

      await supabase.auth.signOut({ scope: 'global' })
      return { error: null }
    },
    [isPasswordRecovery],
  )

  const value = useMemo<AuthContextValue>(
    () => ({
      // Recovery JWT must not look like a signed-in account anywhere in the UI.
      session: isPasswordRecovery ? null : session,
      user: isPasswordRecovery ? null : (session?.user ?? null),
      loading,
      configured: supabaseConfigured,
      requiresMfa: isPasswordRecovery ? false : requiresMfa,
      signIn,
      signInWithPasskey,
      signInWithOAuth,
      signUp,
      verifySignupOtp,
      requestPasswordReset,
      isPasswordRecovery,
      updatePassword,
      registerPasskey,
      listPasskeys,
      deletePasskey,
      refreshMfaStatus,
      listMfaFactors,
      enrollMfaTotp,
      challengeAndVerifyMfa,
      unenrollMfa,
      signOut,
      deleteAccount,
    }),
    [
      session,
      loading,
      requiresMfa,
      isPasswordRecovery,
      signIn,
      signInWithPasskey,
      signInWithOAuth,
      signUp,
      verifySignupOtp,
      requestPasswordReset,
      updatePassword,
      registerPasskey,
      listPasskeys,
      deletePasskey,
      refreshMfaStatus,
      listMfaFactors,
      enrollMfaTotp,
      challengeAndVerifyMfa,
      unenrollMfa,
      signOut,
      deleteAccount,
    ],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
