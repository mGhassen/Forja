import { createFileRoute } from '@tanstack/react-router'
import { AdminDeepRefsPage } from '@/pages/admin/admin-deep-refs-page'

export type DeepRefsSearch = {
  /** Focus / expand deep ref by iptv_scrape_deep_refs.id */
  ref?: string
}

export const Route = createFileRoute('/_ops/deep-refs')({
  validateSearch: (s: Record<string, unknown>): DeepRefsSearch => {
    const ref =
      typeof s.ref === 'string' && s.ref.trim() ? s.ref.trim() : undefined
    return ref ? { ref } : {}
  },
  component: AdminDeepRefsPage,
})
