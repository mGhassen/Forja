import { AccountSettingsAddonPackKindPage } from '@/pages/account-settings-addon-pack-kind-page'

/** Addons → Live Sports — live provider packs + schedule catalogs. */
export function AccountSettingsLiveSportsPage() {
  return (
    <AccountSettingsAddonPackKindPage
      title="Live Sports"
      description="Addons → Live Sports — Forja live provider packs and schedule catalogs on this profile. Same packs as Settings → Addons → Live Sports in the app (expand a pack to toggle plugins)."
      kinds={['live', 'catalog']}
      sectionLabel="Live plugins"
      sectionDescription="Install or remove Live / Catalog packs. Devices download scripts on the next sync. Per-plugin enable stays in the app."
      localNote="League filters, portal matcher, and per-plugin toggles stay in the app (Settings → Addons → Live Sports). Turning the Addons switch off hides the Live Sports tab."
    />
  )
}
