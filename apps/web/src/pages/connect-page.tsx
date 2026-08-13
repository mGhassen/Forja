import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react'
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
import { closeDesktopHandoffWindow } from '@/lib/desktop-auth-callback'
import {
  approveDeviceLink,
  normalizeDeviceUserCode,
} from '@/lib/device-link'
import { authConfig } from '@forja/auth'

const AUTO_LINK_SECONDS = 5
const CLOSE_TAB_SECONDS = 5

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
  const [autoSecondsLeft, setAutoSecondsLeft] = useState<number | null>(null)
  const [closeSecondsLeft, setCloseSecondsLeft] = useState(CLOSE_TAB_SECONDS)
  const [closeBlocked, setCloseBlocked] = useState(false)
  const [autoCancelled, setAutoCancelled] = useState(false)
  const submitStarted = useRef(false)

  const fromDeepLink = normalizeDeviceUserCode(initialCode).length >= 6
  const sessionReady =
    !loading &&
    configured &&
    !!user &&
    !isPasswordRecovery &&
    !(authConfig.mfaTotp && requiresMfa)

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

  const submitCode = useCallback(async (raw: string) => {
    if (submitStarted.current) return
    submitStarted.current = true
    setAutoSecondsLeft(null)
    setError(null)
    setSubmitting(true)
    const result = await approveDeviceLink(raw)
    setSubmitting(false)
    if (!result.ok) {
      submitStarted.current = false
      setError(result.error)
      return
    }
    setDone(true)
  }, [])

  // Deep link / QR: show 5s countdown, then approve.
  useEffect(() => {
    if (!sessionReady || !fromDeepLink || done || submitting || autoCancelled) {
      return
    }
    if (autoSecondsLeft !== null) return
    setAutoSecondsLeft(AUTO_LINK_SECONDS)
  }, [
    sessionReady,
    fromDeepLink,
    done,
    submitting,
    autoCancelled,
    autoSecondsLeft,
  ])

  useEffect(() => {
    if (autoSecondsLeft === null || done || submitting || autoCancelled) return
    if (autoSecondsLeft <= 0) {
      void submitCode(normalizeDeviceUserCode(initialCode || code))
      return
    }
    const id = window.setTimeout(() => {
      setAutoSecondsLeft((s) => (s === null ? null : s - 1))
    }, 1000)
    return () => window.clearTimeout(id)
  }, [
    autoSecondsLeft,
    done,
    submitting,
    autoCancelled,
    initialCode,
    code,
    submitCode,
  ])

  // Success: 5s then best-effort close tab.
  useEffect(() => {
    if (!done) return
    if (closeSecondsLeft <= 0) {
      closeDesktopHandoffWindow()
      const id = window.setTimeout(() => {
        if (!window.closed) setCloseBlocked(true)
      }, 50)
      return () => window.clearTimeout(id)
    }
    const id = window.setTimeout(() => {
      setCloseSecondsLeft((s) => s - 1)
    }, 1000)
    return () => window.clearTimeout(id)
  }, [done, closeSecondsLeft])

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
    setAutoCancelled(true)
    setAutoSecondsLeft(null)
    await submitCode(code)
  }

  function onCancelAuto() {
    setAutoCancelled(true)
    setAutoSecondsLeft(null)
  }

  function onCloseNow() {
    closeDesktopHandoffWindow()
    window.setTimeout(() => {
      if (!window.closed) setCloseBlocked(true)
    }, 50)
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
                  Device link
                </span>
              </div>
              <CardTitle className="text-2xl">Link your device</CardTitle>
              <CardDescription>
                Enter the code shown on Forja. Your app will sign in
                automatically.
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
                      <p className="font-medium">Device signed in</p>
                      <p className="mt-1 text-forja-muted">
                        Return to Forja — it should continue in a moment.
                      </p>
                    </div>
                  </div>
                  {closeBlocked ? (
                    <p className="text-center text-sm text-forja-muted">
                      This tab could not close automatically. Close it and
                      return to Forja.
                    </p>
                  ) : (
                    <p className="text-center font-mono text-xs uppercase tracking-[0.16em] text-forja-muted">
                      Closing in{' '}
                      <span className="tabular-nums text-[#EDE6DA]">
                        {closeSecondsLeft}
                      </span>
                      s
                    </p>
                  )}
                  <div className="flex flex-col gap-2 sm:flex-row">
                    <Button
                      type="button"
                      className="w-full"
                      onClick={onCloseNow}
                    >
                      Close tab
                    </Button>
                    <Button
                      type="button"
                      variant="secondary"
                      className="w-full"
                      onClick={() => void navigate({ to: '/account/profiles' })}
                    >
                      Go to account
                    </Button>
                  </div>
                </div>
              ) : (
                <form className="space-y-4" onSubmit={(e) => void onSubmit(e)}>
                  <div className="space-y-2">
                    <Label htmlFor="tv-code">Device code</Label>
                    <Input
                      id="tv-code"
                      name="code"
                      autoComplete="one-time-code"
                      autoCapitalize="characters"
                      spellCheck={false}
                      inputMode="text"
                      placeholder="ABCD2345"
                      value={code}
                      onChange={(e) => {
                        setAutoCancelled(true)
                        setAutoSecondsLeft(null)
                        setCode(normalizeDeviceUserCode(e.target.value))
                      }}
                      className="font-mono text-lg tracking-[0.2em]"
                      maxLength={12}
                      required
                      disabled={submitting}
                    />
                  </div>
                  {autoSecondsLeft !== null && !submitting ? (
                    <p className="text-center text-sm text-forja-muted">
                      Linking automatically in{' '}
                      <span className="tabular-nums font-medium text-[#EDE6DA]">
                        {autoSecondsLeft}
                      </span>
                      s
                      <button
                        type="button"
                        className="ml-2 underline underline-offset-2"
                        onClick={onCancelAuto}
                      >
                        Cancel
                      </button>
                    </p>
                  ) : null}
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
                    ) : autoSecondsLeft !== null ? (
                      'Link now'
                    ) : (
                      'Confirm link'
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
