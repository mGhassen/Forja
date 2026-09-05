import { createFileRoute, Navigate } from '@tanstack/react-router'

/** Provider order is device-local in the app — not managed on the web portal. */
export const Route = createFileRoute('/account/settings/providers')({
  component: () => <Navigate to="/account/settings/addons" replace />,
})
