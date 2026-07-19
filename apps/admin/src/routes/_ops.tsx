import { Outlet, createFileRoute } from '@tanstack/react-router'
import { AdminShell } from '@/components/admin-shell'
import { RequireAdmin } from '@/components/require-admin'

export const Route = createFileRoute('/_ops')({
  component: OpsLayout,
})

function OpsLayout() {
  return (
    <RequireAdmin>
      <AdminShell>
        <Outlet />
      </AdminShell>
    </RequireAdmin>
  )
}
