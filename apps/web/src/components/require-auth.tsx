import { Navigate } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { RequireAuth as SharedRequireAuth } from '@forja/auth/react'

export function RequireAuth({ children }: { children: ReactNode }) {
  return (
    <SharedRequireAuth
      navigate={{
        toLogin: <Navigate to="/login" />,
        toResetPassword: <Navigate to="/reset-password" />,
        toMfa: <Navigate to="/login/mfa" />,
        loading: (
          <div className="flex min-h-screen items-center justify-center text-forja-muted">
            Loading…
          </div>
        ),
      }}
    >
      {children}
    </SharedRequireAuth>
  )
}
