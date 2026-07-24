import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Link, Navigate, useNavigate } from '@tanstack/react-router'
import { CheckCircle2, Loader2, Tv } from 'lucide-react'
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
  approveDeviceLink,
  normalizeDeviceUserCode,
} from '@/lib/device-link'
import { authConfig } from '@forja/auth'

type ConnectPageProps = {
  initialCode?: string
}

export function ConnectPage({ initialCode = '' }: ConnectPageProps) {
  const navigate = useNavigate()
  const {
    user,
    loading,
    configured,
    isPasswordRecovery,
    requiresMfa,
  } = useAuth()
  const [code, setCode] = useState(() =>
    normalizeDeviceUserCode(initialCode),
  )
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [done, setDone] = useState(false)

  useEffect(() => {
    const next = normalizeDeviceUserCode(initialCode)
    if (next) setCode(next)
  }, [initialCode])

  const loginSearch = useCallback(() => {
    const params = new URLSearchParams()
    params.set('next', '/connect')
    const normalized = normalizeDeviceUserCode(code || initialCode)
    if (normalized) params.set('code', normalized)
    return Object.fromEntries(params.entries()) as {
      next: string
      code?: string
    }
  }, [code, initialCode])

  if (loading) {
    return (
      <div className="flex min-h-full items-center justify-center text-forja-muted">
        Loading…
      </div>
    )
  }

  if (!configured) {
    return (
      <div className="flex min-h-full items-center justify-center p-6 text-forja-muted">
        Sign-in is unavailable right now.
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/login" search={loginSearch()} replace />
  }

  if (isPasswordRecovery) {
    return <Navigate to="/reset-password" replace />
  }

  if (authConfig.mfaTotp && requiresMfa) {
    return <Navigate to="/login/mfa" replace />
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setSubmitting(true)
    const result = await approveDeviceLink(code)
    setSubmitting(false)
    if (!result.ok) {
      setError(result.error)
      return
    }
    setDone(true)
  }

  return (
    <div className="flex min-h-full items-center justify-center p-6 sm:p-10">
      <Reveal className="w-full max-w-md">
        <LiquidGlass className="rounded-2xl">
          <Card className="border-0 bg-transparent shadow-none">
            <CardHeader className="space-y-2">
              <div className="flex items-center gap-2 text-forja-accent">
                <Tv className="size-5" aria-hidden />
                <span className="text-sm font-medium tracking-wide">
                  Android TV
                </span>
              </div>
              <CardTitle className="text-2xl">Link your TV</CardTitle>
              <CardDescription>
                Enter the code shown on Forja for Android TV. Your TV will sign
                in automatically.
              </CardDescription>
            </CardHeader>
            <CardContent>
              {done ? (
                <div className="space-y-4">
                  <div className="flex items-start gap-3 rounded-xl border border-emerald-500/30 bg-emerald-500/10 p-4 text-sm text-[#EDE6DA]">
                    <CheckCircle2
                      className="mt-0.5 size-5 shrink-0 text-emerald-400"
                      aria-hidden
                    />
                    <div>
                      <p className="font-medium">TV signed in</p>
                      <p className="mt-1 text-forja-muted">
                        Return to your TV — it should continue in a moment.
                      </p>
                    </div>
                  </div>
                  <Button
                    type="button"
                    variant="secondary"
                    className="w-full"
                    onClick={() => void navigate({ to: '/account/profiles' })}
                  >
                    Go to account
                  </Button>
                </div>
              ) : (
                <form className="space-y-4" onSubmit={(e) => void onSubmit(e)}>
                  <div className="space-y-2">
                    <Label htmlFor="tv-code">TV code</Label>
                    <Input
                      id="tv-code"
                      name="code"
                      autoComplete="one-time-code"
                      autoCapitalize="characters"
                      spellCheck={false}
                      inputMode="text"
                      placeholder="ABCD2345"
                      value={code}
                      onChange={(e) =>
                        setCode(normalizeDeviceUserCode(e.target.value))
                      }
                      className="font-mono text-lg tracking-[0.2em]"
                      maxLength={12}
                      required
                    />
                  </div>
                  {error ? (
                    <p className="text-sm text-red-400" role="alert">
                      {error}
                    </p>
                  ) : null}
                  <Button
                    type="submit"
                    className="w-full"
                    disabled={submitting || code.length < 6}
                  >
                    {submitting ? (
                      <>
                        <Loader2 className="size-4 animate-spin" />
                        Linking…
                      </>
                    ) : (
                      'Confirm on this TV'
                    )}
                  </Button>
                  <p className="text-center text-xs text-forja-muted">
                    Wrong account?{' '}
                    <Link
                      to="/account/settings/connections"
                      className="underline underline-offset-2"
                    >
                      Manage sessions
                    </Link>
                  </p>
                </form>
              )}
            </CardContent>
          </Card>
        </LiquidGlass>
      </Reveal>
    </div>
  )
}
