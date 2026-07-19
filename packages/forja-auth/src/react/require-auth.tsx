import type { ReactNode } from 'react'
import { authConfig } from '../config'
import { useAuth } from './auth-provider'

export type RequireAuthNavigate = {
  toLogin: ReactNode
  toResetPassword: ReactNode
  toMfa: ReactNode
  loading?: ReactNode
}

/**
 * Shared auth gate. Host apps pass Navigate elements for each destination
 * (TanStack / React Router differ by app).
 */
export function RequireAuth({
  children,
  navigate,
}: {
  children: ReactNode
  navigate: RequireAuthNavigate
}) {
  const { user, loading, isPasswordRecovery, requiresMfa } = useAuth()

  if (loading) {
    return (
      navigate.loading ?? (
        <div className="flex min-h-screen items-center justify-center opacity-70">
          Loading…
        </div>
      )
    )
  }

  if (isPasswordRecovery) return navigate.toResetPassword
  if (!user) return navigate.toLogin
  if (authConfig.mfaTotp && requiresMfa) return navigate.toMfa

  return children
}
