import { createFileRoute } from '@tanstack/react-router'
import { AdminDashboardPage } from '@/pages/admin/admin-dashboard-page'

export const Route = createFileRoute('/_ops/')({
  component: AdminDashboardPage,
})
