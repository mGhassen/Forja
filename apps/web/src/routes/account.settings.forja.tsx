import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsForjaPage } from '@/pages/account-settings-forja-page'

export const Route = createFileRoute('/account/settings/forja')({
  component: AccountSettingsForjaPage,
})
