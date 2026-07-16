import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsStremioPage } from '@/pages/account-settings-stremio-page'

export const Route = createFileRoute('/account/settings/stremio')({
  component: AccountSettingsStremioPage,
})
