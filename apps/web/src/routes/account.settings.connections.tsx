import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsConnectionsPage } from '@/pages/account-settings-connections-page'

export const Route = createFileRoute('/account/settings/connections')({
  component: AccountSettingsConnectionsPage,
})
