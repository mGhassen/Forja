import { useState } from 'react'
import { Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SettingsSection } from '@/components/settings-section'
import { useServerDraft } from '@/hooks/use-server-draft'
import { useStremioSetting } from '@/hooks/use-user-setting'
import {
  emptyStremioPayload,
  type StremioAddonRow,
  type StremioPayload,
} from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

function stremioFromServer(value: unknown): StremioPayload {
  const payload = value as StremioPayload | undefined
  return { addons: payload?.addons ?? [] }
}

function toggleFeature(
  features: Array<'vod' | 'live'> | undefined,
  feature: 'vod' | 'live',
): Array<'vod' | 'live'> {
  const current = features?.length ? [...features] : (['vod'] as Array<'vod' | 'live'>)
  if (current.includes(feature)) {
    if (current.length <= 1) return current
    return current.filter((f) => f !== feature)
  }
  const next = [...current, feature]
  return next.sort((a, b) => (a === 'vod' ? -1 : 1) - (b === 'vod' ? -1 : 1))
}

export function AccountSettingsStremioPage() {
  const { data, profileId, isLoading, save, isSaving, saveError } =
    useStremioSetting()
  const [draft, setDraft] = useServerDraft(
    profileId,
    data?.updated_at,
    Boolean(data) && !isLoading,
    data?.payload,
    stremioFromServer,
    emptyStremioPayload,
  )
  const [url, setUrl] = useState('')
  const [savedFlash, setSavedFlash] = useState(false)
  const controlsLocked = !profileId || (isLoading && !data)

  const addAddon = () => {
    const baseUrl = url.trim()
    if (!baseUrl) return
    if (draft.addons.some((a) => a.baseUrl === baseUrl)) return
    const row: StremioAddonRow = {
      baseUrl,
      name: baseUrl,
      features: ['vod'],
    }
    setDraft((prev) => ({ addons: [...prev.addons, row] }))
    setUrl('')
  }

  const removeAddon = (baseUrl: string) => {
    setDraft((prev) => ({
      addons: prev.addons.filter((a) => a.baseUrl !== baseUrl),
    }))
  }

  const setFeature = (baseUrl: string, feature: 'vod' | 'live') => {
    setDraft((prev) => ({
      addons: prev.addons.map((a) =>
        a.baseUrl === baseUrl
          ? { ...a, features: toggleFeature(a.features, feature) }
          : a,
      ),
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
      description="Manifest URLs for Stremio addons. Assign each to Sources and/or Live Matches — same list as Settings → Sources in the app."
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
        description="Paste a Stremio addon manifest URL ending with /manifest.json. Use Sources for movies/series; Live Matches for sport addons."
      >
          {draft.addons.length === 0 ? (
            <p className="text-sm text-forja-muted">No addons yet.</p>
          ) : (
            <ul className="divide-y divide-forja-border">
              {draft.addons.map((addon) => {
                const features = addon.features?.length ? addon.features : (['vod'] as const)
                return (
                  <li
                    key={addon.baseUrl}
                    className="flex min-h-[58px] flex-col gap-3 px-0.5 py-3 sm:flex-row sm:items-center sm:justify-between"
                  >
                    <div className="min-w-0">
                      <p className="font-medium">{addon.name || 'Addon'}</p>
                      <p className="truncate text-sm text-forja-muted">{addon.baseUrl}</p>
                      <div className="mt-2 flex flex-wrap gap-2">
                        {(
                          [
                            ['vod', 'Sources'],
                            ['live', 'Live Matches'],
                          ] as const
                        ).map(([id, label]) => {
                          const selected = features.includes(id)
                          return (
                            <button
                              key={id}
                              type="button"
                              disabled={controlsLocked}
                              onClick={() => setFeature(addon.baseUrl, id)}
                              className={cn(
                                'rounded-md border px-2.5 py-1 text-xs font-semibold transition-colors',
                                selected
                                  ? 'border-forja-green/50 bg-forja-green/15 text-forja-green'
                                  : 'border-forja-border bg-transparent text-forja-muted hover:text-forja-fg',
                              )}
                            >
                              {label}
                            </button>
                          )
                        })}
                      </div>
                    </div>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="self-end text-red-300 hover:text-red-200 sm:self-center"
                      onClick={() => removeAddon(addon.baseUrl)}
                      disabled={controlsLocked}
                    >
                      <Trash2 className="size-4" />
                    </Button>
                  </li>
                )
              })}
            </ul>
          )}

          <div className="space-y-2 py-4">
            <Label htmlFor="addon-url">Manifest URL</Label>
            <Input
              id="addon-url"
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
