import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import {
  packRowFromInstallPayload,
  type PluginInstallConfirmPayload,
} from '@/components/plugin-install-confirm-dialog'
import type { PluginBatchInstallItem } from '@/components/plugin-batch-install-dialog'
import { useAuth } from '@/hooks/use-auth'
import { useForjaSetting } from '@/hooks/use-user-setting'
import { useProfiles } from '@/hooks/use-profiles'
import type { ForjaPluginPackLive } from '@/lib/forja-plugin-catalog'
import {
  clearPluginBatchInstallIntent,
  installPayloadFromPack,
  readPluginBatchInstallIntent,
  rememberPluginBatchInstallIntent,
  tryOpenForjaBatchInstallDeepLink,
} from '@/lib/forja-plugin-install'

export function selectionFromBatchIntent(
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

type UsePluginBatchInstallOptions = {
  catalogPacks: ForjaPluginPackLive[]
  openOnMount?: boolean
  onOpenOnMountHandled?: () => void
}

export function usePluginBatchInstall({
  catalogPacks,
  openOnMount,
  onOpenOnMountHandled,
}: UsePluginBatchInstallOptions) {
  const navigate = useNavigate()
  const { user } = useAuth()
  const { activeProfile } = useProfiles()
  const { data, save } = useForjaSetting()
  const [dialogOpen, setDialogOpen] = useState(false)
  const [dialogPacks, setDialogPacks] = useState<ForjaPluginPackLive[]>([])
  const [busy, setBusy] = useState(false)
  const [initialSelection, setInitialSelection] = useState<
    Set<string> | undefined
  >()

  const installedPacks = data?.payload?.packs ?? []

  useEffect(() => {
    if (!openOnMount) return
    const intent = readPluginBatchInstallIntent()
    if (intent) {
      setInitialSelection(selectionFromBatchIntent(catalogPacks, intent.selections))
      setDialogPacks(catalogPacks)
    } else {
      setInitialSelection(undefined)
      setDialogPacks(catalogPacks)
    }
    setDialogOpen(true)
    onOpenOnMountHandled?.()
  }, [openOnMount, onOpenOnMountHandled, catalogPacks])

  const closeDialog = useCallback(() => {
    setDialogOpen(false)
    setDialogPacks([])
    setInitialSelection(undefined)
    clearPluginBatchInstallIntent()
  }, [])

  const openDialog = useCallback((packs: ForjaPluginPackLive[]) => {
    if (packs.length === 0) return
    setDialogPacks(packs)
    setInitialSelection(
      new Set(packs.map((pack) => pack.manifestUrl.trim())),
    )
    setDialogOpen(true)
  }, [])

  const commitBatch = useCallback(
    async (items: PluginBatchInstallItem[]) => {
      if (items.length === 0) {
        closeDialog()
        return false
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
        setDialogPacks([])
        setInitialSelection(undefined)
        return true
      } finally {
        setBusy(false)
      }
    },
    [closeDialog, data?.payload?.packs, save],
  )

  const confirmBatch = useCallback(
    async (items: PluginBatchInstallItem[]) => {
      if (items.length === 0) return false

      const opened = await tryOpenForjaBatchInstallDeepLink(
        items.map((item) => installPayloadFromPack(item)),
      )
      if (opened) {
        clearPluginBatchInstallIntent()
        setDialogOpen(false)
        setDialogPacks([])
        setInitialSelection(undefined)
        return true
      }

      if (!user) {
        rememberPluginBatchInstallIntent({
          selections: items.map((item) => installPayloadFromPack(item)),
        })
        void navigate({
          to: '/login',
          search: { next: '/plugins?batchInstall=1' },
        })
        return false
      }
      if (!activeProfile) {
        rememberPluginBatchInstallIntent({
          selections: items.map((item) => installPayloadFromPack(item)),
        })
        void navigate({ to: '/account/profiles' })
        return false
      }
      return commitBatch(items)
    },
    [activeProfile, commitBatch, navigate, user],
  )

  return {
    dialogOpen,
    dialogPacks,
    installedPacks,
    initialSelection,
    busy,
    openDialog,
    closeDialog,
    confirmBatch,
  }
}
