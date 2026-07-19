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
} from '@forja/auth'
import { supabase, supabaseConfigured } from '@/lib/supabase'

export type { OAuthProviderId }
export type SignOutScope = 'local' | 'global'

export const AUTH_UNAVAILABLE_MESSAGE =
  "Sign-in isn't available right now. Check VITE_SUPABASE_* in apps/admin/.env."

export const CAPTCHA_REQUIRED_MESSAGE =
  'Complete the captcha check, then try again.'

type AuthResult = {
  error: string | null
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
  requiresMfa: boolean
  isPasswordRecovery: boolean
  signIn: (
    email: string,
    password: string,
    options?: { captchaToken?: string },
  ) => Promise<AuthResult>
  signInWithOAuth: (provider: OAuthProviderId) => Promise<AuthResult>
  refreshMfaStatus: () => Promise<boolean>
  listMfaFactors: () => Promise<{
    error: string | null
    factors: ForjaMfaFactor[]
  }>
  challengeAndVerifyMfa: (
    factorId: string,
    code: string,
  ) => Promise<AuthResult>
  signOut: (options?: { scope?: SignOutScope }) => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const [requiresMfa, setRequiresMfa] = useState(false)

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
    const { data: sub } = supabase.auth.onAuthStateChange((event, next) => {
      if (!mounted) return
      if (event === 'SIGNED_OUT') setRequiresMfa(false)
      setSession(next)
      setLoading(false)
      if (next) {
        void checkRequiresMfa(supabase).then((needed) => {
          if (mounted) setRequiresMfa(needed)
        })
      } else {
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

  const signInWithOAuth = useCallback(
    async (provider: OAuthProviderId): Promise<AuthResult> => {
      const { error } = await startOAuthSignIn(
        supabase,
        supabaseConfigured,
        provider,
        { unavailableMessage: AUTH_UNAVAILABLE_MESSAGE },
      )
      return { error }
    },
    [],
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
    return {
      error: null,
      factors: (data?.totp ?? []).map((f) => ({
        id: f.id,
        friendlyName: f.friendly_name ?? null,
        status: f.status,
      })),
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

  const signOut = useCallback(
    async (options?: { scope?: SignOutScope }) => {
      if (!supabaseConfigured) return
      setRequiresMfa(false)
      await supabase.auth.signOut({ scope: options?.scope ?? 'local' })
    },
    [],
  )

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      user: session?.user ?? null,
      loading,
      configured: supabaseConfigured,
      requiresMfa,
      isPasswordRecovery: false,
      signIn,
      signInWithOAuth,
      refreshMfaStatus,
      listMfaFactors,
      challengeAndVerifyMfa,
      signOut,
    }),
    [
      session,
      loading,
      requiresMfa,
      signIn,
      signInWithOAuth,
      refreshMfaStatus,
      listMfaFactors,
      challengeAndVerifyMfa,
      signOut,
    ],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
