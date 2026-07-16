import { createFileRoute } from '@tanstack/react-router'
import { AccountProfilesPage } from '@/pages/account-profiles-page'

export const Route = createFileRoute('/account/profiles')({
  component: AccountProfilesPage,
})
