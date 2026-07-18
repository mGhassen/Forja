import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { LiquidGlass } from '@/components/liquid-glass'
import { Reveal } from '@/components/reveal'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { Label } from '@/components/ui/label'
import { PasswordInput } from '@/components/ui/password-input'
import {
  useAuth,
  AUTH_UNAVAILABLE_MESSAGE,
} from '@/hooks/use-auth'

const MIN_PASSWORD_LENGTH = 6

/** True while Supabase may still be exchanging the recovery link tokens. */
function urlLooksLikeRecoveryRedirect(): boolean {
  if (typeof window === 'undefined') return false
  const params = new URLSearchParams(window.location.search)
  if (params.has('code')) return true
  const hash = window.location.hash.replace(/^#/, '')
  if (!hash) return false
  const hashParams = new URLSearchParams(hash)
  return (
    hashParams.get('type') === 'recovery' || hashParams.has('access_token')
  )
}

function ResetPasswordForm() {
  const navigate = useNavigate()
  const {
    updatePassword,
    isPasswordRecovery,
    loading,
    configured,
  } = useAuth()
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [awaitingLink, setAwaitingLink] = useState(urlLooksLikeRecoveryRedirect)

  useEffect(() => {
    if (isPasswordRecovery) {
      setAwaitingLink(false)
      return
    }
    if (!awaitingLink) return
    const timeout = window.setTimeout(() => setAwaitingLink(false), 8000)
    return () => window.clearTimeout(timeout)
  }, [isPasswordRecovery, awaitingLink])

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
    const { error: resetError } = await updatePassword(password)
    setSubmitting(false)

    if (resetError) {
      setError(resetError)
      return
    }

    void navigate({ to: '/login' })
  }

  if (loading || awaitingLink) {
    return (
      <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
        <p className="text-sm text-[rgba(237,230,218,0.55)]">
          Checking reset link…
        </p>
      </section>
    )
  }

  if (configured && !isPasswordRecovery) {
    return (
      <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
        <Reveal variant="right" className="reveal-slow w-full max-w-md">
          <LiquidGlass className="shadow-[0_32px_80px_-32px_rgba(0,0,0,0.85)]">
            <Card className="border-0 bg-transparent shadow-none">
              <CardHeader className="space-y-2 pb-2">
                <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-[rgba(237,230,218,0.4)]">
                  Password reset
                </p>
                <CardTitle className="font-disp text-3xl font-extrabold uppercase tracking-tight">
                  Link expired
                </CardTitle>
                <CardDescription className="text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
                  Open the reset link from your email, or request a new one.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="mt-2 space-y-4">
                  <Link
                    to="/forgot-password"
                    data-hover=""
                    className="btn-magnet inline-flex h-12 w-full items-center justify-center rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                  >
                    Request reset link
                  </Link>
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
              Password reset
            </p>
            <CardTitle className="font-disp text-3xl font-extrabold uppercase tracking-tight">
              Choose a new password
            </CardTitle>
            <CardDescription className="text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
              Your account is on hold until you set a new password (at least{' '}
              {MIN_PASSWORD_LENGTH} characters). This is not a normal sign-in —
              after saving, you&apos;ll sign in with email + password.
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
                <PasswordInput
                  id="reset-password"
                  autoComplete="new-password"
                  required={configured}
                  disabled={!configured}
                  minLength={MIN_PASSWORD_LENGTH}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="h-11 border-[rgba(237,230,218,0.16)] bg-forja-bg disabled:opacity-40"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="reset-confirm">Confirm password</Label>
                <PasswordInput
                  id="reset-confirm"
                  autoComplete="new-password"
                  required={configured}
                  disabled={!configured}
                  minLength={MIN_PASSWORD_LENGTH}
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                  className="h-11 border-[rgba(237,230,218,0.16)] bg-forja-bg disabled:opacity-40"
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
                  disabled={submitting}
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
        </LiquidGlass>
      </Reveal>
    </section>
  )
}

export function ResetPasswordPage() {
  return <ResetPasswordForm />
}
