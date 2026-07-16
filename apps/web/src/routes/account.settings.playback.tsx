import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsPlaybackPage } from '@/pages/account-settings-playback-page'

export const Route = createFileRoute('/account/settings/playback')({
  component: AccountSettingsPlaybackPage,
})
