import { AccountSettingsAddonPackKindPage } from '@/pages/account-settings-addon-pack-kind-page'

/** Addons → Direct torrent — torrent indexer packs. */
export function AccountSettingsTorrentPage() {
  return (
    <AccountSettingsAddonPackKindPage
      title="Direct torrent"
      description="Addons → Direct torrent — Forja torrent indexer packs on this profile. Same packs as Settings → Addons → Direct torrent in the app (expand a pack to toggle indexers)."
      kinds={['torrent']}
      sectionLabel="Torrent plugins"
      sectionDescription="Install or remove the torrent pack. Devices download indexer scripts on the next sync. Per-plugin enable stays in the app."
      localNote="Jackett / Prowlarr API keys, FlareSolverr, sort order, and per-indexer toggles stay in the app (Settings → Addons → Direct torrent). Those keys are device-local and do not sync."
    />
  )
}
