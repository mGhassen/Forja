import { useCallback } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { MfaChallengePanel, useAuth } from '@forja/auth/react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

export function MfaVerifyPage() {
  const navigate = useNavigate()
  const { signOut } = useAuth()

  const onVerified = useCallback(() => {
    void navigate({ to: '/', replace: true })
  }, [navigate])

  return (
    <div className="mx-auto max-w-sm space-y-6 py-10">
      <div>
        <h1 className="font-disp text-2xl font-bold tracking-tight">
          Enter code
        </h1>
        <p className="mt-1 text-sm text-forja-muted">
          Open your authenticator app and enter the 6-digit code.
        </p>
      </div>
      <MfaChallengePanel
        onVerified={onVerified}
        footer={
          <p className="text-center text-sm text-forja-muted">
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
          <form className="space-y-4" onSubmit={onSubmit}>
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
                className="tracking-[0.3em]"
                placeholder="000000"
              />
            </div>
            {error ? (
              <p role="alert" className="text-sm text-red-300">
                {error}
              </p>
            ) : null}
            <Button
              type="submit"
              className="w-full"
              disabled={submitting || code.length < 6 || !factorReady}
            >
              {submitting ? 'Verifying…' : 'Verify'}
            </Button>
          </form>
        )}
      />
    </div>
  )
}
