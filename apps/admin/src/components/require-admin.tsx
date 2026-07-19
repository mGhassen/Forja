import type { ReactNode } from 'react'
import { Link } from '@tanstack/react-router'
import { RequireAuth } from '@/components/require-auth'
import { useIsAdmin } from '@/hooks/use-is-admin'
import { supabaseConfigured } from '@/lib/supabase'

function AdminGate({ children }: { children: ReactNode }) {
  const admin = useIsAdmin()

  if (!supabaseConfigured) {
    return (
      <div className="mx-auto max-w-lg p-8 text-sm text-amber-200">
        Set <code className="font-mono-ui">VITE_SUPABASE_*</code> (or repo-root{' '}
        <code className="font-mono-ui">SUPABASE_*</code>) for the web app.
      </div>
    )
  }

  if (admin.isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center text-forja-muted">
        Loading…
      </div>
    )
  }

  if (!admin.data) {
    return (
      <div className="mx-auto flex min-h-screen max-w-lg flex-col justify-center gap-3 p-8">
        <p className="text-sm text-red-300">
          Signed in, but this account is not <code className="font-mono-ui">is_admin</code>.
        </p>
        <Link to="/login" className="text-sm text-forja-green hover:underline">
          Back to sign in
        </Link>
      </div>
    )
  }

  return children
}

/** Auth + `accounts.is_admin` gate for ops routes. */
export function RequireAdmin({ children }: { children: ReactNode }) {
  return (
    <RequireAuth>
      <AdminGate>{children}</AdminGate>
    </RequireAuth>
  )
}
