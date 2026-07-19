import { useEffect, useState } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { runAuthCallback } from '@forja/auth/react'
import { AUTH_UNAVAILABLE_MESSAGE } from '@/hooks/use-auth'
import { supabase, supabaseConfigured } from '@/lib/supabase'

export function AuthCallbackPage() {
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    void (async () => {
      const result = await runAuthCallback({
        client: supabase,
        configured: supabaseConfigured,
        unavailableMessage: AUTH_UNAVAILABLE_MESSAGE,
        defaultNext: '/',
        errorPath: '/login',
      })
      if (cancelled) return
      if (result.status === 'error') {
        setError(result.message)
        return
      }
      if (result.needsMfa) {
        void navigate({ to: '/login/mfa', replace: true })
        return
      }
      void navigate({ to: result.nextPath, replace: true })
    })()
    return () => {
      cancelled = true
    }
  }, [navigate])

  if (error) {
    return (
      <div className="mx-auto flex max-w-sm flex-col gap-3 py-16 text-center">
        <p className="text-sm text-forja-text">{error}</p>
        <Link to="/login" className="text-sm text-forja-green hover:underline">
          Back to sign in
        </Link>
      </div>
    )
  }

  return (
    <div className="py-16 text-center text-sm text-forja-muted">
      Finishing sign-in…
    </div>
  )
}
