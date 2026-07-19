import { useCallback } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { MfaChallengePanel, useAuth } from '@forja/auth/react'
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
import {
  isSafeDesktopCallback,
  resolveDesktopAuthParams,
} from '@/lib/desktop-auth-callback'

export function MfaVerifyPage() {
  const navigate = useNavigate()
  const { signOut } = useAuth()

  const onVerified = useCallback(() => {
    const desktop = resolveDesktopAuthParams()
    if (isSafeDesktopCallback(desktop.callback)) {
      void navigate({ to: '/login', replace: true })
      return
    }
    void navigate({ to: '/account/profiles', replace: true })
  }, [navigate])

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
              <MfaChallengePanel
                onVerified={onVerified}
                footer={
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
                }
                render={({
                  code,
                  setCode,
                  error,
                  submitting,
                  factorReady,
                  onSubmit,
                }) => (
                  <form onSubmit={onSubmit} className="space-y-5">
                    <div className="space-y-2">
                      <Label htmlFor="mfa-code">Authentication code</Label>
                      <Input
                        id="mfa-code"
                        inputMode="numeric"
                        autoComplete="one-time-code"
                        maxLength={6}
                        required
                        value={code}
                        onChange={(e) => setCode(e.target.value)}
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
                      disabled={submitting || code.length < 6 || !factorReady}
                      className="h-12 w-full rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]"
                    >
                      {submitting ? 'Verifying…' : 'Verify'}
                    </Button>
                  </form>
                )}
              />
            </CardContent>
          </Card>
        </LiquidGlass>
      </Reveal>
    </section>
  )
}
