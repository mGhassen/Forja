import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react'
import { checkRequiresMfa } from '../mfa'
import { mapAuthError } from '../errors'
import { startOAuthSignIn } from '../oauth'
import type { OAuthProviderId } from '../config'
import type {
  AuthResult,
  ForjaAuthContextValue,
  ForjaAuthProviderProps,
  ForjaMfaFactor,
  ForjaPasskey,
  SignOutScope,
} from './types'

export const CAPTCHA_REQUIRED_MESSAGE =
  'Complete the captcha check, then try again.'

const PASSWORD_RECOVERY_STORAGE_KEY = 'forja.password_recovery'

const AuthContext = createContext<ForjaAuthContextValue | null>(null)

function urlIndicatesPasswordRecovery(): boolean {
  if (typeof window === 'undefined') return false
  const hash = new URLSearchParams(window.location.hash.replace(/^#/, ''))
  if (hash.get('type') === 'recovery') return true
  const query = new URLSearchParams(window.location.search)
  if (query.get('type') === 'recovery') return true
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
    // ignore
  }
}

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

/**
 * Full Forja Auth provider — shared by portal + admin.
 * Host apps inject Supabase client + optional recovery / refresh pause hooks.
 */
export function ForjaAuthProvider({ host, children }: ForjaAuthProviderProps) {
  const {
    client,
    configured,
    unavailableMessage,
    features = {},
    passwordRecovery: recoveryHost,
    pauseSessionRefresh,
  } = host

  const passkeysEnabled = features.passkeys !== false
  const signupEnabled = features.signup !== false
  const deleteEnabled = features.deleteAccount !== false
  const recoveryEnabled = features.passwordRecovery !== false
  const visibilityRefresh = features.visibilityRefresh !== false

  const [sessionState, setSessionState] = useState<
    ForjaAuthContextValue['session']
  >(null)
  const [loading, setLoading] = useState(true)
  const [requiresMfa, setRequiresMfa] = useState(false)
  const [isPasswordRecovery, setIsPasswordRecovery] = useState(() => {
    if (!recoveryEnabled) return false
    if (urlIndicatesPasswordRecovery()) {
      persistPasswordRecovery(true)
      recoveryHost?.setLock(true)
      return true
    }
    const stored = readStoredPasswordRecovery()
    if (stored) recoveryHost?.setLock(true)
    return stored
  })

  const markRecovery = useCallback(
    (active: boolean) => {
      if (!recoveryEnabled) return
      persistPasswordRecovery(active)
      recoveryHost?.setLock(active)
      setIsPasswordRecovery(active)
    },
    [recoveryEnabled, recoveryHost],
  )

  const refreshMfaStatus = useCallback(async (): Promise<boolean> => {
    if (!configured) {
      setRequiresMfa(false)
      return false
    }
    const needed = await checkRequiresMfa(client)
    setRequiresMfa(needed)
    return needed
  }, [client, configured])

  useEffect(() => {
    if (!configured) {
      setLoading(false)
      return
    }

    let mounted = true

    if (recoveryEnabled && urlIndicatesPasswordRecovery()) {
      markRecovery(true)
    }

    const { data: sub } = client.auth.onAuthStateChange((event, next) => {
      if (!mounted) return
      if (
        recoveryEnabled &&
        (event === 'PASSWORD_RECOVERY' || urlIndicatesPasswordRecovery())
      ) {
        markRecovery(true)
      }
      if (event === 'SIGNED_OUT') {
        markRecovery(false)
        setRequiresMfa(false)
      }
      setSessionState(next)
      setLoading(false)
      if (next && event !== 'PASSWORD_RECOVERY') {
        void checkRequiresMfa(client).then((needed) => {
          if (mounted) setRequiresMfa(needed)
        })
      } else if (!next) {
        setRequiresMfa(false)
      }
    })

    void client.auth.getSession().then(async ({ data }) => {
      if (!mounted) return
      setSessionState(data.session)
      setLoading(false)
      if (data.session) {
        setRequiresMfa(await checkRequiresMfa(client))
      }
    })

    if (pauseSessionRefresh?.shouldPause()) {
      pauseSessionRefresh.onDetectPause?.()
    }

    let lastRefresh = 0
    const refreshIfVisible = () => {
      if (!mounted || !visibilityRefresh) return
      if (recoveryHost?.isLockActive()) return
      if (pauseSessionRefresh?.shouldPause()) return
      if (document.visibilityState !== 'visible') return
      const now = Date.now()
      if (now - lastRefresh < 30_000) return
      lastRefresh = now
      void client.auth.refreshSession().then(({ data }) => {
        if (mounted && data.session) setSessionState(data.session)
      })
    }

    if (visibilityRefresh) {
      document.addEventListener('visibilitychange', refreshIfVisible)
      window.addEventListener('focus', refreshIfVisible)
      if (!pauseSessionRefresh?.shouldPause()) {
        refreshIfVisible()
      }
    }

    return () => {
      mounted = false
      sub.subscription.unsubscribe()
      if (visibilityRefresh) {
        document.removeEventListener('visibilitychange', refreshIfVisible)
        window.removeEventListener('focus', refreshIfVisible)
      }
    }
  }, [
    client,
    configured,
    recoveryEnabled,
    recoveryHost,
    pauseSessionRefresh,
    visibilityRefresh,
    markRecovery,
  ])

  const unavailable = useCallback(
    (): AuthResult => ({ error: unavailableMessage }),
    [unavailableMessage],
  )

  const featureOff = useCallback(
    (name: string): AuthResult => ({
      error: `${name} is not available here.`,
    }),
    [],
  )

  const signIn = useCallback(
    async (
      email: string,
      password: string,
      options?: { captchaToken?: string },
    ): Promise<AuthResult> => {
      if (!configured) return unavailable()
      const { error } = await client.auth.signInWithPassword({
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
    [client, configured, refreshMfaStatus, unavailable],
  )

  const signInWithPasskey = useCallback(
    async (options?: { captchaToken?: string }): Promise<AuthResult> => {
      if (!configured) return unavailable()
      if (!passkeysEnabled) return featureOff('Passkeys')
      const { error } = await client.auth.signInWithPasskey({
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
    [client, configured, passkeysEnabled, refreshMfaStatus, unavailable, featureOff],
  )

  const signInWithOAuth = useCallback(
    async (provider: OAuthProviderId): Promise<AuthResult> => {
      const { error } = await startOAuthSignIn(client, configured, provider, {
        unavailableMessage,
      })
      return { error }
    },
    [client, configured, unavailableMessage],
  )

  const signUp = useCallback(
    async (
      email: string,
      password: string,
      options?: { captchaToken?: string },
    ): Promise<AuthResult> => {
      if (!configured) return unavailable()
      if (!signupEnabled) return featureOff('Sign up')
      const { data, error } = await client.auth.signUp({
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
      return {
        error: null,
        needsEmailConfirmation: Boolean(data.user) && !data.session,
      }
    },
    [client, configured, signupEnabled, unavailable, featureOff],
  )

  const verifySignupOtp = useCallback(
    async (email: string, token: string): Promise<AuthResult> => {
      if (!configured) return unavailable()
      if (!signupEnabled) return featureOff('Sign up')
      const { error } = await client.auth.verifyOtp({
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
    [client, configured, signupEnabled, refreshMfaStatus, unavailable, featureOff],
  )

  const requestPasswordReset = useCallback(
    async (
      email: string,
      options?: { captchaToken?: string },
    ): Promise<AuthResult> => {
      if (!configured) return unavailable()
      if (!recoveryEnabled) return featureOff('Password reset')
      const redirectTo = `${window.location.origin}/reset-password`
      const { error } = await client.auth.resetPasswordForEmail(email, {
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
    [client, configured, recoveryEnabled, unavailable, featureOff],
  )

  const updatePassword = useCallback(
    async (password: string): Promise<AuthResult> => {
      if (!configured) return unavailable()
      if (!recoveryEnabled) return featureOff('Password reset')
      if (!isPasswordRecovery) {
        return {
          error:
            'Open the reset link from your email first. Request a new one if it expired.',
        }
      }
      const { error: updateError } = await client.auth.updateUser({ password })
      if (updateError) {
        return {
          error: mapAuthError({
            message: updateError.message,
            code: updateError.code,
          }),
        }
      }
      markRecovery(false)
      await client.auth.signOut({ scope: 'local' })
      return { error: null }
    },
    [
      client,
      configured,
      recoveryEnabled,
      isPasswordRecovery,
      markRecovery,
      unavailable,
      featureOff,
    ],
  )

  const registerPasskey = useCallback(async (): Promise<{
    error: string | null
    passkey: ForjaPasskey | null
  }> => {
    if (!configured) return { error: unavailableMessage, passkey: null }
    if (!passkeysEnabled) {
      return { error: 'Passkeys are not available here.', passkey: null }
    }
    if (isPasswordRecovery) {
      return {
        error: 'Finish resetting your password before managing passkeys.',
        passkey: null,
      }
    }
    const { data, error } = await client.auth.registerPasskey()
    if (error) return { error: error.message, passkey: null }
    if (!data) return { error: 'Could not register passkey.', passkey: null }
    return { error: null, passkey: mapPasskey(data) }
  }, [
    client,
    configured,
    passkeysEnabled,
    isPasswordRecovery,
    unavailableMessage,
  ])

  const listPasskeys = useCallback(async (): Promise<{
    error: string | null
    passkeys: ForjaPasskey[]
  }> => {
    if (!configured) return { error: unavailableMessage, passkeys: [] }
    if (!passkeysEnabled) return { error: null, passkeys: [] }
    if (isPasswordRecovery) {
      return {
        error: 'Finish resetting your password before managing passkeys.',
        passkeys: [],
      }
    }
    const { data, error } = await client.auth.passkey.list()
    if (error) return { error: error.message, passkeys: [] }
    return { error: null, passkeys: (data ?? []).map(mapPasskey) }
  }, [
    client,
    configured,
    passkeysEnabled,
    isPasswordRecovery,
    unavailableMessage,
  ])

  const deletePasskey = useCallback(
    async (passkeyId: string): Promise<{ error: string | null }> => {
      if (!configured) return { error: unavailableMessage }
      if (!passkeysEnabled) {
        return { error: 'Passkeys are not available here.' }
      }
      if (isPasswordRecovery) {
        return {
          error: 'Finish resetting your password before managing passkeys.',
        }
      }
      const { error } = await client.auth.passkey.delete({ passkeyId })
      return { error: error?.message ?? null }
    },
    [
      client,
      configured,
      passkeysEnabled,
      isPasswordRecovery,
      unavailableMessage,
    ],
  )

  const listMfaFactors = useCallback(async (): Promise<{
    error: string | null
    factors: ForjaMfaFactor[]
  }> => {
    if (!configured) return { error: unavailableMessage, factors: [] }
    const { data, error } = await client.auth.mfa.listFactors()
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
  }, [client, configured, unavailableMessage])

  const enrollMfaTotp = useCallback(async (): Promise<{
    error: string | null
    factorId: string | null
    qrCode: string | null
    secret: string | null
  }> => {
    if (!configured) {
      return {
        error: unavailableMessage,
        factorId: null,
        qrCode: null,
        secret: null,
      }
    }
    const { data, error } = await client.auth.mfa.enroll({
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
  }, [client, configured, unavailableMessage])

  const challengeAndVerifyMfa = useCallback(
    async (factorId: string, code: string): Promise<AuthResult> => {
      if (!configured) return unavailable()
      const { data: challenge, error: challengeError } =
        await client.auth.mfa.challenge({ factorId })
      if (challengeError || !challenge) {
        return {
          error: mapAuthError({
            message: challengeError?.message,
            code: challengeError?.code,
            fallback: 'Could not start verification.',
          }),
        }
      }
      const { error } = await client.auth.mfa.verify({
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
    [client, configured, refreshMfaStatus, unavailable],
  )

  const unenrollMfa = useCallback(
    async (factorId: string): Promise<{ error: string | null }> => {
      if (!configured) return { error: unavailableMessage }
      const { error } = await client.auth.mfa.unenroll({ factorId })
      if (error) {
        return {
          error: mapAuthError({ message: error.message, code: error.code }),
        }
      }
      await refreshMfaStatus()
      return { error: null }
    },
    [client, configured, refreshMfaStatus, unavailableMessage],
  )

  const signOut = useCallback(
    async (options?: { scope?: SignOutScope }) => {
      if (!configured) return
      markRecovery(false)
      setRequiresMfa(false)
      await client.auth.signOut({ scope: options?.scope ?? 'local' })
    },
    [client, configured, markRecovery],
  )

  const deleteAccount = useCallback(
    async (confirmEmail: string): Promise<{ error: string | null }> => {
      if (!configured) return { error: unavailableMessage }
      if (!deleteEnabled) {
        return { error: 'Account delete is not available here.' }
      }
      if (isPasswordRecovery) {
        return {
          error: 'Finish resetting your password before deleting the account.',
        }
      }
      const {
        data: { session: current },
      } = await client.auth.getSession()
      if (!current?.access_token) {
        return { error: 'You must be signed in to delete your account.' }
      }

      const { data, error } = await client.functions.invoke('delete-account', {
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

      await client.auth.signOut({ scope: 'global' })
      return { error: null }
    },
    [
      client,
      configured,
      deleteEnabled,
      isPasswordRecovery,
      unavailableMessage,
    ],
  )

  const value = useMemo<ForjaAuthContextValue>(
    () => ({
      session: isPasswordRecovery ? null : sessionState,
      user: isPasswordRecovery ? null : (sessionState?.user ?? null),
      loading,
      configured,
      requiresMfa: isPasswordRecovery ? false : requiresMfa,
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
    }),
    [
      sessionState,
      loading,
      configured,
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

export function useAuth(): ForjaAuthContextValue {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within ForjaAuthProvider')
  return ctx
}
