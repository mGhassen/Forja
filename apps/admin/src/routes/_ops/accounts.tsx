import { createFileRoute } from '@tanstack/react-router'
import { AdminAccountsPage } from '@/pages/admin/admin-accounts-page'

export const Route = createFileRoute('/_ops/accounts')({
  component: AdminAccountsPage,
})
