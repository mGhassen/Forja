import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { AuthStoryPanel } from '@/components/auth-story-panel'
import { LiquidGlass } from '@/components/liquid-glass'
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

const MIN_PASSWORD_LENGTH = 6

function SignupForm() {
  const navigate = useNavigate()
  const { signUp, verifySignupOtp, user, loading, configured } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [otp, setOtp] = useState('')
  const [captchaToken, setCaptchaToken] = useState<string | null>(null)
  const [captchaKey, setCaptchaKey] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [needsEmailConfirmation, setNeedsEmailConfirmation] = useState(false)

  const onCaptchaToken = useCallback((token: string | null) => {
    setCaptchaToken(token)
  }, [])

  function resetCaptcha() {
    setCaptchaToken(null)
    setCaptchaKey((k) => k + 1)
  }

  useEffect(() => {
    if (!loading && user) {
      void navigate({ to: '/account/profiles' })
    }
  }, [loading, user, navigate])

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)

    if (password.length < MIN_PASSWORD_LENGTH) {
      setError(`Password must be at least ${MIN_PASSWORD_LENGTH} characters.`)
      return
    }
    if (password !== confirm) {
      setError('Passwords do not match.')
      return
    }
    if (captchaConfigured && !captchaToken) {
      setError(CAPTCHA_REQUIRED_MESSAGE)
      return
    }

    setSubmitting(true)
    const { error: signUpError, needsEmailConfirmation: confirmEmail } =
      await signUp(email.trim(), password, {
        captchaToken: captchaToken ?? undefined,
      })
    setSubmitting(false)

    if (signUpError) {
      setError(signUpError)
      resetCaptcha()
      return
    }

    if (confirmEmail) {
      setNeedsEmailConfirmation(true)
      return
    }

    void navigate({ to: '/account/profiles' })
  }

  async function onConfirmOtp(e: FormEvent) {
    e.preventDefault()
    setError(null)

    if (!otp.trim()) {
      setError('Enter the code from your email.')
      return
    }

    setSubmitting(true)
    const { error: otpError } = await verifySignupOtp(email.trim(), otp)
    setSubmitting(false)

    if (otpError) {
      setError(otpError)
      return
    }

    void navigate({ to: '/account/profiles' })
  }

  if (needsEmailConfirmation) {
    return (
      <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
        <Reveal variant="right" className="w-full max-w-md">
          <LiquidGlass className="shadow-[0_32px_80px_-32px_rgba(0,0,0,0.85)]">
            <Card className="border-0 bg-transparent shadow-none">
            <CardHeader className="space-y-2 pb-2">
              <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-forja-green">
                Check your inbox
              </p>
              <CardTitle className="font-disp text-3xl font-extrabold uppercase tracking-tight">
                Confirm email
              </CardTitle>
              <CardDescription className="text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
                We sent a confirmation code to{' '}
                <span className="text-[#EDE6DA]">{email.trim()}</span>. Enter it
                below, then you can sign in with your password anytime.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <form onSubmit={onConfirmOtp} className="space-y-5">
                <div className="space-y-2">
                  <Label htmlFor="signup-otp">Confirmation code</Label>
                  <Input
                    id="signup-otp"
                    type="text"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    required
                    value={otp}
                    onChange={(e) => setOtp(e.target.value)}
                    placeholder="6-digit code"
                    className="h-11 border-[rgba(237,230,218,0.16)] bg-[#0B0A0A] font-mono-ui tracking-[0.2em]"
                  />
                </div>

                {error ? (
                  <p
                    role="alert"
                    className="rounded-lg border border-flame/35 bg-flame/10 px-3 py-2.5 text-sm text-[#EDE6DA]"
                  >
                    {error}
                  </p>
                ) : null}

                <Button
                  type="submit"
                  disabled={submitting || loading}
                  className="h-12 w-full rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                >
                  {submitting ? 'Confirming…' : 'Confirm email'}
                </Button>
              </form>

              <div className="mt-8 space-y-4 border-t border-[rgba(237,230,218,0.1)] pt-6">
                <Link
                  to="/login"
                  className="font-mono-ui flex items-center justify-center gap-2 text-[11px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.38)] transition-colors hover:text-[#EDE6DA]"
                >
                  Back to sign in →
                </Link>
              </div>
            </CardContent>
          </Card>
          </LiquidGlass>
        </Reveal>
      </section>
    )
  }

  return (
    <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
      <Reveal variant="right" className="w-full max-w-md">
        <LiquidGlass className="shadow-[0_32px_80px_-32px_rgba(0,0,0,0.85)]">
          <Card className="border-0 bg-transparent shadow-none">
          <CardHeader className="space-y-2 pb-2">
            <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-[rgba(237,230,218,0.4)]">
              New account
            </p>
            <CardTitle className="font-disp text-3xl font-extrabold uppercase tracking-tight">
              Sign up
            </CardTitle>
            <CardDescription className="text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
              Optional account for synced settings. Download stays free either
              way.
            </CardDescription>
          </CardHeader>

          <CardContent>
            <form onSubmit={onSubmit} className="space-y-5">
              {!configured ? (
                <p className="text-sm leading-relaxed text-[rgba(237,230,218,0.55)]">
                  Web sign-up is not open yet. Download Forja - you can watch
                  without an account.
                </p>
              ) : null}

              <div className="space-y-2">
                <Label htmlFor="signup-email">Email</Label>
                <Input
                  id="signup-email"
                  type="email"
                  autoComplete="email"
                  required={configured}
                  disabled={!configured}
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  className="h-11 border-[rgba(237,230,218,0.16)] bg-[#0B0A0A] disabled:opacity-40"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="signup-password">Password</Label>
                <Input
                  id="signup-password"
                  type="password"
                  autoComplete="new-password"
                  required={configured}
                  disabled={!configured}
                  minLength={MIN_PASSWORD_LENGTH}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="h-11 border-[rgba(237,230,218,0.16)] bg-[#0B0A0A] disabled:opacity-40"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="signup-confirm">Confirm password</Label>
                <Input
                  id="signup-confirm"
                  type="password"
                  autoComplete="new-password"
                  required={configured}
                  disabled={!configured}
                  minLength={MIN_PASSWORD_LENGTH}
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                  className="h-11 border-[rgba(237,230,218,0.16)] bg-[#0B0A0A] disabled:opacity-40"
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
                    ? 'Sign-up is not available right now. Download Forja and play without an account.'
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
                  {submitting ? 'Creating account…' : 'Create account'}
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

            <div className="mt-8 space-y-4 border-t border-[rgba(237,230,218,0.1)] pt-6">
              <p className="text-center text-sm text-[rgba(237,230,218,0.45)]">
                Already have an account?{' '}
                <Link
                  to="/login"
                  className="text-forja-green hover:text-flame hover:underline"
                >
                  Sign in
                </Link>
              </p>
              <Link
                to="/download"
                className="font-mono-ui flex items-center justify-center gap-2 text-[11px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.38)] transition-colors hover:text-[#EDE6DA]"
              >
                Or download and play without signing up →
              </Link>
            </div>
          </CardContent>
        </Card>
        </LiquidGlass>
      </Reveal>
    </section>
  )
}

export function SignupPage() {
  return (
    <div className="film-grain relative min-h-screen bg-[#0B0A0A] text-[#EDE6DA]">
      <SiteHeader />

      <main className="relative grid min-h-screen lg:grid-cols-[1.05fr_0.95fr]">
        <AuthStoryPanel
          emphasis="Create an account to sync settings across your screens."
        />
        <SignupForm />
      </main>
    </div>
  )
}
