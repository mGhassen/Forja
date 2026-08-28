import { useState } from 'react'
import { Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SettingsSection } from '@/components/settings-section'
import { useServerDraft } from '@/hooks/use-server-draft'
import { useForjaSetting } from '@/hooks/use-user-setting'
import {
  emptyForjaPayload,
  type ForjaPackRow,
  type ForjaPayload,
} from '@/lib/sync-domains'

function forjaFromServer(value: unknown): ForjaPayload {
  const payload = value as ForjaPayload | undefined
  return { packs: payload?.packs ?? [] }
}

export function AccountSettingsForjaPage() {
  const { data, profileId, isLoading, save, isSaving, saveError } =
    useForjaSetting()
  const [draft, setDraft] = useServerDraft(
    profileId,
    data?.updated_at,
    Boolean(data) && !isLoading,
    data?.payload,
    forjaFromServer,
    emptyForjaPayload,
  )
  const [url, setUrl] = useState('')
  const [savedFlash, setSavedFlash] = useState(false)
  const controlsLocked = !profileId || (isLoading && !data)

  const addPack = () => {
    const manifestUrl = url.trim()
    if (!manifestUrl) return
    if (draft.packs.some((a) => a.manifestUrl === manifestUrl)) return
    const row: ForjaPackRow = { manifestUrl, name: manifestUrl }
    setDraft((prev) => ({ packs: [...prev.packs, row] }))
    setUrl('')
  }

  const removePack = (manifestUrl: string) => {
    setDraft((prev) => ({
      packs: prev.packs.filter((a) => a.manifestUrl !== manifestUrl),
    }))
  }

  const handleSave = async () => {
    await save(draft)
    setSavedFlash(true)
    window.setTimeout(() => setSavedFlash(false), 2500)
  }

  return (
    <AccountSettingsShell
      title="Forja plugins"
      description="Manifest URLs for Forja engine plugin packs. The app installs these on sync — same list as Settings → Forja plugins (community packs). Official ForjaHQ packs auto-install in the app."
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
        label="Installed packs"
        description="Paste a Forja plugin pack manifest URL ending with /manifest.json."
      >
        {draft.packs.length === 0 ? (
          <p className="text-sm text-forja-muted">No packs yet.</p>
        ) : (
          <ul className="divide-y divide-forja-border">
            {draft.packs.map((pack) => (
              <li
                key={pack.manifestUrl}
                className="flex min-h-[58px] items-center justify-between gap-3 px-0.5 py-3"
              >
                <div className="min-w-0">
                  <p className="font-medium">{pack.name || 'Pack'}</p>
                  <p className="truncate text-sm text-forja-muted">
                    {pack.manifestUrl}
                  </p>
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="text-red-300 hover:text-red-200"
                  onClick={() => removePack(pack.manifestUrl)}
                  disabled={controlsLocked}
                >
                  <Trash2 className="size-4" />
                </Button>
              </li>
            ))}
          </ul>
        )}

        <div className="space-y-2 py-4">
          <Label htmlFor="forja-pack-url">Manifest URL</Label>
          <Input
            id="forja-pack-url"
            placeholder="https://…/manifest.json"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            disabled={controlsLocked}
          />
        </div>
        <Button
          type="button"
          variant="secondary"
          onClick={addPack}
          disabled={controlsLocked}
        >
          Add pack
        </Button>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
