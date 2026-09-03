import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { Layers, Loader2 } from 'lucide-react'
import {
  packRowFromInstallPayload,
  type PluginInstallConfirmPayload,
} from '@/components/plugin-install-confirm-dialog'
import {
  PluginBatchInstallDialog,
  type PluginBatchInstallItem,
} from '@/components/plugin-batch-install-dialog'
import { useAuth } from '@/hooks/use-auth'
import { useForjaSetting } from '@/hooks/use-user-setting'
import { useProfiles } from '@/hooks/use-profiles'
import type { ForjaPluginPackLive } from '@/lib/forja-plugin-catalog'
import {
  clearPluginBatchInstallIntent,
  installPayloadFromPack,
  readPluginBatchInstallIntent,
  rememberPluginBatchInstallIntent,
} from '@/lib/forja-plugin-install'
import { cn } from '@/lib/utils'

type BatchAddToForjaProps = {
  packs: ForjaPluginPackLive[]
  openOnMount?: boolean
  onOpenOnMountHandled?: () => void
  className?: string
}

function selectionFromIntent(
  packs: ForjaPluginPackLive[],
  selections: PluginInstallConfirmPayload[],
): Set<string> {
  const urls = new Set(selections.map((item) => item.manifestUrl.trim()))
  const next = new Set<string>()
  for (const pack of packs) {
    if (urls.has(pack.manifestUrl.trim())) {
      next.add(pack.manifestUrl)
    }
  }
  return next
}

export function BatchAddToForja({
  packs,
  openOnMount,
  onOpenOnMountHandled,
  className,
}: BatchAddToForjaProps) {
  const navigate = useNavigate()
  const { user, loading: authLoading } = useAuth()
  const { activeProfile } = useProfiles()
  const { data, isLoading, save } = useForjaSetting()
  const [dialogOpen, setDialogOpen] = useState(false)
  const [busy, setBusy] = useState(false)
  const [doneFlash, setDoneFlash] = useState(false)
  const [initialSelection, setInitialSelection] = useState<Set<string> | undefined>()

  const installedPacks = data?.payload?.packs ?? []

  useEffect(() => {
    if (!openOnMount) return
    const intent = readPluginBatchInstallIntent()
    if (intent) {
      setInitialSelection(selectionFromIntent(packs, intent.selections))
      setDialogOpen(true)
    } else {
      setInitialSelection(undefined)
      setDialogOpen(true)
    }
    onOpenOnMountHandled?.()
  }, [openOnMount, onOpenOnMountHandled, packs])

  const openDialog = useCallback(() => {
    setInitialSelection(undefined)
    setDialogOpen(true)
  }, [])

  const closeDialog = useCallback(() => {
    setDialogOpen(false)
    setInitialSelection(undefined)
    clearPluginBatchInstallIntent()
  }, [])

  const commitBatch = useCallback(
    async (items: PluginBatchInstallItem[]) => {
      if (items.length === 0) {
        closeDialog()
        return
      }
      setBusy(true)
      try {
        const existing = data?.payload?.packs ?? []
        const seen = new Set(existing.map((pack) => pack.manifestUrl.trim()))
        const rows = [...existing]
        for (const item of items) {
          const row = packRowFromInstallPayload(item)
          if (seen.has(row.manifestUrl)) continue
          seen.add(row.manifestUrl)
          rows.push(row)
        }
        await save({ packs: rows })
        clearPluginBatchInstallIntent()
        setDialogOpen(false)
        setInitialSelection(undefined)
        setDoneFlash(true)
        window.setTimeout(() => setDoneFlash(false), 2500)
      } finally {
        setBusy(false)
      }
    },
    [closeDialog, data?.payload?.packs, save],
  )

  const handleConfirm = useCallback(
    async (items: PluginBatchInstallItem[]) => {
      if (!user) {
        rememberPluginBatchInstallIntent({
          selections: items.map((item) => installPayloadFromPack(item)),
        })
        void navigate({
          to: '/login',
          search: { next: '/plugins?batchInstall=1' },
        })
        return
      }
      if (!activeProfile) {
        rememberPluginBatchInstallIntent({
          selections: items.map((item) => installPayloadFromPack(item)),
        })
        void navigate({ to: '/account/profiles' })
        return
      }
      await commitBatch(items)
    },
    [activeProfile, commitBatch, navigate, user],
  )

  const label = useMemo(() => {
    if (doneFlash) return 'Added to profile'
    if (authLoading || isLoading) return 'Loading…'
    return 'Batch add to Forja'
  }, [authLoading, doneFlash, isLoading])

  return (
    <>
      <button
        type="button"
        data-hover=""
        disabled={authLoading || isLoading || packs.length === 0 || busy}
        onClick={openDialog}
        className={cn(
          'inline-flex shrink-0 items-center justify-center gap-2 rounded-xl border px-4 py-2.5 font-mono-ui text-[10px] font-bold uppercase tracking-[0.12em] transition-colors sm:text-[11px]',
          doneFlash
            ? 'border-forja-green/40 bg-forja-green/15 text-forja-green'
            : 'border-white/15 bg-white/[0.04] text-[rgba(237,230,218,0.7)] hover:border-forja-green/35 hover:text-forja-green',
          (authLoading || isLoading || packs.length === 0 || busy) &&
            'pointer-events-none opacity-60',
          className,
        )}
      >
        {busy || authLoading || isLoading ? (
          <Loader2 className="size-4 animate-spin" />
        ) : (
          <Layers className="size-4" />
        )}
        {label}
      </button>

      <PluginBatchInstallDialog
        open={dialogOpen}
        packs={packs}
        installedPacks={installedPacks}
        initialSelection={initialSelection}
        busy={busy}
        onConfirm={(items) => void handleConfirm(items)}
        onCancel={closeDialog}
      />
    </>
  )
}
