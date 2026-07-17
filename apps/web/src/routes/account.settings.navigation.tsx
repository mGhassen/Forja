import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsNavigationPage } from '@/pages/account-settings-navigation-page'

export const Route = createFileRoute('/account/settings/navigation')({
  component: AccountSettingsNavigationPage,
})
