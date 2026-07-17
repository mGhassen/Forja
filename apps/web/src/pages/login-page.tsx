import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { AuthStoryPanel } from '@/components/auth-story-panel'
import { LiquidGlass } from '@/components/liquid-glass'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { Reveal } from '@/components/reveal'
import { SiteHeader } from '@/components/site-header'
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
import {
  useAuth,
  AUTH_UNAVAILABLE_MESSAGE,
  CAPTCHA_REQUIRED_MESSAGE,
} from '@/hooks/use-auth'
import { captchaConfigured } from '@/lib/captcha'
import {
  handoffSessionToDesktop,
  isSafeDesktopCallback,
  readDesktopAuthSearchParams,
} from '@/lib/desktop-auth-callback'
import { supabase } from '@/lib/supabase'

function LoginForm() {
  const navigate = useNavigate()
  const { signIn, session, user, loading, configured } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [captchaToken, setCaptchaToken] = useState<string | null>(null)
  const [captchaKey, setCaptchaKey] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [desktopHandoff, setDesktopHandoff] = useState(false)
  const handoffStarted = useRef(false)

  const desktopParams = readDesktopAuthSearchParams()
  const isDesktopLogin = isSafeDesktopCallback(desktopParams.callback)

  const onCaptchaToken = useCallback((token: string | null) => {
    setCaptchaToken(token)
  }, [])

  function resetCaptcha() {
    setCaptchaToken(null)
    setCaptchaKey((k) => k + 1)
  }

  const handoffToDesktop = useCallback(
    async (accessToken: string, refreshToken: string) => {
      if (!desktopParams.callback) return false
      if (!isSafeDesktopCallback(desktopParams.callback)) {
        setError(
          'This desktop login link is invalid. Open Web login from Forja again.',
        )
        return false
      }
      if (handoffStarted.current) return true
      handoffStarted.current = true
      setDesktopHandoff(true)
      setError(null)
      const ok = await handoffSessionToDesktop({
        callback: desktopParams.callback,
        state: desktopParams.state,
        accessToken,
        refreshToken,
      })
      if (!ok) {
        handoffStarted.current = false
        setDesktopHandoff(false)
        setError(
          'Signed in, but the desktop handoff failed. Try Web login again from Forja.',
        )
        return false
      }
      return true
    },
    [desktopParams.callback, desktopParams.state],
  )

  useEffect(() => {
    if (loading || !user) return
    if (isDesktopLogin && session?.access_token && session.refresh_token) {
      void handoffToDesktop(session.access_token, session.refresh_token)
      return
    }
    if (!isDesktopLogin) {
      void navigate({ to: '/account/profiles' })
    }
  }, [
    loading,
    user,
    session,
    isDesktopLogin,
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
    const { error: signInError } = await signIn(email.trim(), password, {
      captchaToken: captchaToken ?? undefined,
    })
    if (signInError) {
      setSubmitting(false)
      setError(signInError)
      resetCaptcha()
      return
    }

    if (isDesktopLogin) {
      const { data } = await supabase.auth.getSession()
      const next = data.session
      if (next?.access_token && next.refresh_token) {
        const ok = await handoffToDesktop(
          next.access_token,
          next.refresh_token,
        )
        setSubmitting(false)
        if (!ok) resetCaptcha()
        return
      }
      setSubmitting(false)
      setError(
        'Signed in, but the desktop handoff failed. Try Web login again from Forja.',
      )
      return
    }

    setSubmitting(false)
    void navigate({ to: '/account/profiles' })
  }

  return (
    <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
      <Reveal variant="right" className="w-full max-w-md">
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
                ? 'After you sign in here, Forja on your desktop finishes automatically. You can close this tab.'
                : 'Your player settings, synced. Download stays free - account is optional.'}
            </CardDescription>
          </CardHeader>

          <CardContent>
            {desktopHandoff ? (
              <p className="text-sm leading-relaxed text-[rgba(237,230,218,0.7)]">
                Signed in — you can close this tab and return to Forja.
              </p>
            ) : (
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
                  <Input
                    id="password"
                    type="password"
                    autoComplete="current-password"
                    required={configured}
                    disabled={!configured}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="h-11 border-[rgba(237,230,218,0.16)] bg-forja-bg disabled:opacity-40"
                  />
                </div>

                {configured && captchaConfigured ? (
                  <div className="space-y-2">
                    <Label>Verification</Label>
                    <TurnstileCaptcha key={captchaKey} onToken={onCaptchaToken} />
                  </div>
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
                  <Button
                    type="submit"
                    disabled={
                      submitting ||
                      loading ||
                      (captchaConfigured && !captchaToken)
                    }
                    className="h-12 w-full rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                  >
                    {submitting
                      ? isDesktopLogin
                        ? 'Signing in for desktop…'
                        : 'Signing in…'
                      : isDesktopLogin
                        ? 'Sign in & return to app'
                        : 'Sign in'}
                  </Button>
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
            )}

            {!desktopHandoff ? (
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
                {!isDesktopLogin ? (
                  <Link
                    to="/download"
                    className="font-mono-ui flex items-center justify-center gap-2 text-[11px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.38)] transition-colors hover:text-[#EDE6DA]"
                  >
                    Or download and play without signing in →
                  </Link>
                ) : null}
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
  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="auth" />
      <div className="relative z-10">
      <SiteHeader />

      <main className="relative grid min-h-screen lg:grid-cols-[1.05fr_0.95fr]">
        <AuthStoryPanel
          emphasis={
            isSafeDesktopCallback(readDesktopAuthSearchParams().callback)
              ? 'Sign in here to unlock sync on your desktop Forja app.'
              : undefined
          }
        />
        <LoginForm />
      </main>
      </div>
    </div>
  )
}

