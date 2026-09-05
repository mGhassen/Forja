import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsTorrentPage } from '@/pages/account-settings-torrent-page'

export const Route = createFileRoute('/account/settings/torrent')({
  component: AccountSettingsTorrentPage,
})
