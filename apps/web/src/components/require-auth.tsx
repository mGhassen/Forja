import { Navigate } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { useAuth } from '@/hooks/use-auth'

export function RequireAuth({ children }: { children: ReactNode }) {
  const { user, loading } = useAuth()

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

  return children
}
