import { useEffect } from 'react'
import { useNavigate, useRouterState } from '@tanstack/react-router'
import { useAuth } from '@/hooks/use-auth'

const RECOVERY_ALLOWED_PREFIXES = ['/reset-password'] as const

function isAllowedDuringRecovery(pathname: string): boolean {
  return RECOVERY_ALLOWED_PREFIXES.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`),
  )
}

/**
 * Recovery is not a login. The only allowed screen is `/reset-password`
 * until a new password is saved (then the session is signed out).
 */
export function PasswordRecoveryGate() {
  const { isPasswordRecovery, loading } = useAuth()
  const navigate = useNavigate()
  const pathname = useRouterState({ select: (s) => s.location.pathname })

  useEffect(() => {
    if (loading || !isPasswordRecovery) return
    if (isAllowedDuringRecovery(pathname)) return
    void navigate({ to: '/reset-password', replace: true })
  }, [loading, isPasswordRecovery, pathname, navigate])

  return null
}
