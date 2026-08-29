import { useState } from 'react'
import { Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SettingsSection } from '@/components/settings-section'
import { useCommitDraft } from '@/hooks/use-commit-draft'
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
  const { data, profileId, isLoading, save } = useStremioSetting()
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
    mapServer: stremioFromServer,
    makeEmpty: emptyStremioPayload,
    save,
  })
  const [url, setUrl] = useState('')

  const addAddon = () => {
    const baseUrl = url.trim()
    if (!baseUrl) return
    if (draft.addons.some((a) => a.baseUrl === baseUrl)) return
    const row: StremioAddonRow = {
      baseUrl,
      name: baseUrl,
      features: ['vod'],
      enabled: true,
    }
    void commit((prev) => ({ addons: [...prev.addons, row] }))
    setUrl('')
  }

  const removeAddon = (baseUrl: string) => {
    void commit((prev) => ({
      addons: prev.addons.filter((a) => a.baseUrl !== baseUrl),
    }))
  }

  const setEnabled = (baseUrl: string, enabled: boolean) => {
    void commit((prev) => ({
      addons: prev.addons.map((a) =>
        a.baseUrl === baseUrl ? { ...a, enabled } : a,
      ),
    }))
  }

  const setFeature = (baseUrl: string, feature: 'vod' | 'live') => {
    void commit((prev) => ({
      addons: prev.addons.map((a) =>
        a.baseUrl === baseUrl
          ? { ...a, features: toggleFeature(a.features, feature) }
          : a,
      ),
    }))
  }

  return (
    <AccountSettingsShell
      title="Stremio addons"
      description="Manifest URLs for Stremio addons. Assign each to Sources and/or Live Matches — same list as Settings → Sources in the app."
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
        description="Paste a Stremio addon manifest URL ending with /manifest.json. Use Sources for movies/series; Live Matches for sport addons. Turn the switch off to keep the addon installed without using it."
      >
          {draft.addons.length === 0 ? (
            <p className="text-sm text-forja-muted">No addons yet.</p>
          ) : (
            <ul className="divide-y divide-forja-border">
              {draft.addons.map((addon) => {
                const features: Array<'vod' | 'live'> = addon.features?.length
                  ? [...addon.features]
                  : ['vod']
                const enabled = addon.enabled !== false
                return (
                  <li
                    key={addon.baseUrl}
                    className="flex min-h-14.5 flex-col gap-3 px-0.5 py-3 sm:flex-row sm:items-center sm:justify-between"
                  >
                    <div className="min-w-0">
                      <p
                        className={cn(
                          'font-medium',
                          !enabled && 'text-forja-muted',
                        )}
                      >
                        {addon.name || 'Addon'}
                      </p>
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
                              disabled={controlsLocked || isSaving}
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
                    <div className="flex items-center gap-1 self-end sm:self-center">
                      <button
                        type="button"
                        role="switch"
                        aria-checked={enabled}
                        aria-label={enabled ? 'Disable addon' : 'Enable addon'}
                        disabled={controlsLocked || isSaving}
                        onClick={() => setEnabled(addon.baseUrl, !enabled)}
                        className="group relative h-6 w-11 shrink-0 rounded-full transition-colors disabled:cursor-not-allowed disabled:opacity-60"
                      >
                        <span
                          aria-hidden
                          className={cn(
                            'absolute inset-0 rounded-full transition-colors',
                            enabled ? 'bg-forja-green' : 'bg-white/15',
                          )}
                        />
                        <span
                          aria-hidden
                          className={cn(
                            'absolute top-1 left-1 size-4 rounded-full bg-forja-bg transition-transform',
                            enabled ? 'translate-x-5' : 'translate-x-0',
                          )}
                        />
                      </button>
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="text-red-300 hover:text-red-200"
                        onClick={() => removeAddon(addon.baseUrl)}
                        disabled={controlsLocked || isSaving}
                      >
                        <Trash2 className="size-4" />
                      </Button>
                    </div>
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
