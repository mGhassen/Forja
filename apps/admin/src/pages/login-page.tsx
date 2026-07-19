import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { TurnstileCaptcha } from '@/components/turnstile-captcha'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { PasswordInput } from '@/components/ui/password-input'
import {
  useAuth,
  AUTH_UNAVAILABLE_MESSAGE,
  CAPTCHA_REQUIRED_MESSAGE,
} from '@/hooks/use-auth'
import { captchaConfigured } from '@/lib/captcha'

/** Ops login only — no desktop handoff / portal chrome. */
export function LoginPage() {
  const navigate = useNavigate()
  const { signIn, session, user, loading, configured } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [captchaToken, setCaptchaToken] = useState<string | null>(null)
  const [captchaKey, setCaptchaKey] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  const onCaptchaToken = useCallback((token: string | null) => {
    setCaptchaToken(token)
  }, [])

  useEffect(() => {
    if (!loading && user) {
      void navigate({ to: '/', replace: true })
    }
  }, [loading, user, navigate])

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!configured) {
      setError(AUTH_UNAVAILABLE_MESSAGE)
      return
    }
    if (captchaConfigured && !captchaToken) {
      setError(CAPTCHA_REQUIRED_MESSAGE)
      return
    }
    setSubmitting(true)
    const result = await signIn(email, password, {
      captchaToken: captchaToken ?? undefined,
    })
    setSubmitting(false)
    if (result.error) {
      setError(result.error)
      setCaptchaToken(null)
      setCaptchaKey((k) => k + 1)
      return
    }
    void navigate({ to: '/', replace: true })
  }

  if (loading || session) {
    return (
      <div className="py-16 text-center text-sm text-forja-muted">Loading…</div>
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-disp text-2xl font-bold tracking-tight">
          Forja Admin
        </h1>
        <p className="mt-1 text-sm text-forja-muted">
          Sign in with an <code className="font-mono-ui text-xs">is_admin</code>{' '}
          account.
        </p>
      </div>
      <form className="space-y-4" onSubmit={(e) => void onSubmit(e)}>
        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>
        <div className="space-y-2">
          <Label htmlFor="password">Password</Label>
          <PasswordInput
            id="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>
        {configured && captchaConfigured ? (
          <TurnstileCaptcha key={captchaKey} onToken={onCaptchaToken} />
        ) : null}
        {error ? <p className="text-sm text-red-400">{error}</p> : null}
        <Button
          type="submit"
          className="w-full"
          disabled={
            submitting || (captchaConfigured && !captchaToken && configured)
          }
        >
          {submitting ? 'Signing in…' : 'Sign in'}
        </Button>
      </form>
    </div>
  )
}
