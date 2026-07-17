import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { AuthStoryPanel } from '@/components/auth-story-panel'
import { Reveal } from '@/components/reveal'
import { SiteHeader } from '@/components/site-header'
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
} from '@/hooks/use-auth'

const MIN_PASSWORD_LENGTH = 6

function ResetPasswordForm() {
  const navigate = useNavigate()
  const {
    updatePassword,
    passwordRecovery,
    loading,
    configured,
    session,
  } = useAuth()
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  /** Give the recovery hash/code a moment to establish a session. */
  const [waited, setWaited] = useState(false)

  useEffect(() => {
    const t = window.setTimeout(() => setWaited(true), 1500)
    return () => window.clearTimeout(t)
  }, [])

  const canReset = passwordRecovery || Boolean(session)
  const stillResolving = !canReset && (!waited || loading)
  const showInvalid = !canReset && waited && !loading

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

    setSubmitting(true)
    const { error: updateError } = await updatePassword(password)
    setSubmitting(false)

    if (updateError) {
      setError(updateError)
      return
    }

    void navigate({ to: '/account/profiles' })
  }

  if (stillResolving) {
    return (
      <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
        <Reveal variant="right" className="w-full max-w-md">
          <Card className="border-[rgba(237,230,218,0.16)] bg-[#121110]/90 shadow-[0_32px_80px_-32px_rgba(0,0,0,0.85)]">
            <CardHeader className="space-y-2 pb-2">
              <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-[rgba(237,230,218,0.4)]">
                Password reset
              </p>
              <CardTitle className="font-disp text-3xl font-extrabold uppercase tracking-tight">
                Opening link…
              </CardTitle>
              <CardDescription className="text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
                Confirming your reset link. This only takes a moment.
              </CardDescription>
            </CardHeader>
          </Card>
        </Reveal>
      </section>
    )
  }

  if (showInvalid) {
    return (
      <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
        <Reveal variant="right" className="w-full max-w-md">
          <Card className="border-[rgba(237,230,218,0.16)] bg-[#121110]/90 shadow-[0_32px_80px_-32px_rgba(0,0,0,0.85)]">
            <CardHeader className="space-y-2 pb-2">
              <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-flame">
                Link expired
              </p>
              <CardTitle className="font-disp text-3xl font-extrabold uppercase tracking-tight">
                Invalid reset link
              </CardTitle>
              <CardDescription className="text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
                This password reset link is invalid or has expired. Request a
                new one to continue.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4 pt-2">
              <Link
                to="/forgot-password"
                data-hover=""
                className="btn-magnet inline-flex h-12 w-full items-center justify-center rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
              >
                Request a new link
              </Link>
              <Link
                to="/login"
                className="font-mono-ui flex items-center justify-center gap-2 text-[11px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.38)] transition-colors hover:text-[#EDE6DA]"
              >
                Back to sign in →
              </Link>
            </CardContent>
          </Card>
        </Reveal>
      </section>
    )
  }

  return (
    <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
      <Reveal variant="right" className="w-full max-w-md">
        <Card className="border-[rgba(237,230,218,0.16)] bg-[#121110]/90 shadow-[0_32px_80px_-32px_rgba(0,0,0,0.85)]">
          <CardHeader className="space-y-2 pb-2">
            <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-[rgba(237,230,218,0.4)]">
              Password reset
            </p>
            <CardTitle className="font-disp text-3xl font-extrabold uppercase tracking-tight">
              Choose a new password
            </CardTitle>
            <CardDescription className="text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
              Pick a new password for your Forja account. At least{' '}
              {MIN_PASSWORD_LENGTH} characters.
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
                <Label htmlFor="reset-password">New password</Label>
                <Input
                  id="reset-password"
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
                <Label htmlFor="reset-confirm">Confirm password</Label>
                <Input
                  id="reset-confirm"
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
                  disabled={submitting || loading}
                  className="h-12 w-full rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                >
                  {submitting ? 'Saving…' : 'Save new password'}
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

            <div className="mt-8 border-t border-[rgba(237,230,218,0.1)] pt-6">
              <p className="text-center text-sm text-[rgba(237,230,218,0.45)]">
                <Link
                  to="/login"
                  className="text-forja-green hover:text-flame hover:underline"
                >
                  Back to sign in
                </Link>
              </p>
            </div>
          </CardContent>
        </Card>
      </Reveal>
    </section>
  )
}

export function ResetPasswordPage() {
  return (
    <div className="film-grain relative min-h-screen bg-[#0B0A0A] text-[#EDE6DA]">
      <SiteHeader solid flush />

      <main className="relative grid min-h-screen lg:grid-cols-[1.05fr_0.95fr]">
        <AuthStoryPanel emphasis="Almost there — set a new password and you’re back in." />
        <ResetPasswordForm />
      </main>
    </div>
  )
}
