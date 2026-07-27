import { useState } from 'react'
import { Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SettingsSection } from '@/components/settings-section'
import { useServerDraft } from '@/hooks/use-server-draft'
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
  const { data, profileId, isLoading, save, isSaving, saveError } =
    useNuvioSetting()
  const [draft, setDraft] = useServerDraft(
    profileId,
    data?.updated_at,
    Boolean(data) && !isLoading,
    data?.payload,
    nuvioFromServer,
    emptyNuvioPayload,
  )
  const [url, setUrl] = useState('')
  const [savedFlash, setSavedFlash] = useState(false)
  const controlsLocked = !profileId || (isLoading && !data)

  const addAddon = () => {
    const manifestUrl = url.trim()
    if (!manifestUrl) return
    if (draft.addons.some((a) => a.manifestUrl === manifestUrl)) return
    const row: NuvioAddonRow = { manifestUrl, name: manifestUrl }
    setDraft((prev) => ({ addons: [...prev.addons, row] }))
    setUrl('')
  }

  const removeAddon = (manifestUrl: string) => {
    setDraft((prev) => ({
      addons: prev.addons.filter((a) => a.manifestUrl !== manifestUrl),
    }))
  }

  const handleSave = async () => {
    await save(draft)
    setSavedFlash(true)
    window.setTimeout(() => setSavedFlash(false), 2500)
  }

  return (
    <AccountSettingsShell
      title="Nuvio addons"
      description="Manifest URLs for Nuvio scrapers. The app installs these on sync — same list as Settings → Providers & Addons → Nuvio."
      footer={
        <div className="flex flex-wrap items-center gap-3">
          <Button onClick={() => void handleSave()} disabled={controlsLocked || isSaving}>
            {isSaving ? 'Saving…' : 'Save changes'}
          </Button>
          {savedFlash ? (
            <span className="text-sm text-forja-green">Saved - open Forja to sync.</span>
          ) : null}
          {saveError ? (
            <span className="text-sm text-red-300">
              {saveError instanceof Error ? saveError.message : 'Save failed'}
            </span>
          ) : null}
        </div>
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
                className="flex min-h-[58px] items-center justify-between gap-3 px-0.5 py-3"
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
                  disabled={controlsLocked}
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
            disabled={controlsLocked}
          />
        </div>
        <Button
          type="button"
          variant="secondary"
          onClick={addAddon}
          disabled={controlsLocked}
        >
          Add addon
        </Button>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
