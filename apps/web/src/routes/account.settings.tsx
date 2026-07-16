import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsPage } from '@/pages/account-settings-page'

export const Route = createFileRoute('/account/settings')({
  component: AccountSettingsPage,
})
