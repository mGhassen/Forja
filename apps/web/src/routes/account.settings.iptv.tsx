import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsIptvPage } from '@/pages/account-settings-iptv-page'

export const Route = createFileRoute('/account/settings/iptv')({
  component: AccountSettingsIptvPage,
})
