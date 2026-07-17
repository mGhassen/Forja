import { useCallback, useState, type FormEvent } from 'react'
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

function ForgotPasswordForm() {
  const navigate = useNavigate()
  const { requestPasswordReset, configured } = useAuth()
  const [email, setEmail] = useState('')
  const [captchaToken, setCaptchaToken] = useState<string | null>(null)
  const [captchaKey, setCaptchaKey] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  const onCaptchaToken = useCallback((token: string | null) => {
    setCaptchaToken(token)
  }, [])

  function resetCaptcha() {
    setCaptchaToken(null)
    setCaptchaKey((k) => k + 1)
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)

    if (captchaConfigured && !captchaToken) {
      setError(CAPTCHA_REQUIRED_MESSAGE)
      return
    }

    setSubmitting(true)
    const trimmed = email.trim()
    const { error: resetError } = await requestPasswordReset(trimmed, {
      captchaToken: captchaToken ?? undefined,
    })
    setSubmitting(false)

    if (resetError) {
      setError(resetError)
      resetCaptcha()
      return
    }

    void navigate({
      to: '/reset-password',
      search: { email: trimmed },
    })
  }

  return (
    <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
      <Reveal variant="right" className="w-full max-w-md">
        <LiquidGlass className="shadow-[0_32px_80px_-32px_rgba(0,0,0,0.85)]">
          <Card className="border-0 bg-transparent shadow-none">
          <CardHeader className="space-y-2 pb-2">
            <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-[rgba(237,230,218,0.4)]">
              Account recovery
            </p>
            <CardTitle className="font-disp text-3xl font-extrabold uppercase tracking-tight">
              Forgot password
            </CardTitle>
            <CardDescription className="text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
              Enter your email. We&apos;ll send a one-time code — then you choose
              a new password. Sign-in stays email + password (no magic links).
            </CardDescription>
          </CardHeader>

          <CardContent>
            <form onSubmit={onSubmit} className="space-y-5">
              {!configured ? (
                <p className="text-sm leading-relaxed text-[rgba(237,230,218,0.55)]">
                  Password reset is not open yet. Download Forja - you can watch
                  without an account.
                </p>
              ) : null}

              <div className="space-y-2">
                <Label htmlFor="forgot-email">Email</Label>
                <Input
                  id="forgot-email"
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
                    ? 'Password reset is not available right now. Download Forja and play without an account.'
                    : error}
                </p>
              ) : null}

              {configured ? (
                <Button
                  type="submit"
                  disabled={
                    submitting || (captchaConfigured && !captchaToken)
                  }
                  className="h-12 w-full rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                >
                  {submitting ? 'Sending code…' : 'Send reset code'}
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
                Already have a code?{' '}
                <Link
                  to="/reset-password"
                  className="text-forja-green hover:text-flame hover:underline"
                >
                  Enter it here
                </Link>
              </p>
              <p className="text-center text-sm text-[rgba(237,230,218,0.45)]">
                Remembered it?{' '}
                <Link
                  to="/login"
                  className="text-forja-green hover:text-flame hover:underline"
                >
                  Sign in
                </Link>
              </p>
            </div>
          </CardContent>
        </Card>
        </LiquidGlass>
      </Reveal>
    </section>
  )
}

export function ForgotPasswordPage() {
  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="auth" />
      <div className="relative z-10">
      <SiteHeader />

      <main className="relative grid min-h-screen lg:grid-cols-[1.05fr_0.95fr]">
        <AuthStoryPanel emphasis="Reset your password to get back to synced settings." />
        <ForgotPasswordForm />
      </main>
      </div>
    </div>
  )
}
