import { createFileRoute } from '@tanstack/react-router'
import { AdminDownloadsPage } from '@/pages/admin/admin-downloads-page'

export const Route = createFileRoute('/_ops/downloads')({
  component: AdminDownloadsPage,
})
