import { createFileRoute } from '@tanstack/react-router'
import { AdminPluginsPage } from '@/pages/admin/admin-plugins-page'

export const Route = createFileRoute('/_ops/plugins')({
  component: AdminPluginsPage,
})
