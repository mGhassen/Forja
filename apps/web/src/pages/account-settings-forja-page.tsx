import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import {
  packRowFromInstallPayload,
  PluginInstallConfirmDialog,
  type PluginInstallConfirmPayload,
} from '@/components/plugin-install-confirm-dialog'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SettingsSection } from '@/components/settings-section'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import { useForjaSetting } from '@/hooks/use-user-setting'
import {
  clearPluginInstallIntent,
  isPackInstalled,
  isSafeManifestUrl,
  readPluginInstallIntent,
} from '@/lib/forja-plugin-install'
import {
  emptyForjaPayload,
  type ForjaPackRow,
  type ForjaPayload,
} from '@/lib/sync-domains'
import { Route } from '@/routes/account.settings.forja'

function forjaFromServer(value: unknown): ForjaPayload {
  const payload = value as ForjaPayload | undefined
  return { packs: payload?.packs ?? [] }
}

function packTitle(pack: ForjaPackRow): string {
  const name = pack.name?.trim()
  if (name && name !== pack.manifestUrl) return name
  try {
    const path = new URL(pack.manifestUrl).pathname
    const segment = path.split('/').filter(Boolean).slice(-2, -1)[0]
    if (segment) return segment.replace(/_/g, ' ')
  } catch {
    // ignore
  }
  return 'Plugin pack'
}

export function AccountSettingsForjaPage() {
  const navigate = useNavigate()
  const search = Route.useSearch()
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
  const [installPrompt, setInstallPrompt] =
    useState<PluginInstallConfirmPayload | null>(null)
  const [dialogOpen, setDialogOpen] = useState(false)
  const [dialogMode, setDialogMode] = useState<'add' | 'remove'>('add')

  const pendingFromUrl = useMemo((): PluginInstallConfirmPayload | null => {
    if (!search.manifest || !isSafeManifestUrl(search.manifest)) return null
    return {
      manifestUrl: search.manifest,
      name: search.name,
      version: search.version,
    }
  }, [search.manifest, search.name, search.version])

  useEffect(() => {
    const fromUrl = pendingFromUrl
    const fromSession = fromUrl ? null : readPluginInstallIntent()
    const pending = fromUrl ?? fromSession
    if (!pending?.manifestUrl) return
    setInstallPrompt(pending)
    setDialogMode(search.op === 'remove' ? 'remove' : 'add')
    setDialogOpen(true)
    if (fromSession) clearPluginInstallIntent()
  }, [pendingFromUrl, search.op])

  const alreadyInstalled = installPrompt
    ? isPackInstalled(draft.packs, installPrompt.manifestUrl)
    : false

  const closeInstallDialog = () => {
    setDialogOpen(false)
    setInstallPrompt(null)
    setDialogMode('add')
    clearPluginInstallIntent()
    void navigate({
      to: '/account/settings/forja',
      search: {},
      replace: true,
    })
  }

  const confirmInstall = async () => {
    if (!installPrompt) return
    if (dialogMode === 'remove') {
      try {
        await commit((prev) => ({
          packs: prev.packs.filter(
            (p) => p.manifestUrl !== installPrompt.manifestUrl,
          ),
        }))
        closeInstallDialog()
      } catch {
        // saveError surfaced in footer
      }
      return
    }
    const row = packRowFromInstallPayload(installPrompt)
    if (draft.packs.some((p) => p.manifestUrl === row.manifestUrl)) {
      closeInstallDialog()
      return
    }
    try {
      await commit((prev) => ({ packs: [...prev.packs, row] }))
      closeInstallDialog()
    } catch {
      // saveError surfaced in footer
    }
  }

  const addPack = () => {
    const manifestUrl = url.trim()
    if (!manifestUrl) return
    if (draft.packs.some((a) => a.manifestUrl === manifestUrl)) return
    const row: ForjaPackRow = { manifestUrl, name: manifestUrl }
    void commit((prev) => ({ packs: [...prev.packs, row] }))
    setUrl('')
  }

  const removePack = (pack: ForjaPackRow) => {
    setInstallPrompt({
      manifestUrl: pack.manifestUrl,
      name: pack.name,
      version: pack.version,
    })
    setDialogMode('remove')
    setDialogOpen(true)
  }

  return (
    <>
      <AccountSettingsShell
      title="Plugins"
        description="Forja pack manifests on this profile — same as Settings → Forja Packs in the app. Hub packs contribute tabs under Features after sync."
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
          description="Paste a manifest URL or pick a pack from Community Packs."
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
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="text-red-300 hover:text-red-200"
                    onClick={() => removePack(pack)}
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
              placeholder="https://…/manifest.json"
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

      <PluginInstallConfirmDialog
        open={dialogOpen}
        payload={installPrompt}
        alreadyInstalled={alreadyInstalled}
        mode={dialogMode}
        busy={isSaving}
        onConfirm={() => void confirmInstall()}
        onCancel={closeInstallDialog}
      />
    </>
  )
}
