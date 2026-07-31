import { createFileRoute } from '@tanstack/react-router'
import { AdminDeepRefsPage } from '@/pages/admin/admin-deep-refs-page'

export const Route = createFileRoute('/_ops/deep-refs')({
  component: AdminDeepRefsPage,
})
