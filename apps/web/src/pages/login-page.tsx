import { useCallback, useEffect, useLayoutEffect, useRef, useState, type FormEvent } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { Fingerprint, Loader2 } from 'lucide-react'
import { DesktopAuthDone } from '@/components/desktop-auth-done'
import { LiquidGlass } from '@/components/liquid-glass'
import { Reveal } from '@/components/reveal'
import { TurnstileCaptcha } from '@/components/turnstile-captcha'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { PasswordInput } from '@/components/ui/password-input'
import { OAuthProviders } from '@forja/auth/react'
import {
  useAuth,
  AUTH_UNAVAILABLE_MESSAGE,
  CAPTCHA_REQUIRED_MESSAGE,
} from '@/hooks/use-auth'
import { authConfig } from '@forja/auth'
import { captchaConfigured } from '@/lib/captcha'
import {
  completeDesktopHandoffKeepingPortal,
  consumeDesktopHandoffDone,
  getDesktopAuthUiDone,
  isSafeDesktopCallback,
  lockDesktopHandoff,
  mintAndHandoffToDesktop,
  rememberDesktopAuthParams,
  resolveDesktopAuthParams,
} from '@/lib/desktop-auth-callback'
import { supabase } from '@/lib/supabase'

function LoginForm() {
  const navigate = useNavigate()
  const {
    signIn,
    signInWithPasskey,
    session,
    user,
    loading,
    configured,
    isPasswordRecovery,
    requiresMfa,
  } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [captchaToken, setCaptchaToken] = useState<string | null>(null)
  const [captchaKey, setCaptchaKey] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [passkeySubmitting, setPasskeySubmitting] = useState(false)
  const [oauthBusy, setOauthBusy] = useState(false)
  // First paint must match SSR — no window/sessionStorage in useState.
  const [desktopReady, setDesktopReady] = useState(false)
  const [desktopHandoff, setDesktopHandoff] = useState(false)
  const [handoffBusy, setHandoffBusy] = useState(false)
  const autoHandoffTried = useRef(false)
  const [desktopParams, setDesktopParams] = useState<{
    callback: string | null
    state: string | null
  }>({ callback: null, state: null })
  const isDesktopLogin = isSafeDesktopCallback(desktopParams.callback)

  useLayoutEffect(() => {
    if (consumeDesktopHandoffDone() || getDesktopAuthUiDone()) {
      setDesktopHandoff(true)
      setDesktopReady(true)
      return
    }
    rememberDesktopAuthParams()
    const params = resolveDesktopAuthParams()
    setDesktopParams(params)
    if (isSafeDesktopCallback(params.callback)) {
      lockDesktopHandoff()
    }
    const err = new URLSearchParams(window.location.search).get('error')
    if (err) setError(err)
    setDesktopReady(true)
  }, [])

  const onCaptchaToken = useCallback((token: string | null) => {
    setCaptchaToken(token)
  }, [])

  function resetCaptcha() {
    setCaptchaToken(null)
    setCaptchaKey((k) => k + 1)
  }

  const handoffToDesktop = useCallback(async () => {
    const params = resolveDesktopAuthParams()
    setDesktopParams(params)
    if (!params.callback || !isSafeDesktopCallback(params.callback)) {
      setError(
        'This desktop login link is invalid. Open Web login from Forja again.',
      )
      return false
    }
    setHandoffBusy(true)
    setError(null)
    const result = await mintAndHandoffToDesktop({
      callback: params.callback,
      state: params.state,
    })
    setHandoffBusy(false)
    if (result.status === 'mint_failed') {
      setError(
        result.body?.trim() ||
          'Could not create a desktop session. Try Return to Forja again.',
      )
      return false
    }
    if (result.status === 'unreachable') {
      setError(
        'Could not reach the Forja app. Keep this tab open, make sure Forja is still waiting on Web login, then tap Return to Forja. If Chrome asks to allow local network access, allow it.',
      )
      return false
    }
    if (result.status === 'rejected') {
      setError(
        result.body?.trim() ||
          'Forja received the sign-in but could not apply the session. Keep this tab open and tap Return to Forja, or start Web login again from the app.',
      )
      return false
    }
    // Session B is on the app; portal keeps session A.
    completeDesktopHandoffKeepingPortal()
    setDesktopHandoff(true)
    return true
  }, [])

  useEffect(() => {
    if (!desktopReady || desktopHandoff) return
    if (loading) return
    if (!user) return
    if (isPasswordRecovery) {
      void navigate({ to: '/reset-password', replace: true })
      return
    }
    if (authConfig.mfaTotp && requiresMfa) {
      void navigate({ to: '/login/mfa', replace: true })
      return
    }
    // Prefer live params so we never race-navigate to profiles before
    // desktop_callback hydrates from the URL.
    const desktopNow = isSafeDesktopCallback(
      resolveDesktopAuthParams().callback,
    )
    if (desktopNow && session?.access_token && session.refresh_token) {
      if (autoHandoffTried.current) return
      autoHandoffTried.current = true
      void handoffToDesktop()
      return
    }
    if (!desktopNow) {
      void navigate({ to: '/account/profiles' })
    }
  }, [
    desktopReady,
    desktopHandoff,
    loading,
    user,
    session,
    isPasswordRecovery,
    requiresMfa,
    handoffToDesktop,
    navigate,
  ])

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)

    if (captchaConfigured && !captchaToken) {
      setError(CAPTCHA_REQUIRED_MESSAGE)
      return
    }

    setSubmitting(true)
    const { error: signInError, needsMfa } = await signIn(
      email.trim(),
      password,
      { captchaToken: captchaToken ?? undefined },
    )
    if (signInError) {
      setSubmitting(false)
      setError(signInError)
      resetCaptcha()
      return
    }
    if (needsMfa) {
      setSubmitting(false)
      void navigate({ to: '/login/mfa', replace: true })
      return
    }

    if (isDesktopLogin) {
      const { data } = await supabase.auth.getSession()
      if (data.session?.access_token && data.session.refresh_token) {
        autoHandoffTried.current = true
        await handoffToDesktop()
        setSubmitting(false)
        return
      }
      setSubmitting(false)
      setError(
        'Signed in, but the desktop handoff failed. Tap Return to Forja, or try Web login again from the app.',
      )
      return
    }

    setSubmitting(false)
    void navigate({ to: '/account/profiles' })
  }

  async function onPasskeySignIn() {
    setError(null)

    if (captchaConfigured && !captchaToken) {
      setError(CAPTCHA_REQUIRED_MESSAGE)
      return
    }

    setPasskeySubmitting(true)
    const { error: passkeyError, needsMfa } = await signInWithPasskey({
      captchaToken: captchaToken ?? undefined,
    })
    if (passkeyError) {
      setPasskeySubmitting(false)
      setError(passkeyError)
      resetCaptcha()
      return
    }
    if (needsMfa) {
      setPasskeySubmitting(false)
      void navigate({ to: '/login/mfa', replace: true })
      return
    }

    if (isDesktopLogin) {
      const { data } = await supabase.auth.getSession()
      if (data.session?.access_token && data.session.refresh_token) {
        autoHandoffTried.current = true
        await handoffToDesktop()
        setPasskeySubmitting(false)
        return
      }
      setPasskeySubmitting(false)
      setError(
        'Signed in, but the desktop handoff failed. Tap Return to Forja, or try Web login again from the app.',
      )
      return
    }

    setPasskeySubmitting(false)
    void navigate({ to: '/account/profiles' })
  }

  async function onReturnToForja() {
    setError(null)
    const { data } = await supabase.auth.getSession()
    if (!data.session?.access_token || !data.session.refresh_token) {
      setError('No active session. Sign in again, then tap Return to Forja.')
      return
    }
    await handoffToDesktop()
  }

  const authBusy =
    submitting || passkeySubmitting || handoffBusy || oauthBusy

  // Desktop handoff: never show credentials while session is hydrating, or
  // when already signed in (auto-mint / Return to Forja only).
  const desktopPendingAuth = isDesktopLogin && loading
  const desktopSignedIn =
    isDesktopLogin &&
    !loading &&
    !!user &&
    !requiresMfa &&
    !desktopHandoff
  const showCredentialsForm =
    !isDesktopLogin || (!loading && !user && !desktopHandoff)

  if (desktopHandoff) {
    return <DesktopAuthDone />
  }

  // SSR + first client paint match (no window yet) — neutral, no credentials.
  if (!desktopReady) {
    return (
      <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
        <div className="flex items-center gap-3 text-sm text-[rgba(237,230,218,0.55)]">
          <Loader2
            className="size-5 animate-spin text-forja-green"
            aria-hidden
          />
          Loading…
        </div>
      </section>
    )
  }

  if (desktopPendingAuth || desktopSignedIn) {
    return (
      <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
        <Reveal variant="right" className="reveal-slow w-full max-w-md">
          <LiquidGlass className="shadow-[0_32px_80px_-32px_rgba(0,0,0,0.85)]">
            <Card className="border-0 bg-transparent shadow-none">
              <CardHeader className="space-y-2 pb-2">
                <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-[rgba(237,230,218,0.4)]">
                  Desktop handoff
                </p>
                <CardTitle className="font-disp text-3xl font-extrabold uppercase tracking-tight">
                  {desktopSignedIn ? 'Return to Forja' : 'Connecting…'}
                </CardTitle>
                <CardDescription className="text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
                  {desktopSignedIn
                    ? 'You are already signed in here. Forja gets its own session — this browser stays signed in.'
                    : 'Checking your portal session before finishing desktop login.'}
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-5">
                {error ? (
                  <p
                    role="alert"
                    className="rounded-lg border border-flame/35 bg-flame/10 px-3 py-2.5 text-sm text-[#EDE6DA]"
                  >
                    {error}
                  </p>
                ) : null}
                {!desktopSignedIn || handoffBusy ? (
                  <div className="flex items-center justify-center gap-3 py-4 text-sm text-[rgba(237,230,218,0.55)]">
                    <Loader2
                      className="size-5 animate-spin text-forja-green"
                      aria-hidden
                    />
                    {handoffBusy
                      ? 'Connecting to Forja…'
                      : 'Looking up your session…'}
                  </div>
                ) : null}
                {desktopSignedIn ? (
                  <Button
                    type="button"
                    disabled={handoffBusy}
                    onClick={() => void onReturnToForja()}
                    className="h-12 w-full rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                  >
                    {handoffBusy ? 'Connecting to Forja…' : 'Return to Forja'}
                  </Button>
                ) : null}
              </CardContent>
            </Card>
          </LiquidGlass>
        </Reveal>
      </section>
    )
  }

  return (
    <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
      <Reveal variant="right" className="reveal-slow w-full max-w-md">
        <LiquidGlass className="shadow-[0_32px_80px_-32px_rgba(0,0,0,0.85)]">
          <Card className="border-0 bg-transparent shadow-none">
          <CardHeader className="space-y-2 pb-2">
            <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-[rgba(237,230,218,0.4)]">
              {isDesktopLogin ? 'Desktop handoff' : 'Welcome back'}
            </p>
            <CardTitle className="font-disp text-3xl font-extrabold uppercase tracking-tight">
              {isDesktopLogin ? 'Sign in for Forja' : 'Log in'}
            </CardTitle>
            <CardDescription className="text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
              {isDesktopLogin
                ? 'After you sign in here, Forja on your desktop finishes automatically.'
                : 'Your player settings, synced. Download stays free - account is optional.'}
            </CardDescription>
          </CardHeader>

          <CardContent>
            {showCredentialsForm ? (
            <form onSubmit={onSubmit} className="space-y-5">
              {!configured ? (
                <p className="text-sm leading-relaxed text-[rgba(237,230,218,0.55)]">
                  Web sign-in is not open yet. Download Forja - you can watch
                  without an account.
                </p>
              ) : null}

              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  autoComplete="email"
                  required={configured}
                  disabled={!configured}
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  className="h-11 border-[rgba(237,230,218,0.16)] bg-forja-bg disabled:opacity-40"
                />
              </div>
              <div className="space-y-2">
                <div className="flex items-center justify-between gap-3">
                  <Label htmlFor="password">Password</Label>
                  {configured && !isDesktopLogin ? (
                    <Link
                      to="/forgot-password"
                      className="text-xs text-[rgba(237,230,218,0.45)] transition-colors hover:text-forja-green hover:underline"
                    >
                      Forgot password?
                    </Link>
                  ) : null}
                </div>
                <PasswordInput
                  id="password"
                  autoComplete="current-password"
                  required={configured}
                  disabled={!configured}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="h-11 border-[rgba(237,230,218,0.16)] bg-forja-bg disabled:opacity-40"
                />
              </div>

              {configured && captchaConfigured ? (
                <TurnstileCaptcha key={captchaKey} onToken={onCaptchaToken} />
              ) : null}

              {error ? (
                <p
                  role="alert"
                  className="rounded-lg border border-flame/35 bg-flame/10 px-3 py-2.5 text-sm text-[#EDE6DA]"
                >
                  {error === AUTH_UNAVAILABLE_MESSAGE
                    ? 'Sign-in is not available right now. Download Forja and play without an account.'
                    : error}
                </p>
              ) : null}

              {configured ? (
                <div className="flex items-stretch gap-2">
                  <Button
                    type="submit"
                    disabled={
                      authBusy ||
                      loading ||
                      (captchaConfigured && !captchaToken)
                    }
                    className="h-12 min-w-0 flex-1 rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                  >
                    {submitting
                      ? isDesktopLogin
                        ? 'Signing in for desktop…'
                        : 'Signing in…'
                      : isDesktopLogin
                        ? 'Sign in & return to app'
                        : 'Sign in'}
                  </Button>
                  <Button
                    type="button"
                    variant="outline"
                    title={
                      passkeySubmitting
                        ? 'Waiting for passkey…'
                        : 'Sign in with passkey'
                    }
                    aria-label={
                      passkeySubmitting
                        ? 'Waiting for passkey'
                        : 'Sign in with passkey'
                    }
                    disabled={
                      authBusy ||
                      loading ||
                      (captchaConfigured && !captchaToken)
                    }
                    onClick={() => void onPasskeySignIn()}
                    className="size-12 shrink-0 rounded-full border-[rgba(237,230,218,0.22)] p-0 text-[#EDE6DA] hover:border-forja-green/50 hover:bg-forja-green/10"
                  >
                    <Fingerprint className="size-5" aria-hidden />
                  </Button>
                </div>
              ) : (
                <Link
                  to="/download"
                  data-hover=""
                  className="btn-magnet inline-flex h-12 w-full items-center justify-center rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                >
                  Download Forja
                </Link>
              )}
            </form>
            ) : null}

            {configured && showCredentialsForm ? (
              <OAuthProviders>
                {({ providers, label, signIn: oauthSignIn }) => (
                  <div className="mt-6 space-y-3 border-t border-[rgba(237,230,218,0.1)] pt-6">
                    <p className="text-center font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.35)]">
                      Or continue with
                    </p>
                    <div className="flex flex-col gap-2">
                      {providers.map((provider) => (
                        <Button
                          key={provider}
                          type="button"
                          variant="outline"
                          disabled={authBusy || loading}
                          onClick={() => {
                            setError(null)
                            rememberDesktopAuthParams()
                            setOauthBusy(true)
                            void oauthSignIn(provider).then(({ error: oauthError }) => {
                              if (oauthError) {
                                setOauthBusy(false)
                                setError(oauthError)
                              }
                            })
                          }}
                          className="h-11 w-full rounded-full border-[rgba(237,230,218,0.22)] font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                        >
                          {oauthBusy ? 'Redirecting…' : label(provider)}
                        </Button>
                      ))}
                    </div>
                  </div>
                )}
              </OAuthProviders>
            ) : null}

            {showCredentialsForm ? (
            <div className="mt-8 space-y-4 border-t border-[rgba(237,230,218,0.1)] pt-6">
              <p className="text-center text-sm text-[rgba(237,230,218,0.45)]">
                No account yet?{' '}
                <Link
                  to="/signup"
                  className="text-forja-green hover:text-flame hover:underline"
                >
                  Create one
                </Link>
              </p>
            </div>
            ) : null}
          </CardContent>
        </Card>
        </LiquidGlass>
      </Reveal>
    </section>
  )
}

export function LoginPage() {
  return <LoginForm />
}
