import { useEffect, useState } from 'react'
import { Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SettingsSection } from '@/components/settings-section'
import { useUserSetting } from '@/hooks/use-user-setting'
import {
  emptyStremioPayload,
  SYNC_DOMAINS,
  type StremioAddonRow,
  type StremioPayload,
} from '@/lib/sync-domains'

export function AccountSettingsStremioPage() {
  const { data, profileId, isLoading, save, isSaving, saveError } =
    useUserSetting<StremioPayload>(SYNC_DOMAINS.stremio)
  const [draft, setDraft] = useState(emptyStremioPayload())
  const [url, setUrl] = useState('')
  const [savedFlash, setSavedFlash] = useState(false)

  useEffect(() => {
    setDraft(emptyStremioPayload())
  }, [profileId])

  useEffect(() => {
    if (!data) return
    setDraft({ addons: data.payload.addons ?? [] })
  }, [data])

  const addAddon = () => {
    const baseUrl = url.trim()
    if (!baseUrl) return
    if (draft.addons.some((a) => a.baseUrl === baseUrl)) return
    const row: StremioAddonRow = { baseUrl, name: baseUrl }
    setDraft((prev) => ({ addons: [...prev.addons, row] }))
    setUrl('')
  }

  const removeAddon = (baseUrl: string) => {
    setDraft((prev) => ({
      addons: prev.addons.filter((a) => a.baseUrl !== baseUrl),
    }))
  }

  const handleSave = async () => {
    await save(draft)
    setSavedFlash(true)
    window.setTimeout(() => setSavedFlash(false), 2500)
  }

  return (
    <AccountSettingsShell
      title="Stremio addons"
      description="Manifest URLs for Stremio addons. The app installs these on sync — same list as Settings → Sources."
      footer={
        <div className="flex flex-wrap items-center gap-3">
          <Button onClick={() => void handleSave()} disabled={isLoading || isSaving}>
            {isSaving ? 'Saving…' : 'Save changes'}
          </Button>
          {savedFlash ? (
            <span className="text-sm text-forja-green">Saved — open Forja to sync.</span>
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
        description="Paste a Stremio addon manifest URL ending with /manifest.json."
      >
          {draft.addons.length === 0 ? (
            <p className="text-sm text-forja-muted">No addons yet.</p>
          ) : (
            <ul className="divide-y divide-forja-border">
              {draft.addons.map((addon) => (
                <li
                  key={addon.baseUrl}
                  className="flex min-h-[58px] items-center justify-between gap-3 px-0.5 py-3"
                >
                  <div className="min-w-0">
                    <p className="font-medium">{addon.name || 'Addon'}</p>
                    <p className="truncate text-sm text-forja-muted">{addon.baseUrl}</p>
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="text-red-300 hover:text-red-200"
                    onClick={() => removeAddon(addon.baseUrl)}
                  >
                    <Trash2 className="size-4" />
                  </Button>
                </li>
              ))}
            </ul>
          )}

          <div className="space-y-2 py-4">
            <Label htmlFor="addon-url">Manifest URL</Label>
            <Input
              id="addon-url"
              placeholder="https://…/manifest.json"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
            />
          </div>
          <Button type="button" variant="secondary" onClick={addAddon}>
            Add addon
          </Button>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
