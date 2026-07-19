import { useEffect, useState } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { exchangeAuthCode, checkRequiresMfa } from '@/lib/auth'
import { supabase } from '@/lib/supabase'
import {
  isSafeDesktopCallback,
  resolveDesktopAuthParams,
} from '@/lib/desktop-auth-callback'

export function AuthCallbackPage() {
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    void (async () => {
      const result = await exchangeAuthCode()
      if (cancelled) return
      if (result.status === 'error') {
        setError(result.message)
        return
      }
      const needsMfa = await checkRequiresMfa(supabase)
      if (cancelled) return
      if (needsMfa) {
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
