import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { authConfig } from '@forja/auth'
import { OAuthProviders } from '@forja/auth/react'
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

/** Ops login — shared @forja/auth (MFA + optional OAuth). */
export function LoginPage() {
  const navigate = useNavigate()
  const {
    signIn,
    session,
    user,
    loading,
    configured,
    requiresMfa,
  } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [captchaToken, setCaptchaToken] = useState<string | null>(null)
  const [captchaKey, setCaptchaKey] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [oauthBusy, setOauthBusy] = useState(false)

  const onCaptchaToken = useCallback((token: string | null) => {
    setCaptchaToken(token)
  }, [])

  useEffect(() => {
    const err = new URLSearchParams(window.location.search).get('error')
    if (err) setError(err)
  }, [])

  useEffect(() => {
    if (loading || !user) return
    if (authConfig.mfaTotp && requiresMfa) {
      void navigate({ to: '/login/mfa', replace: true })
      return
    }
    void navigate({ to: '/', replace: true })
  }, [loading, user, requiresMfa, navigate])

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
    if (result.needsMfa) {
      void navigate({ to: '/login/mfa', replace: true })
      return
    }
    void navigate({ to: '/', replace: true })
  }

  const busy = submitting || oauthBusy

  if (loading || (session && !requiresMfa)) {
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
            required
            disabled={!configured || busy}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>
        <div className="space-y-2">
          <Label htmlFor="password">Password</Label>
          <PasswordInput
            id="password"
            autoComplete="current-password"
            required
            disabled={!configured || busy}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </div>
        {configured && captchaConfigured ? (
          <TurnstileCaptcha key={captchaKey} onToken={onCaptchaToken} />
        ) : null}
        {error ? (
          <p role="alert" className="text-sm text-red-300">
            {error}
          </p>
        ) : null}
        <Button
          type="submit"
          className="w-full"
          disabled={
            busy || !configured || (captchaConfigured && !captchaToken)
          }
        >
          {submitting ? 'Signing in…' : 'Sign in'}
        </Button>
      </form>

      {configured ? (
        <OAuthProviders>
          {({ providers, label, signIn: oauthSignIn }) => (
            <div className="space-y-2 border-t border-forja-border pt-4">
              <p className="text-center font-mono-ui text-[10px] uppercase tracking-[0.16em] text-forja-muted">
                Or continue with
              </p>
              {providers.map((provider) => (
                <Button
                  key={provider}
                  type="button"
                  variant="outline"
                  className="w-full"
                  disabled={busy}
                  onClick={() => {
                    setError(null)
                    setOauthBusy(true)
                    void oauthSignIn(provider).then(({ error: oauthError }) => {
                      if (oauthError) {
                        setOauthBusy(false)
                        setError(oauthError)
                      }
                    })
                  }}
                >
                  {oauthBusy ? 'Redirecting…' : label(provider)}
                </Button>
              ))}
            </div>
          )}
        </OAuthProviders>
      ) : null}
    </div>
  )
}
