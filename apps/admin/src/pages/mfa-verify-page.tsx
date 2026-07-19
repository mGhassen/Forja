import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuth } from '@/hooks/use-auth'

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
      void navigate({ to: '/', replace: true })
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
    void navigate({ to: '/', replace: true })
  }

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
      <form className="space-y-4" onSubmit={(e) => void onSubmit(e)}>
        <div className="space-y-2">
          <Label htmlFor="mfa-code">Authentication code</Label>
          <Input
            id="mfa-code"
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            required
            value={code}
            onChange={(e) =>
              setCode(e.target.value.replace(/\D/g, '').slice(0, 6))
            }
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
          disabled={submitting || code.length < 6 || !factorId}
        >
          {submitting ? 'Verifying…' : 'Verify'}
        </Button>
      </form>
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
    </div>
  )
}
