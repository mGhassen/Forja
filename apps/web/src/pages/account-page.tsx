import { Navigate, Outlet, useRouterState } from '@tanstack/react-router'

/**
 * Account root is not a destination. After login + profile pick,
 * the user lands in remote settings. Profile manage lives under
 * the settings profile menu — not as a peer of settings.
 */
export function AccountPage() {
  const pathname = useRouterState({ select: (state) => state.location.pathname })

  if (pathname !== '/account' && pathname !== '/account/') {
    return <Outlet />
  }

  return <Navigate to="/account/settings" replace />
}
