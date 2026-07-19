import { useEffect, useState } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { runAuthCallback } from '@forja/auth/react'
import { AUTH_UNAVAILABLE_MESSAGE } from '@/hooks/use-auth'
import {
  isSafeDesktopCallback,
  resolveDesktopAuthParams,
} from '@/lib/desktop-auth-callback'
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
        defaultNext: '/account/profiles',
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
      const desktop = resolveDesktopAuthParams()
      if (isSafeDesktopCallback(desktop.callback)) {
        void navigate({ to: '/login', replace: true })
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
      <section className="flex flex-1 flex-col items-center justify-center gap-4 px-5 py-20 text-center">
        <p className="max-w-md text-base text-[#EDE6DA]">{error}</p>
        <Link
          to="/login"
          className="font-mono-ui text-xs font-bold uppercase tracking-[0.12em] text-forja-green hover:underline"
        >
          Back to log in
        </Link>
      </section>
    )
  }

  return (
    <section className="flex flex-1 items-center justify-center px-5 py-20 text-forja-muted">
      Finishing sign-in…
    </section>
  )
}
