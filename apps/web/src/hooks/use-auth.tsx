import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import type { Session, User } from '@supabase/supabase-js'
import { supabase, supabaseConfigured } from '@/lib/supabase'

/** Never expose env keys, paths, or backend names to end users. */
export const AUTH_UNAVAILABLE_MESSAGE =
  "Sign-in isn't available right now. Download Forja and play without an account."

export const CAPTCHA_REQUIRED_MESSAGE =
  'Complete the captcha check, then try again.'

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
}

type AuthContextValue = {
  session: Session | null
  user: User | null
  loading: boolean
  configured: boolean
  signIn: (
    email: string,
    password: string,
    options?: { captchaToken?: string },
  ) => Promise<AuthResult>
  signInWithPasskey: (options?: {
    captchaToken?: string
  }) => Promise<AuthResult>
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
  signOut: () => Promise<void>
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

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const [isPasswordRecovery, setIsPasswordRecovery] = useState(false)

  useEffect(() => {
    if (!supabaseConfigured) {
      setLoading(false)
      return
    }

    let mounted = true

    // Subscribe first so PASSWORD_RECOVERY from the email redirect is not missed.
    const { data: sub } = supabase.auth.onAuthStateChange((event, next) => {
      if (!mounted) return
      if (event === 'PASSWORD_RECOVERY') {
        setIsPasswordRecovery(true)
      }
      if (event === 'SIGNED_OUT') {
        setIsPasswordRecovery(false)
      }
      setSession(next)
      setLoading(false)
    })

    void supabase.auth.getSession().then(({ data }) => {
      if (mounted) {
        setSession(data.session)
        setLoading(false)
      }
    })

    return () => {
      mounted = false
      sub.subscription.unsubscribe()
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
      return { error: error?.message ?? null }
    },
    [],
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
      return { error: error?.message ?? null }
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
      if (error) return { error: error.message }
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
      return { error: error?.message ?? null }
    },
    [],
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
      return { error: error?.message ?? null }
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
      if (updateError) return { error: updateError.message }

      setIsPasswordRecovery(false)
      await supabase.auth.signOut()
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
    const { data, error } = await supabase.auth.registerPasskey()
    if (error) return { error: error.message, passkey: null }
    if (!data) return { error: 'Could not register passkey.', passkey: null }
    return { error: null, passkey: mapPasskey(data) }
  }, [])

  const listPasskeys = useCallback(async (): Promise<{
    error: string | null
    passkeys: ForjaPasskey[]
  }> => {
    if (!supabaseConfigured) {
      return { error: AUTH_UNAVAILABLE_MESSAGE, passkeys: [] }
    }
    const { data, error } = await supabase.auth.passkey.list()
    if (error) return { error: error.message, passkeys: [] }
    return {
      error: null,
      passkeys: (data ?? []).map(mapPasskey),
    }
  }, [])

  const deletePasskey = useCallback(
    async (passkeyId: string): Promise<{ error: string | null }> => {
      if (!supabaseConfigured) {
        return { error: AUTH_UNAVAILABLE_MESSAGE }
      }
      const { error } = await supabase.auth.passkey.delete({ passkeyId })
      return { error: error?.message ?? null }
    },
    [],
  )

  const signOut = useCallback(async () => {
    if (!supabaseConfigured) return
    await supabase.auth.signOut()
  }, [])

  const deleteAccount = useCallback(
    async (confirmEmail: string): Promise<{ error: string | null }> => {
      if (!supabaseConfigured) {
        return { error: AUTH_UNAVAILABLE_MESSAGE }
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

      await supabase.auth.signOut()
      return { error: null }
    },
    [],
  )

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      user: session?.user ?? null,
      loading,
      configured: supabaseConfigured,
      signIn,
      signInWithPasskey,
      signUp,
      verifySignupOtp,
      requestPasswordReset,
      isPasswordRecovery,
      updatePassword,
      registerPasskey,
      listPasskeys,
      deletePasskey,
      signOut,
      deleteAccount,
    }),
    [
      session,
      loading,
      isPasswordRecovery,
      signIn,
      signInWithPasskey,
      signUp,
      verifySignupOtp,
      requestPasswordReset,
      updatePassword,
      registerPasskey,
      listPasskeys,
      deletePasskey,
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
