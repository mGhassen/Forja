import { useEffect, useRef, useState } from 'react'
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

function needsManifestMeta(row: ForjaPackRow): boolean {
  const name = row.name?.trim()
  return !name || name === row.manifestUrl || !row.version?.trim()
}

async function fetchPackMeta(
  manifestUrl: string,
): Promise<{ name: string; version?: string }> {
  const res = await fetch(manifestUrl, {
    headers: { Accept: 'application/json' },
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  const raw: unknown = await res.json()
  if (!raw || typeof raw !== 'object') throw new Error('Invalid manifest')
  const m = raw as Record<string, unknown>
  const name =
    typeof m.name === 'string' && m.name.trim()
      ? m.name.trim()
      : typeof m.id === 'string' && m.id.trim()
        ? m.id.trim()
        : 'Forja pack'
  const version =
    typeof m.version === 'string' && m.version.trim()
      ? m.version.trim()
      : undefined
  return { name, version }
}

function packTitle(pack: ForjaPackRow): string {
  const name = pack.name?.trim()
  if (name && name !== pack.manifestUrl) return name
  return 'Pack'
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
  const [adding, setAdding] = useState(false)
  const [addError, setAddError] = useState<string | null>(null)
  const [resolving, setResolving] = useState(false)
  const hydratedUrls = useRef(new Set<string>())

  // Resolve name/version for bare-URL rows, then persist.
  useEffect(() => {
    const pending = draft.packs.filter(
      (p) => needsManifestMeta(p) && !hydratedUrls.current.has(p.manifestUrl),
    )
    if (pending.length === 0) return

    let cancelled = false
    setResolving(true)
    void (async () => {
      const updates = new Map<string, { name: string; version?: string }>()
      await Promise.all(
        pending.map(async (pack) => {
          hydratedUrls.current.add(pack.manifestUrl)
          try {
            updates.set(pack.manifestUrl, await fetchPackMeta(pack.manifestUrl))
          } catch {
            hydratedUrls.current.delete(pack.manifestUrl)
          }
        }),
      )
      if (cancelled || updates.size === 0) {
        if (!cancelled) setResolving(false)
        return
      }
      await commit((prev) => ({
        packs: prev.packs.map((p) => {
          const meta = updates.get(p.manifestUrl)
          if (!meta) return p
          return {
            ...p,
            name: meta.name,
            ...(meta.version ? { version: meta.version } : {}),
          }
        }),
      }))
      if (!cancelled) setResolving(false)
    })()

    return () => {
      cancelled = true
    }
  }, [draft.packs, commit])

  const addPack = async () => {
    const manifestUrl = url.trim()
    if (!manifestUrl) return
    if (draft.packs.some((a) => a.manifestUrl === manifestUrl)) return
    setAdding(true)
    setAddError(null)
    try {
      const meta = await fetchPackMeta(manifestUrl)
      hydratedUrls.current.add(manifestUrl)
      const row: ForjaPackRow = {
        manifestUrl,
        name: meta.name,
        ...(meta.version ? { version: meta.version } : {}),
      }
      await commit((prev) => ({ packs: [...prev.packs, row] }))
      setUrl('')
    } catch (e) {
      setAddError(
        e instanceof Error ? e.message : 'Could not load manifest',
      )
    } finally {
      setAdding(false)
    }
  }

  const removePack = (manifestUrl: string) => {
    hydratedUrls.current.delete(manifestUrl)
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
          isSaving={isSaving || adding || resolving}
          savedFlash={savedFlash}
          error={saveError ?? addError}
        />
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
                  <p className="font-medium">
                    {packTitle(pack)}
                    {pack.version?.trim() ? (
                      <span className="ml-2 font-normal text-forja-muted">
                        v{pack.version.trim()}
                      </span>
                    ) : null}
                  </p>
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
                  disabled={controlsLocked || isSaving}
                >
                  <Trash2 className="size-4" />
                </Button>
              </li>
            ))}
          </ul>
        )}
        {resolving ? (
          <p className="pt-2 text-xs text-forja-muted">Loading pack names…</p>
        ) : null}

        <div className="space-y-2 py-4">
          <Label htmlFor="forja-pack-url">Manifest URL</Label>
          <Input
            id="forja-pack-url"
            placeholder="https://…/manifest.json"
            value={url}
            onChange={(e) => {
              setUrl(e.target.value)
              setAddError(null)
            }}
            disabled={controlsLocked || adding}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault()
                void addPack()
              }
            }}
          />
        </div>
        <Button
          type="button"
          variant="secondary"
          onClick={() => void addPack()}
          disabled={controlsLocked || adding || !url.trim()}
        >
          {adding ? 'Loading…' : 'Add pack'}
        </Button>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
