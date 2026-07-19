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
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuth } from '@/hooks/use-auth'
import {
  isSafeDesktopCallback,
  resolveDesktopAuthParams,
} from '@/lib/desktop-auth-callback'

export function MfaVerifyPage() {
  const navigate = useNavigate()
  const {
    user,
    loading,
    requiresMfa,
    listMfaFactors,
    challengeAndVerifyMfa,
    signOut,
  } = useAuth()
  const [factorId, setFactorId] = useState<string | null>(null)
  const [code, setCode] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    if (loading) return
    if (!user) {
      void navigate({ to: '/login', replace: true })
      return
    }
    if (!requiresMfa) {
      const desktop = resolveDesktopAuthParams()
      if (isSafeDesktopCallback(desktop.callback)) {
        void navigate({ to: '/login', replace: true })
        return
      }
      void navigate({ to: '/account/profiles', replace: true })
    }
  }, [loading, user, requiresMfa, navigate])

  useEffect(() => {
    if (!user || !requiresMfa) return
    void listMfaFactors().then(({ error: listError, factors }) => {
      if (listError) {
        setError(listError)
        return
      }
      const verified = factors.find((f) => f.status === 'verified')
      setFactorId(verified?.id ?? factors[0]?.id ?? null)
    })
  }, [user, requiresMfa, listMfaFactors])

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (!factorId) {
      setError('No authenticator found on this account.')
      return
    }
    setSubmitting(true)
    setError(null)
    const { error: verifyError } = await challengeAndVerifyMfa(factorId, code)
    setSubmitting(false)
    if (verifyError) {
      setError(verifyError)
      return
    }
    const desktop = resolveDesktopAuthParams()
    if (isSafeDesktopCallback(desktop.callback)) {
      void navigate({ to: '/login', replace: true })
      return
    }
    void navigate({ to: '/account/profiles', replace: true })
  }

  return (
    <section className="flex flex-1 items-center justify-center px-5 py-14 sm:px-8 lg:px-10 lg:py-20">
      <Reveal variant="right" className="reveal-slow w-full max-w-md">
        <LiquidGlass className="shadow-[0_32px_80px_-32px_rgba(0,0,0,0.85)]">
          <Card className="border-0 bg-transparent shadow-none">
            <CardHeader className="space-y-2 pb-2">
              <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-[rgba(237,230,218,0.4)]">
                Two-factor
              </p>
              <CardTitle className="font-disp text-3xl font-extrabold uppercase tracking-tight">
                Enter code
              </CardTitle>
              <CardDescription className="text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
                Open your authenticator app and enter the 6-digit code for
                Forja.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <form onSubmit={(e) => void onSubmit(e)} className="space-y-5">
                <div className="space-y-2">
                  <Label htmlFor="mfa-code">Authentication code</Label>
                  <Input
                    id="mfa-code"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    pattern="[0-9]{6}"
                    maxLength={6}
                    required
                    value={code}
                    onChange={(e) =>
                      setCode(e.target.value.replace(/\D/g, '').slice(0, 6))
                    }
                    className="h-11 border-[rgba(237,230,218,0.16)] bg-forja-bg tracking-[0.3em]"
                    placeholder="000000"
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
                  disabled={submitting || code.length < 6 || !factorId}
                  className="h-12 w-full rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                >
                  {submitting ? 'Verifying…' : 'Verify'}
                </Button>
              </form>
              <p className="mt-6 text-center text-sm text-[rgba(237,230,218,0.45)]">
                <button
                  type="button"
                  className="text-forja-green hover:underline"
                  onClick={() => void signOut({ scope: 'local' })}
                >
                  Sign out
                </button>
                {' · '}
                <Link to="/login" className="hover:text-forja-green">
                  Back to login
                </Link>
              </p>
            </CardContent>
          </Card>
        </LiquidGlass>
      </Reveal>
    </section>
  )
}
