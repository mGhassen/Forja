import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { Package, Trash2, Users } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import {
  packRowFromInstallPayload,
  PluginInstallConfirmDialog,
  type PluginInstallConfirmPayload,
} from '@/components/plugin-install-confirm-dialog'
import {
  PluginBatchInstallDialog,
  type PluginBatchInstallItem,
} from '@/components/plugin-batch-install-dialog'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SettingsSection } from '@/components/settings-section'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import { useForjaSetting } from '@/hooks/use-user-setting'
import {
  clearPluginInstallIntent,
  ensurePackVersions,
  fetchManifestMeta,
  isPackInstalled,
  isSafeManifestUrl,
  readPluginInstallIntent,
} from '@/lib/forja-plugin-install'
import {
  isOfficialPluginPack,
  loadLivePluginCatalog,
  pluginKindLabel,
  type ForjaPluginPackLive,
} from '@/lib/forja-plugin-catalog'
import {
  emptyForjaPayload,
  type ForjaPackRow,
  type ForjaPayload,
} from '@/lib/sync-domains'
import { cn } from '@/lib/utils'
import { Route } from '@/routes/account.settings.forja'

/** Same bucket order as app Settings → Forja Packs. */
const PACK_KIND_ORDER = [
  'providers',
  'live',
  'catalog',
  'torrent',
  'iptv',
  'hubs',
  'other',
] as const

function forjaFromServer(value: unknown): ForjaPayload {
  const payload = value as ForjaPayload | undefined
  return {
    packs: payload?.packs ?? [],
    ...(payload?.onboarded === true ? { onboarded: true as const } : {}),
  }
}

