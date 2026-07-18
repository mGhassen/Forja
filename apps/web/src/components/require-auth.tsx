import { Navigate } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { useAuth } from '@/hooks/use-auth'

export function RequireAuth({ children }: { children: ReactNode }) {
  const { user, loading, isPasswordRecovery } = useAuth()

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center text-forja-muted">
        Loading…
      </div>
    )
  }

  // Recovery session is not a normal login — finish password reset first.
  if (isPasswordRecovery) {
    return <Navigate to="/reset-password" />
  }

  if (!user) {
    return <Navigate to="/login" />
  }

  return children
}
