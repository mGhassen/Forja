import { Navigate, Outlet, useRouterState } from '@tanstack/react-router'

export function AccountSettingsPage() {
  const pathname = useRouterState({ select: (state) => state.location.pathname })

  if (pathname !== '/account/settings' && pathname !== '/account/settings/') {
    return <Outlet />
  }

  return <Navigate to="/account/settings/addons" replace />
}
