import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsNuvioPage } from '@/pages/account-settings-nuvio-page'

export const Route = createFileRoute('/account/settings/nuvio')({
  component: AccountSettingsNuvioPage,
})
