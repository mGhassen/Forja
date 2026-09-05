import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsAddonsPage } from '@/pages/account-settings-addons-page'

export const Route = createFileRoute('/account/settings/addons')({
  component: AccountSettingsAddonsPage,
})
