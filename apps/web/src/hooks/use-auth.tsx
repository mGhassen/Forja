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
  signUp: (
    email: string,
    password: string,
    options?: { captchaToken?: string },
  ) => Promise<AuthResult>
  signOut: () => Promise<void>
  deleteAccount: (confirmEmail: string) => Promise<{ error: string | null }>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!supabaseConfigured) {
      setLoading(false)
      return
    }

    let mounted = true
    void supabase.auth.getSession().then(({ data }) => {
      if (mounted) {
        setSession(data.session)
        setLoading(false)
      }
    })

    const { data: sub } = supabase.auth.onAuthStateChange((_event, next) => {
      setSession(next)
      setLoading(false)
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
          emailRedirectTo:
            typeof window !== 'undefined'
              ? `${window.location.origin}/account/profiles`
              : undefined,
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
      signUp,
      signOut,
      deleteAccount,
    }),
    [session, loading, signIn, signUp, signOut, deleteAccount],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
