import { createFileRoute } from '@tanstack/react-router'
import { AdminPoolPage } from '@/pages/admin/admin-pool-page'

export const Route = createFileRoute('/_ops/pool')({
  validateSearch: (s: Record<string, unknown>): { portal?: string } => {
    const portal =
      typeof s.portal === 'string' && s.portal.trim()
        ? s.portal.trim()
        : undefined
    return portal ? { portal } : {}
  },
  component: AdminPoolPage,
})
