import { useEffect, useMemo, useState } from 'react'
import { Link } from '@tanstack/react-router'
import { Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import {
  PluginBatchInstallDialog,
  type PluginBatchInstallItem,
} from '@/components/plugin-batch-install-dialog'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { Button } from '@/components/ui/button'
import { SettingsSection } from '@/components/settings-section'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import { useForjaSetting } from '@/hooks/use-user-setting'
import { isPackInstalled } from '@/lib/forja-plugin-install'
import {
  fetchPluginCatalog,
  hydratePluginCatalog,
  isOfficialPluginPack,
  pluginKindLabel,
  type ForjaPluginPackLive,
} from '@/lib/forja-plugin-catalog'
import {
  emptyForjaPayload,
  type ForjaPackRow,
  type ForjaPayload,
} from '@/lib/sync-domains'

function forjaFromServer(value: unknown): ForjaPayload {
  const payload = value as ForjaPayload | undefined
  return { packs: payload?.packs ?? [] }
}

function packTitle(pack: ForjaPackRow, catalog?: ForjaPluginPackLive): string {
  const fromCatalog = catalog?.name?.trim()
  if (fromCatalog) return fromCatalog
  const name = pack.name?.trim()
  if (name && name !== pack.manifestUrl) return name
  return 'Plugin pack'
}

export type AddonPackKindPageProps = {
  title: string
  description: string
  /** Catalog kinds to manage (e.g. live + catalog for Live Sports). */
  kinds: string[]
  sectionLabel: string
  sectionDescription: string
  localNote: string
}

/**
 * Addons → Live Sports / Direct torrent — manage Forja packs that contribute
 * those plugins (same membership as Profile → Forja Packs, filtered by kind).
 */
export function AccountSettingsAddonPackKindPage({
  title,
  description,
  kinds,
  sectionLabel,
  sectionDescription,
  localNote,
}: AddonPackKindPageProps) {
  const kindSet = useMemo(
    () => new Set(kinds.map((k) => k.trim().toLowerCase())),
    [kinds],
  )
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
  const [catalog, setCatalog] = useState<ForjaPluginPackLive[]>([])
  const [officialOpen, setOfficialOpen] = useState(false)

  useEffect(() => {
    let cancelled = false
    void (async () => {
      try {
        const raw = await fetchPluginCatalog()
        if (cancelled) return
        setCatalog(hydratePluginCatalog(raw))
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

  const kindCatalog = useMemo(
    () =>
      catalog.filter((p) => kindSet.has(p.kind.trim().toLowerCase())),
    [catalog, kindSet],
  )

  const installed = useMemo(() => {
    return draft.packs.filter((pack) => {
      const meta = catalogByUrl.get(pack.manifestUrl.trim())
      if (meta) return kindSet.has(meta.kind.trim().toLowerCase())
      // Unknown URL — match path heuristics so custom live/torrent packs still show.
      const url = pack.manifestUrl.toLowerCase()
      if (kindSet.has('live') && url.includes('/plugins/live/')) return true
      if (kindSet.has('catalog') && url.includes('/plugins/catalog/')) return true
      if (kindSet.has('torrent') && url.includes('/plugins/torrent/')) return true
      return false
    })
  }, [draft.packs, catalogByUrl, kindSet])

  const officialMissing = useMemo(
    () =>
      kindCatalog.filter(
        (p) =>
          isOfficialPluginPack(p) &&
          !isPackInstalled(draft.packs, p.manifestUrl),
      ),
    [kindCatalog, draft.packs],
  )

  const removePack = (manifestUrl: string) => {
    void commit((prev) => ({
      packs: prev.packs.filter((p) => p.manifestUrl !== manifestUrl),
    }))
  }

  const confirmOfficial = async (selected: PluginBatchInstallItem[]) => {
    if (!selected.length) {
      setOfficialOpen(false)
      return
    }
    try {
      await commit((prev) => {
        const next = [...prev.packs]
        for (const item of selected) {
          if (isPackInstalled(next, item.manifestUrl)) continue
          next.push({
            manifestUrl: item.manifestUrl,
            name: item.name,
            version: item.version,
          })
        }
        return { packs: next }
      })
      setOfficialOpen(false)
    } catch {
      // saveError in footer
    }
  }

  const kindLabels = kinds.map((k) => pluginKindLabel(k)).join(' / ')

  return (
    <>
      <AccountSettingsShell
        title={title}
        description={description}
        footer={
          <SettingsAutosaveFooter
            isSaving={isSaving}
            savedFlash={savedFlash}
            error={saveError}
          />
        }
      >
        <SettingsSection label={sectionLabel} description={sectionDescription}>
          {installed.length === 0 ? (
            <p className="text-sm text-forja-muted">
              No {kindLabels.toLowerCase()} packs on this profile yet.
            </p>
          ) : (
            <ul className="divide-y divide-forja-border">
              {installed.map((pack) => {
                const meta = catalogByUrl.get(pack.manifestUrl.trim())
                const version =
                  pack.version?.trim() || meta?.version?.trim()
                const pluginCount = meta?.pluginCount
                const kind = meta?.kind
                  ? pluginKindLabel(meta.kind)
                  : kindLabels
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
                        {kind}
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
                      onClick={() => removePack(pack.manifestUrl)}
                      disabled={controlsLocked || isSaving}
                      aria-label={`Remove ${packTitle(pack, meta)}`}
                    >
                      <Trash2 className="size-4" />
                    </Button>
                  </li>
                )
              })}
            </ul>
          )}

          <div className="mt-4 flex flex-wrap gap-2">
            <Button
              type="button"
              variant="secondary"
              disabled={
                controlsLocked || isSaving || officialMissing.length === 0
              }
              onClick={() => setOfficialOpen(true)}
            >
              {officialMissing.length === 0
                ? 'Official packs installed'
                : `Add official (${officialMissing.length})`}
            </Button>
            <Button type="button" variant="ghost" asChild>
              <Link to="/account/settings/forja">All Forja Packs</Link>
            </Button>
            <Button type="button" variant="ghost" asChild>
              <Link to="/plugins">Community Packs</Link>
            </Button>
          </div>
        </SettingsSection>

        <p className="px-0.5 text-xs leading-5 text-forja-muted">{localNote}</p>
      </AccountSettingsShell>

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
