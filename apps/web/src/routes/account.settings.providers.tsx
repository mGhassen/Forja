import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsProvidersPage } from '@/pages/account-settings-providers-page'

export const Route = createFileRoute('/account/settings/providers')({
  component: AccountSettingsProvidersPage,
})
