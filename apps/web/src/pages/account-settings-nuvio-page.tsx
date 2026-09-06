import { useState } from 'react'
import { Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SettingsSection } from '@/components/settings-section'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import { useNuvioSetting } from '@/hooks/use-user-setting'
import {
  emptyNuvioPayload,
  type NuvioAddonRow,
  type NuvioPayload,
} from '@/lib/sync-domains'

function nuvioFromServer(value: unknown): NuvioPayload {
  const payload = value as NuvioPayload | undefined
  return { addons: payload?.addons ?? [] }
}

export function AccountSettingsNuvioPage() {
  const { data, profileId, isLoading, save } = useNuvioSetting()
  const {
    draft,
    commit,
    controlsLocked,
    isSaving,
    savedFlash,
    saveError,
  } = useCommitDraft({
    profileId,
    updatedAt: data?.updated_at,
    isReady: Boolean(data) && !isLoading,
    serverValue: data?.payload,
    mapServer: nuvioFromServer,
    makeEmpty: emptyNuvioPayload,
    save,
  })
  const [url, setUrl] = useState('')

  const addAddon = () => {
    const manifestUrl = url.trim()
    if (!manifestUrl) return
    if (draft.addons.some((a) => a.manifestUrl === manifestUrl)) return
    const row: NuvioAddonRow = { manifestUrl, name: manifestUrl }
    void commit((prev) => ({ addons: [...prev.addons, row] }))
    setUrl('')
  }

  const removeAddon = (manifestUrl: string) => {
    void commit((prev) => ({
      addons: prev.addons.filter((a) => a.manifestUrl !== manifestUrl),
    }))
  }

  return (
    <AccountSettingsShell
      title="Nuvio"
      description="Addons → Nuvio — scraper manifest URLs. Same list as Settings → Addons → Nuvio in the app."
      footer={
        <SettingsAutosaveFooter
          isSaving={isSaving}
          savedFlash={savedFlash}
          error={saveError}
        />
      }
    >
      <SettingsSection
        label="Installed addons"
        description="Paste a Nuvio addon manifest URL ending with /manifest.json."
      >
        {draft.addons.length === 0 ? (
          <p className="text-sm text-forja-muted">No addons yet.</p>
        ) : (
          <ul className="divide-y divide-forja-border">
            {draft.addons.map((addon) => (
              <li
                key={addon.manifestUrl}
                className="flex min-h-14.5 items-center justify-between gap-3 px-0.5 py-3"
              >
                <div className="min-w-0">
                  <p className="font-medium">{addon.name || 'Addon'}</p>
                  <p className="truncate text-sm text-forja-muted">
                    {addon.manifestUrl}
                  </p>
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="text-red-300 hover:text-red-200"
                  onClick={() => removeAddon(addon.manifestUrl)}
                  disabled={controlsLocked || isSaving}
                >
                  <Trash2 className="size-4" />
                </Button>
              </li>
            ))}
          </ul>
        )}

        <div className="space-y-2 py-4">
          <Label htmlFor="nuvio-addon-url">Manifest URL</Label>
          <Input
            id="nuvio-addon-url"
            placeholder="https://…/manifest.json"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            disabled={controlsLocked || isSaving}
          />
        </div>
        <Button
          type="button"
          variant="secondary"
          onClick={addAddon}
          disabled={controlsLocked || isSaving || !url.trim()}
        >
          Add addon
        </Button>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