function packTitle(pack: ForjaPackRow, catalog?: ForjaPluginPackLive): string {
  const fromCatalog = catalog?.name?.trim()
  if (fromCatalog) return fromCatalog
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

function packKindKey(
  pack: ForjaPackRow,
  byUrl: Map<string, ForjaPluginPackLive>,
): string {
  const hit = byUrl.get(pack.manifestUrl.trim())
  const kind = hit?.kind?.trim().toLowerCase()
  if (kind) return kind
  return 'other'
}

function groupInstalledPacks(
  packs: ForjaPackRow[],
  catalog: ForjaPluginPackLive[],
): Array<{ kind: string; label: string; packs: ForjaPackRow[] }> {
  const byUrl = new Map(
    catalog.map((p) => [p.manifestUrl.trim(), p] as const),
  )
  const byKind = new Map<string, ForjaPackRow[]>()
  for (const pack of packs) {
    const kind = packKindKey(pack, byUrl)
    const list = byKind.get(kind) ?? []
    list.push(pack)
    byKind.set(kind, list)
  }
  const orderedKinds = [
    ...PACK_KIND_ORDER.filter((k) => byKind.has(k)),
    ...[...byKind.keys()].filter(
      (k) => !(PACK_KIND_ORDER as readonly string[]).includes(k),
    ),
  ]
  return orderedKinds.map((kind) => ({
    kind,
    label: pluginKindLabel(kind),
    packs: byKind.get(kind) ?? [],
  }))
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
  const [catalog, setCatalog] = useState<ForjaPluginPackLive[]>([])
  const [officialOpen, setOfficialOpen] = useState(false)

  useEffect(() => {
    let cancelled = false
    void (async () => {
      try {
        const live = await loadLivePluginCatalog()
        if (cancelled) return
        setCatalog(live)
      } catch {
        if (!cancelled) setCatalog([])
      }
    })()
    return () => {
      cancelled = true
    }
  }, [])

  const catalogByUrl = useMemo(
    () => new Map(catalog.map((p) => [p.manifestUrl.trim(), p] as const)),
    [catalog],
  )

  const grouped = useMemo(
    () => groupInstalledPacks(draft.packs, catalog),
    [draft.packs, catalog],
  )

  const officialMissing = useMemo(
    () =>
      catalog.filter(
        (p) =>
          isOfficialPluginPack(p) &&
          !isPackInstalled(draft.packs, p.manifestUrl),
      ),
    [catalog, draft.packs],
  )

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
          ...prev,
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
    let row = packRowFromInstallPayload(installPrompt)
    if (draft.packs.some((p) => p.manifestUrl === row.manifestUrl)) {
      closeInstallDialog()
      return
    }
    if (!row.version?.trim()) {
      try {
        const meta = await fetchManifestMeta(row.manifestUrl)
        if (meta.version) row = { ...row, version: meta.version }
        if ((!row.name || row.name === row.manifestUrl) && meta.name) {
          row = { ...row, name: meta.name }
        }
      } catch {
        // keep row without version if fetch fails
      }
    }
    try {
      const versioned = await ensurePackVersions([...draft.packs, row])
      const addUrl = row.manifestUrl
      await commit((prev) => {
        if (isPackInstalled(prev.packs, addUrl)) return prev
        const byUrl = new Map(
          versioned.map((p) => [p.manifestUrl.trim(), p] as const),
        )
        const packs = prev.packs.map((p) => {
          const hit = byUrl.get(p.manifestUrl.trim())
          if (hit?.version && !p.version?.trim()) {
            return { ...p, version: hit.version }
          }
          return p
        })
        const add = byUrl.get(addUrl.trim()) ?? row
        return { ...prev, packs: [...packs, add] }
      })
      closeInstallDialog()
    } catch {
      // saveError surfaced in footer
    }
  }

  const addPack = async () => {
    const manifestUrl = url.trim()
    if (!manifestUrl) return
    if (draft.packs.some((a) => a.manifestUrl === manifestUrl)) return
    const catalogHit = catalogByUrl.get(manifestUrl)
    let row: ForjaPackRow = {
      manifestUrl,
      name: catalogHit?.name ?? manifestUrl,
      version: catalogHit?.version,
    }
    if (!row.version?.trim()) {
      try {
        const meta = await fetchManifestMeta(manifestUrl)
        if (meta.version) row = { ...row, version: meta.version }
        if ((!row.name || row.name === manifestUrl) && meta.name) {
          row = { ...row, name: meta.name }
        }
      } catch {
        // save without version if fetch fails
      }
    }
    const versioned = await ensurePackVersions([...draft.packs, row])
    const addUrl = manifestUrl
    await commit((prev) => {
      if (isPackInstalled(prev.packs, addUrl)) return prev
      const byUrl = new Map(
        versioned.map((p) => [p.manifestUrl.trim(), p] as const),
      )
      const packs = prev.packs.map((p) => {
        const hit = byUrl.get(p.manifestUrl.trim())
        if (hit?.version && !p.version?.trim()) {
          return { ...p, version: hit.version }
        }
        return p
      })
      const add = byUrl.get(addUrl.trim()) ?? row
      return { ...prev, packs: [...packs, add] }
    })
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

  const confirmOfficial = async (selected: PluginBatchInstallItem[]) => {
    if (!selected.length) {
      setOfficialOpen(false)
      return
    }
    try {
      const additions: ForjaPackRow[] = selected.map((item) => ({
        manifestUrl: item.manifestUrl,
        name: item.name,
        version: item.version,
      }))
      const versioned = await ensurePackVersions([
        ...draft.packs,
        ...additions,
      ])
      const addUrls = new Set(
        additions.map((a) => a.manifestUrl.trim()).filter(Boolean),
      )
      await commit((prev) => {
        const byUrl = new Map(
          versioned.map((p) => [p.manifestUrl.trim(), p] as const),
        )
        const packs = prev.packs.map((p) => {
          const hit = byUrl.get(p.manifestUrl.trim())
          if (hit?.version && !p.version?.trim()) {
            return { ...p, version: hit.version }
          }
          return p
        })
        for (const url of addUrls) {
          if (isPackInstalled(packs, url)) continue
          const add = byUrl.get(url)
          if (add) packs.push(add)
        }
        return { ...prev, packs }
      })
      setOfficialOpen(false)
    } catch {
      // saveError surfaced in footer
    }
  }

  return (
    <>
      <AccountSettingsShell
        title="Forja Packs"
        description="Add pack manifests to this profile. The Forja app downloads and installs the scripts. Hub packs unlock tabs under Features. IPTV portals stay under Addons → IPTV."
        footer={
          <SettingsAutosaveFooter
            isSaving={isSaving}
            savedFlash={savedFlash}
            error={saveError}
          />
        }
      >
        <div className="mb-8 grid gap-3 sm:grid-cols-2">
          <button
            type="button"
            disabled={controlsLocked || isSaving || officialMissing.length === 0}
            onClick={() => setOfficialOpen(true)}
            className={cn(
              'flex items-start gap-3 rounded-none border border-forja-border bg-white/3 px-4 py-4 text-left transition',
              'hover:border-forja-green/40 hover:bg-forja-green/5',
              'disabled:cursor-not-allowed disabled:opacity-50',
            )}
          >
            <Package className="mt-0.5 size-5 shrink-0 text-forja-green" />
            <span>
              <span className="block text-sm font-semibold text-forja-text">
                Official packs
              </span>
              <span className="mt-1 block text-xs text-forja-muted">
                {officialMissing.length === 0
                  ? 'All ForjaHQ packs are on this profile'
                  : `Add missing ForjaHQ packs (${officialMissing.length})`}
              </span>
            </span>
          </button>
          <Link
            to="/plugins"
            className={cn(
              'flex items-start gap-3 rounded-none border border-forja-border bg-white/3 px-4 py-4 text-left transition',
              'hover:border-forja-green/40 hover:bg-forja-green/5',
            )}
          >
            <Users className="mt-0.5 size-5 shrink-0 text-forja-green" />
            <span>
              <span className="block text-sm font-semibold text-forja-text">
                Community Packs
              </span>
              <span className="mt-1 block text-xs text-forja-muted">
                Browse packs on the web catalog
              </span>
            </span>
          </Link>
        </div>

        <SettingsSection
          label="Packs on this profile"
          description="Same groups as the app (Providers, Live, Catalog, IPTV, Hubs…). Adding here only updates membership — open Forja on a device to download scripts. Remove drops the pack from this profile; devices uninstall on the next sync."
        >
          {draft.packs.length === 0 ? (
            <p className="text-sm text-forja-muted">No packs on this profile yet.</p>
          ) : (
            <div className="space-y-6">
              {grouped.map((group) => (
                <div key={group.kind}>
                  <p className="mb-1 px-0.5 text-[11px] font-bold uppercase tracking-[0.14em] text-forja-muted">
                    {group.label}
                  </p>
                  <ul className="divide-y divide-forja-border">
                    {group.packs.map((pack) => {
                      const meta = catalogByUrl.get(pack.manifestUrl.trim())
                      const version =
                        pack.version?.trim() || meta?.version?.trim()
                      const pluginCount = meta?.pluginCount
                      return (
                        <li
                          key={pack.manifestUrl}
                          className="flex min-h-14.5 items-center justify-between gap-3 px-0.5 py-3"
                        >
                          <div className="min-w-0 flex-1">
                            <p className="font-medium text-forja-text">
                              {packTitle(pack, meta)}
                            </p>
                            <p className="mt-0.5 truncate text-xs text-forja-muted">
                              {pack.manifestUrl}
                            </p>
                            <p className="mt-1 text-[11px] text-forja-muted">
                              {group.label}
                              {pluginCount != null
                                ? ` · ${pluginCount} plugin${pluginCount === 1 ? '' : 's'}`
                                : ''}
                              {version ? ` · v${version}` : ''}
                            </p>
                          </div>
                          <Button
                            type="button"
                            variant="ghost"
                            size="sm"
                            className="shrink-0 text-red-300 hover:text-red-200"
                            onClick={() => removePack(pack)}
                            disabled={controlsLocked || isSaving}
                            aria-label={`Remove ${packTitle(pack, meta)}`}
                          >
                            <Trash2 className="size-4" />
                          </Button>
                        </li>
                      )
                    })}
                  </ul>
                </div>
              ))}
            </div>
          )}

          <div className="space-y-2 py-4">
            <Label htmlFor="forja-pack-url">Add pack</Label>
            <Input
              id="forja-pack-url"
              placeholder="https://…/manifest.json"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              disabled={controlsLocked}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault()
                  void addPack()
                }
              }}
            />
          </div>
          <div className="flex justify-end">
            <Button
              type="button"
              variant="secondary"
              onClick={() => void addPack()}
              disabled={controlsLocked || !url.trim()}
            >
              Add to profile
            </Button>
          </div>
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

      <PluginBatchInstallDialog
        open={officialOpen}
        packs={officialMissing}
        installedPacks={draft.packs}
        busy={isSaving}
        onConfirm={(selected) => void confirmOfficial(selected)}
        onCancel={() => setOfficialOpen(false)}
      />
    </>
  )
}
