import { createFileRoute } from '@tanstack/react-router'
import { AccountSettingsForjaPage } from '@/pages/account-settings-forja-page'
import { isSafeManifestUrl } from '@/lib/forja-plugin-install'

export type ForjaSettingsSearch = {
  manifest?: string
  name?: string
  version?: string
  op?: 'remove'
}

export const Route = createFileRoute('/account/settings/forja')({
  validateSearch: (search: Record<string, unknown>): ForjaSettingsSearch => {
    const manifest =
      typeof search.manifest === 'string' && isSafeManifestUrl(search.manifest)
        ? search.manifest.trim()
        : undefined
    return {
      manifest,
      name:
        typeof search.name === 'string' && search.name.length > 0
          ? search.name.slice(0, 200)
          : undefined,
      version:
        typeof search.version === 'string' && search.version.length > 0
          ? search.version.slice(0, 40)
          : undefined,
      op: search.op === 'remove' ? 'remove' : undefined,
    }
  },
  component: AccountSettingsForjaPage,
})
