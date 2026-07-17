import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsAccountPage } from '@/pages/account-settings-account-page'

export const Route = createFileRoute('/account/settings/account')({
  component: AccountSettingsAccountPage,
})
