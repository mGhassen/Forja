import { Navigate } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { useAuth } from '@/hooks/use-auth'
import { authConfig } from '@forja/auth'

export function RequireAuth({ children }: { children: ReactNode }) {
  const { user, loading, requiresMfa } = useAuth()

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center text-forja-muted">
        Loading…
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/login" />
  }

  if (authConfig.mfaTotp && requiresMfa) {
    return <Navigate to="/login/mfa" />
  }

  return children
}
