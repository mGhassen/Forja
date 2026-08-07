import { createFileRoute } from '@tanstack/react-router'
import { AdminPoolPage } from '@/pages/admin/admin-pool-page'

export type PoolSearch = {
  /** Focus portal by iptv_portals.id */
  portal?: string
  /** Fallback when portal_id is stale — match url + user */
  url?: string
  user?: string
}

export const Route = createFileRoute('/_ops/pool')({
  validateSearch: (s: Record<string, unknown>): PoolSearch => {
    const portal =
      typeof s.portal === 'string' && s.portal.trim()
        ? s.portal.trim()
        : undefined
    const url =
      typeof s.url === 'string' && s.url.trim() ? s.url.trim() : undefined
    const user =
      typeof s.user === 'string' && s.user.trim() ? s.user.trim() : undefined
    const out: PoolSearch = {}
    if (portal) out.portal = portal
    if (url) out.url = url
    if (user) out.user = user
    return out
  },
  component: AdminPoolPage,
})
