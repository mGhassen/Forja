import { useState } from 'react'
import { Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SettingsSection } from '@/components/settings-section'
import { useCommitDraft } from '@/hooks/use-commit-draft'
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

function packTitle(pack: ForjaPackRow): string {
  const name = pack.name?.trim()
  if (name && name !== pack.manifestUrl) return name
  return pack.manifestUrl
}

export function AccountSettingsForjaPage() {
  const { data, profileId, isLoading, save } = useForjaSetting()
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
    mapServer: forjaFromServer,
    makeEmpty: emptyForjaPayload,
    save,
  })
  const [url, setUrl] = useState('')

  const addPack = () => {
    const manifestUrl = url.trim()
    if (!manifestUrl) return
    if (draft.packs.some((a) => a.manifestUrl === manifestUrl)) return
    const row: ForjaPackRow = { manifestUrl, name: manifestUrl }
    void commit((prev) => ({ packs: [...prev.packs, row] }))
    setUrl('')
  }

  const removePack = (manifestUrl: string) => {
    void commit((prev) => ({
      packs: prev.packs.filter((a) => a.manifestUrl !== manifestUrl),
    }))
  }

  return (
    <AccountSettingsShell
      title="Forja plugins"
      description="Manifest URLs for Forja engine plugin packs. The app installs these on sync — same list as Settings → Forja plugins (community packs). Official ForjaHQ packs auto-install in the app."
      footer={
        <SettingsAutosaveFooter
          isSaving={isSaving}
          savedFlash={savedFlash}
          error={saveError}
        />
      }
    >
      <SettingsSection
        label="Installed packs"
        description="Paste a manifest URL (https://…/manifest.json) or a local path for desktop dev — the app validates and installs on sync."
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
                  <p className="font-medium">
                    {packTitle(pack)}
                    {pack.version?.trim() ? (
                      <span className="ml-2 font-normal text-forja-muted">
                        v{pack.version.trim()}
                      </span>
                    ) : null}
                  </p>
                  {pack.name?.trim() &&
                  pack.name.trim() !== pack.manifestUrl ? (
                    <p className="truncate text-sm text-forja-muted">
                      {pack.manifestUrl}
                    </p>
                  ) : null}
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="text-red-300 hover:text-red-200"
                  onClick={() => removePack(pack.manifestUrl)}
                  disabled={controlsLocked || isSaving}
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
            placeholder="https://…/manifest.json or /path/to/manifest.json"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            disabled={controlsLocked}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault()
                addPack()
              }
            }}
          />
        </div>
        <Button
          type="button"
          variant="secondary"
          onClick={addPack}
          disabled={controlsLocked || !url.trim()}
        >
          Add pack
        </Button>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
