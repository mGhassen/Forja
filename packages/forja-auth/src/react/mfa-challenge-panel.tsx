import { useEffect, useState, type FormEvent, type ReactNode } from 'react'
import { useAuth } from './auth-provider'

/**
 * Shared TOTP challenge UI (unstyled shell — host supplies Button/Input/Label).
 */
export function MfaChallengePanel({
  onVerified,
  footer,
  render,
}: {
  onVerified: () => void
  footer?: ReactNode
  render: (props: {
    code: string
    setCode: (v: string) => void
    error: string | null
    submitting: boolean
    factorReady: boolean
    onSubmit: (e: FormEvent) => void
  }) => ReactNode
}) {
  const { user, loading, requiresMfa, listMfaFactors, challengeAndVerifyMfa } =
    useAuth()
  const [factorId, setFactorId] = useState<string | null>(null)
  const [code, setCode] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    if (loading) return
    if (!user || !requiresMfa) {
      onVerified()
    }
  }, [loading, user, requiresMfa, onVerified])

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
    onVerified()
  }

  return (
    <>
      {render({
        code,
        setCode: (v) => setCode(v.replace(/\D/g, '').slice(0, 6)),
        error,
        submitting,
        factorReady: !!factorId,
        onSubmit: (e) => void onSubmit(e),
      })}
      {footer}
    </>
  )
}
