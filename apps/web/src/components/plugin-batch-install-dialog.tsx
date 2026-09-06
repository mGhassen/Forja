import { useEffect, useMemo, useRef, useState } from 'react'
import { Loader2, Puzzle, Search, X } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { LiquidGlass } from '@/components/liquid-glass'
import type { ForjaPluginPackLive } from '@/lib/forja-plugin-catalog'
import {
  isOfficialPluginPack,
  packAuthorLabel,
  pluginKindLabel,
} from '@/lib/forja-plugin-catalog'
import { isPackInstalled } from '@/lib/forja-plugin-install'
import type { ForjaPackRow } from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

export type PluginBatchInstallItem = {
  manifestUrl: string
  name?: string
  version?: string
}

type PluginBatchInstallDialogProps = {
  open: boolean
  packs: ForjaPluginPackLive[]
  installedPacks: ForjaPackRow[]
  initialSelection?: Set<string>
  busy?: boolean
  onConfirm: (selected: PluginBatchInstallItem[]) => void
  onCancel: () => void
}

export function PluginBatchInstallDialog({
  open,
  packs,
  installedPacks,
  initialSelection,
  busy,
  onConfirm,
  onCancel,
}: PluginBatchInstallDialogProps) {
  const panelRef = useRef<HTMLDivElement>(null)
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState<Set<string>>(
    () => initialSelection ?? new Set(),
  )

  useEffect(() => {
    if (!open) return
    setQuery('')
    setSelected(initialSelection ?? new Set())
  }, [open, packs, installedPacks, initialSelection])

  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onCancel()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onCancel])

  useEffect(() => {
    if (!open) return
    panelRef.current?.focus()
  }, [open])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return packs
    return packs.filter(
      (pack) =>
        pack.name.toLowerCase().includes(q) ||
        pack.description.toLowerCase().includes(q) ||
        packAuthorLabel(pack)?.toLowerCase().includes(q) ||
        pluginKindLabel(pack.kind).toLowerCase().includes(q) ||
        (pack.tags ?? []).some((tag) => tag.toLowerCase().includes(q)),
    )
  }, [packs, query])

  const installable = useMemo(
    () =>
      filtered.filter(
        (pack) => !isPackInstalled(installedPacks, pack.manifestUrl),
      ),
    [filtered, installedPacks],
  )

  const selectedNewCount = useMemo(
    () =>
      packs.filter(
        (pack) =>
          selected.has(pack.manifestUrl) &&
          !isPackInstalled(installedPacks, pack.manifestUrl),
      ).length,
    [packs, selected, installedPacks],
  )

  const allInstallableSelected =
    installable.length > 0 &&
    installable.every((pack) => selected.has(pack.manifestUrl))

  function toggle(manifestUrl: string, installed: boolean) {
    if (installed) return
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(manifestUrl)) next.delete(manifestUrl)
      else next.add(manifestUrl)
      return next
    })
  }

  function selectAllNew() {
    setSelected((prev) => {
      const next = new Set(prev)
      for (const pack of installable) next.add(pack.manifestUrl)
      return next
    })
  }

  function clearNew() {
    setSelected((prev) => {
      const next = new Set(prev)
      for (const pack of installable) next.delete(pack.manifestUrl)
      return next
    })
  }

  function handleConfirm() {
    const items: PluginBatchInstallItem[] = []
    for (const pack of packs) {
      if (
        !selected.has(pack.manifestUrl) ||
        isPackInstalled(installedPacks, pack.manifestUrl)
      ) {
        continue
      }
      items.push({
        manifestUrl: pack.manifestUrl,
        name: pack.name,
        version: pack.version,
      })
    }
    onConfirm(items)
  }

  if (!open) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center p-4 sm:items-center"
      role="presentation"
    >
      <button
        type="button"
        className="absolute inset-0 bg-black/65 backdrop-blur-sm"
        aria-label="Dismiss"
        onClick={onCancel}
      />
      <div
        ref={panelRef}
        tabIndex={-1}
        role="dialog"
        aria-modal="true"
        aria-labelledby="plugin-batch-install-title"
        className="relative flex max-h-[min(90vh,720px)] w-full max-w-2xl flex-col outline-none"
      >
        <LiquidGlass className="flex max-h-[inherit] flex-col border-white/15 p-0 shadow-2xl">
          <div className="flex items-start justify-between gap-3 border-b border-white/10 px-5 py-4">
            <div className="flex min-w-0 items-start gap-3">
              <div className="flex size-9 shrink-0 items-center justify-center rounded-lg border border-forja-green/25 bg-forja-green/10 text-forja-green">
                <Puzzle className="size-4" aria-hidden />
              </div>
              <div className="min-w-0">
                <p className="font-mono-ui text-[10px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.45)]">
                  Batch install
                </p>
                <h2
                  id="plugin-batch-install-title"
                  className="font-medium text-[#EDE6DA]"
                >
                  Add packs to your profile
                </h2>
                <p className="mt-1 text-xs text-[rgba(237,230,218,0.5)]">
                  Choose which packs to sync — the app installs them on next
                  sign-in.
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={onCancel}
              className="flex size-8 shrink-0 items-center justify-center rounded-lg text-[rgba(237,230,218,0.5)] hover:bg-white/8 hover:text-[#EDE6DA]"
              aria-label="Close"
            >
              <X className="size-4" />
            </button>
          </div>

          <div className="space-y-3 border-b border-white/10 px-5 py-3">
            <div className="relative">
              <Search
                className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-[rgba(237,230,218,0.35)]"
                aria-hidden
              />
              <input
                type="search"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Filter packs…"
                className="h-9 w-full rounded-lg border border-white/10 bg-white/[0.04] pl-9 pr-3 text-sm text-[#EDE6DA] placeholder:text-[rgba(237,230,218,0.35)] outline-none focus:border-forja-green/40 focus:ring-1 focus:ring-forja-green/25"
              />
            </div>
            <div className="flex flex-wrap items-center justify-between gap-2">
              <p className="font-mono-ui text-[10px] uppercase tracking-wider text-[rgba(237,230,218,0.4)]">
                {selectedNewCount} to add · {packs.length} total
              </p>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={selectAllNew}
                  disabled={allInstallableSelected || installable.length === 0}
                  className="font-mono-ui text-[10px] uppercase tracking-wider text-forja-green hover:text-[#EDE6DA] disabled:opacity-40"
                >
                  Select all new
                </button>
                <span className="text-[rgba(237,230,218,0.25)]">·</span>
                <button
                  type="button"
                  onClick={clearNew}
                  disabled={selectedNewCount === 0}
                  className="font-mono-ui text-[10px] uppercase tracking-wider text-[rgba(237,230,218,0.5)] hover:text-[#EDE6DA] disabled:opacity-40"
                >
                  Clear
                </button>
              </div>
            </div>
          </div>

          <div className="min-h-0 flex-1 overflow-y-auto px-2 py-2">
            {filtered.length === 0 ? (
              <p className="px-3 py-8 text-center text-sm text-[rgba(237,230,218,0.45)]">
                No packs match your filter.
              </p>
            ) : (
              <ul className="divide-y divide-white/[0.06]">
                {filtered.map((pack) => {
                  const installed = isPackInstalled(
                    installedPacks,
                    pack.manifestUrl,
                  )
                  const checked = installed || selected.has(pack.manifestUrl)
                  const official = isOfficialPluginPack(pack)
                  const author = packAuthorLabel(pack)

                  return (
                    <li key={pack.id}>
                      <label
                        className={cn(
                          'flex cursor-pointer items-start gap-3 rounded-lg px-3 py-2.5 transition-colors',
                          installed
                            ? 'cursor-default opacity-70'
                            : 'hover:bg-white/[0.04]',
                          checked &&
                            !installed &&
                            'bg-forja-green/[0.06]',
                        )}
                      >
                        <input
                          type="checkbox"
                          checked={checked}
                          disabled={installed || busy}
                          onChange={() => toggle(pack.manifestUrl, installed)}
                          className="mt-0.5 size-4 shrink-0 accent-forja-green"
                        />
                        <div className="min-w-0 flex-1">
                          <div className="flex flex-wrap items-center gap-1.5">
                            <span className="font-medium text-[#EDE6DA]">
                              {pack.name}
                            </span>
                            {official ? (
                              <span className="rounded border border-forja-green/35 bg-forja-green/10 px-1.5 py-px font-mono-ui text-[8px] uppercase tracking-wider text-forja-green">
                                Official
                              </span>
                            ) : null}
                            {installed ? (
                              <span className="rounded border border-white/15 bg-white/8 px-1.5 py-px font-mono-ui text-[8px] uppercase tracking-wider text-[rgba(237,230,218,0.55)]">
                                Added
                              </span>
                            ) : null}
                          </div>
                          <p className="mt-0.5 text-xs text-[rgba(237,230,218,0.5)]">
                            {pluginKindLabel(pack.kind)}
                            {author ? ` · ${author}` : ''}
                            {pack.version ? ` · v${pack.version}` : ''}
                          </p>
                        </div>
                      </label>
                    </li>
                  )
                })}
              </ul>
            )}
          </div>

          <div className="flex flex-col-reverse gap-2 border-t border-white/10 px-5 py-4 sm:flex-row sm:justify-end">
            <Button
              type="button"
              variant="ghost"
              className="text-[rgba(237,230,218,0.65)]"
              onClick={onCancel}
              disabled={busy}
            >
              Cancel
            </Button>
            <Button
              type="button"
              className="bg-forja-green text-[#0B0A0A] hover:bg-forja-green/90"
              onClick={handleConfirm}
              disabled={busy || selectedNewCount === 0}
            >
              {busy ? (
                <>
                  <Loader2 className="size-4 animate-spin" />
                  Adding…
                </>
              ) : selectedNewCount === 1 ? (
                'Add 1 pack'
              ) : (
                `Add ${selectedNewCount} packs`
              )}
            </Button>
          </div>
        </LiquidGlass>
      </div>
    </div>
  )
}
