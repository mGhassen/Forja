import { createFileRoute } from '@tanstack/react-router'
import { AdminScrapePage } from '@/pages/admin/admin-scrape-page'

export const Route = createFileRoute('/_ops/scrape')({
  component: AdminScrapePage,
})
