import { createFileRoute } from '@tanstack/react-router'
import { AdminPoolPage } from '@/pages/admin/admin-pool-page'

export const Route = createFileRoute('/_ops/pool')({
  component: AdminPoolPage,
})
