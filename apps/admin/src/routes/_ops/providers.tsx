import { createFileRoute } from '@tanstack/react-router'
import { AdminProvidersPage } from '@/pages/admin/admin-providers-page'

export const Route = createFileRoute('/_ops/providers')({
  component: AdminProvidersPage,
})
