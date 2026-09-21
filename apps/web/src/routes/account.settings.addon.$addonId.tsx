import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsPackAddonPage } from '@/pages/account-settings-pack-addon-page'

export const Route = createFileRoute('/account/settings/addon/$addonId')({
  component: AddonRoute,
})

function AddonRoute() {
  const { addonId } = Route.useParams()
  return <AccountSettingsPackAddonPage addonId={addonId} />
}
