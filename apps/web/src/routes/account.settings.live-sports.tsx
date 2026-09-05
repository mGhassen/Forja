import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsLiveSportsPage } from '@/pages/account-settings-live-sports-page'

export const Route = createFileRoute('/account/settings/live-sports')({
  component: AccountSettingsLiveSportsPage,
})
