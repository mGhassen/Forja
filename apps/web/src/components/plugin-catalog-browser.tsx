import { useEffect, useMemo, useRef, useState, type MouseEvent } from 'react'
import {
  Check,
  ChevronLeft,
  ChevronRight,
  Plus,
  Puzzle,
  Search,
  X,
} from 'lucide-react'
import { AddToForjaButton } from '@/components/add-to-forja-button'
import { PluginBatchInstallDialog } from '@/components/plugin-batch-install-dialog'
import { Button } from '@/components/ui/button'
import { useAuth } from '@/hooks/use-auth'
import { useForjaSetting } from '@/hooks/use-user-setting'
import { usePluginBatchInstall } from '@/hooks/use-plugin-batch-install'
import type { ForjaPluginPackLive } from '@/lib/forja-plugin-catalog'
import {
  isOfficialPluginPack,
  packAuthorLabel,
  packHasTag,
  pluginKindLabel,
  pluginKindsFromPacks,
  pluginTagLabel,
  pluginTagsFromPacks,
} from '@/lib/forja-plugin-catalog'
import {
  isPackInstalled,
  tryOpenForjaBatchInstallDeepLink,
} from '@/lib/forja-plugin-install'
import { cn } from '@/lib/utils'

const PAGE_SIZE = 10
/** Shared catalog pane height — list + detail fill the same column. */
const CATALOG_PANE_HEIGHT_CLASS = 'h-[min(42rem,78vh)]'

function paginate<T>(items: T[], page: number) {
  const totalPages = Math.max(1, Math.ceil(items.length / PAGE_SIZE))
  const safePage = Math.min(Math.max(1, page), totalPages)
  const start = (safePage - 1) * PAGE_SIZE
  return {
    page: safePage,
    totalPages,
    start: items.length === 0 ? 0 : start + 1,
    end: Math.min(start + PAGE_SIZE, items.length),
    items: items.slice(start, start + PAGE_SIZE),
  }
}

function OfficialBadge({ compact = false }: { compact?: boolean }) {
  return (
    <span
      className={cn(
        'shrink-0 rounded-md border border-forja-green/35 bg-forja-green/10 font-mono-ui uppercase tracking-wider text-forja-green',
        compact
          ? 'px-1.5 py-px text-[8px]'
          : 'px-2 py-0.5 text-[9px]',
      )}
    >
      Official
    </span>
  )
}

function PluginDetailPanel({
  pack,
  onClose,
}: {
  pack: ForjaPluginPackLive
  onClose?: () => void
}) {
  const official = isOfficialPluginPack(pack)
  const author = packAuthorLabel(pack)
  const { user } = useAuth()
  const { data } = useForjaSetting()
  const onProfile =
    Boolean(user) &&
    isPackInstalled(data?.payload?.packs ?? [], pack.manifestUrl)

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-start justify-between gap-3 border-b border-white/10 px-4 py-4 sm:px-5">
        <div className="flex min-w-0 items-start gap-3">
          <Puzzle
            className="mt-0.5 size-4 shrink-0 text-[rgba(237,230,218,0.55)]"
            strokeWidth={2}
            aria-hidden
          />
          <div className="min-w-0">
            {author ? (
              <p className="truncate font-mono-ui text-[10px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.45)]">
                {author}
              </p>
            ) : null}
            <h2 className="truncate font-medium text-[#EDE6DA]">
              {pack.name}
            </h2>
            <p className="mt-1 truncate text-xs text-[rgba(237,230,218,0.5)]">
              {pluginKindLabel(pack.kind)}
              {pack.pluginCount != null ? ` · ${pack.pluginCount} plugins` : ''}
            </p>
          </div>
        </div>
        <div className="flex shrink-0 flex-wrap items-center justify-end gap-1.5">
          {official ? <OfficialBadge /> : null}
          {onProfile ? (
            <span className="shrink-0 rounded-md border border-forja-green/35 bg-forja-green/10 px-2 py-0.5 font-mono-ui text-[9px] uppercase tracking-wider text-forja-green">
              On profile
            </span>
          ) : null}
          {pack.version ? (
            <span className="font-mono-ui text-[10px] text-[rgba(237,230,218,0.45)]">
              v{pack.version}
            </span>
          ) : null}
          {onClose ? (
            <button
              type="button"
              onClick={onClose}
              className="flex size-8 items-center justify-center rounded-lg text-[rgba(237,230,218,0.5)] hover:bg-white/8 hover:text-[#EDE6DA]"
              aria-label="Close details"
            >
              <X className="size-4" />
            </button>
          ) : null}
        </div>
      </div>

      <div className="flex-1 space-y-4 overflow-y-auto px-4 py-4 sm:px-5">
        <p className="text-sm leading-relaxed text-[rgba(237,230,218,0.62)]">
          {pack.description}
        </p>

        {(pack.tags?.length ?? 0) > 0 ? (
          <div className="flex flex-wrap gap-1.5">
            {pack.tags!.map((tag) => (
              <span
                key={tag}
                className="rounded-md border border-white/10 bg-white/[0.03] px-2 py-0.5 font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.55)]"
              >
                {pluginTagLabel(tag)}
              </span>
            ))}
          </div>
        ) : null}

        <dl className="grid grid-cols-2 gap-x-6 gap-y-3 text-sm">
          {pack.pluginCount != null ? (
            <div>
              <dt className="font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.4)]">
                Plugins
              </dt>
              <dd className="mt-0.5 text-[#EDE6DA]">{pack.pluginCount}</dd>
            </div>
          ) : null}
          {author ? (
            <div className="min-w-0">
              <dt className="font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.4)]">
                Author
              </dt>
              <dd className="mt-0.5 truncate text-[#EDE6DA]" title={author}>
                {author}
              </dd>
            </div>
          ) : null}
        </dl>
      </div>

      <div className="border-t border-white/10 p-4 sm:p-5">
        <AddToForjaButton pack={pack} variant="magnet" className="w-full" />
      </div>
    </div>
  )
}

function PluginListRow({
  pack,
  focused,
  checked,
  onRowClick,
  onToggleCheck,
}: {
  pack: ForjaPluginPackLive
  focused: boolean
  checked: boolean
  onRowClick: (event: MouseEvent<HTMLElement>) => void
  onToggleCheck: () => void
}) {
  const official = isOfficialPluginPack(pack)
  const author = packAuthorLabel(pack)

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={onRowClick}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          onRowClick(e as unknown as MouseEvent<HTMLElement>)
        }
      }}
      className={cn(
        'flex w-full cursor-pointer items-center gap-3 border-b border-white/[0.06] px-3 py-2.5 text-left transition-colors sm:px-4',
        checked
          ? 'bg-forja-green/15'
          : focused
            ? 'bg-forja-green/10'
            : 'hover:bg-white/[0.04]',
      )}
    >
      <button
        type="button"
        aria-label={checked ? `Deselect ${pack.name}` : `Select ${pack.name}`}
        aria-checked={checked}
        role="checkbox"
        onClick={(e) => {
          e.stopPropagation()
          onToggleCheck()
        }}
        className={cn(
          'flex size-5 shrink-0 items-center justify-center rounded border transition-colors',
          checked
            ? 'border-forja-green bg-forja-green text-[#0B0A0A]'
            : 'border-white/25 bg-transparent hover:border-forja-green/60',
        )}
      >
        {checked ? <Check className="size-3 stroke-[3]" /> : null}
      </button>
      <Puzzle
        className={cn(
          'size-4 shrink-0',
          focused || checked
            ? 'text-forja-green'
            : 'text-[rgba(237,230,218,0.45)]',
        )}
        strokeWidth={2}
        aria-hidden
      />
      <div className="min-w-0 flex-1">
        <div className="flex min-w-0 items-center gap-1.5">
          <span className="truncate font-mono-ui text-[10px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.45)]">
            {author ?? 'Community'}
          </span>
          {official ? <OfficialBadge compact /> : null}
        </div>
        <p className="truncate text-sm font-medium text-[#EDE6DA]">
          {pack.name}
        </p>
        {(pack.tags?.length ?? 0) > 0 ? (
          <p className="mt-0.5 truncate font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.35)]">
            {pack.tags!.map((t) => pluginTagLabel(t)).join(' · ')}
          </p>
        ) : null}
      </div>
      {pack.version ? (
        <span className="shrink-0 font-mono-ui text-[10px] text-[rgba(237,230,218,0.35)]">
          v{pack.version}
        </span>
      ) : null}
    </div>
  )
}

type PluginCatalogBrowserProps = {
  packs: ForjaPluginPackLive[]
  isLoading?: boolean
  error?: Error | null
  batchInstallOnMount?: boolean
  onBatchInstallOnMountHandled?: () => void
}

export function PluginCatalogBrowser({
  packs,
  isLoading,
  error,
  batchInstallOnMount,
  onBatchInstallOnMountHandled,
}: PluginCatalogBrowserProps) {
  const [query, setQuery] = useState('')
  const [kindFilter, setKindFilter] = useState<string | 'all'>('all')
  const [tagFilter, setTagFilter] = useState<string | 'all'>('all')
  const [page, setPage] = useState(1)
  /** Detail panel — only set by plain row click; cleared on multi-select. */
  const [detailId, setDetailId] = useState<string | null>(null)
  const [checkedIds, setCheckedIds] = useState<Set<string>>(() => new Set())
  const [mobileDetailOpen, setMobileDetailOpen] = useState(false)
  const anchorIdRef = useRef<string | null>(null)

  const batchInstall = usePluginBatchInstall({
    catalogPacks: packs,
    openOnMount: batchInstallOnMount,
    onOpenOnMountHandled: onBatchInstallOnMountHandled,
  })

  const filtered = useMemo(() => {
    let list = [...packs]
    if (kindFilter !== 'all') {
      list = list.filter((p) => p.kind === kindFilter)
    }
    if (tagFilter !== 'all') {
      list = list.filter((p) => packHasTag(p, tagFilter))
    }
    const q = query.trim().toLowerCase()
    if (q) {
      list = list.filter(
        (p) =>
          p.name.toLowerCase().includes(q) ||
          p.description.toLowerCase().includes(q) ||
          p.author?.toLowerCase().includes(q) ||
          pluginKindLabel(p.kind).toLowerCase().includes(q) ||
          p.id.toLowerCase().includes(q) ||
          (p.tags ?? []).some(
            (tag) =>
              tag.toLowerCase().includes(q) ||
              pluginTagLabel(tag).toLowerCase().includes(q),
          ),
      )
    }
    return list.sort((a, b) => a.name.localeCompare(b.name))
  }, [packs, kindFilter, tagFilter, query])

  const pageSlice = useMemo(
    () => paginate(filtered, page),
    [filtered, page],
  )

  const detail =
    detailId != null
      ? (filtered.find((p) => p.id === detailId) ?? null)
      : null

  const checkedPacks = useMemo(
    () => filtered.filter((pack) => checkedIds.has(pack.id)),
    [checkedIds, filtered],
  )

  const showMultiAdd = checkedIds.size >= 2
  const multiSelectMode = checkedIds.size >= 2
  const showDetail = Boolean(detail) && !multiSelectMode

  function closeDetail() {
    setDetailId(null)
    setMobileDetailOpen(false)
  }

  useEffect(() => {
    if (multiSelectMode) {
      setDetailId(null)
      setMobileDetailOpen(false)
    }
  }, [multiSelectMode])

  useEffect(() => {
    setPage(1)
  }, [query, kindFilter, tagFilter])

  useEffect(() => {
    if (page > pageSlice.totalPages) {
      setPage(pageSlice.totalPages)
    }
  }, [page, pageSlice.totalPages])

  useEffect(() => {
    if (filtered.length === 0) {
      setDetailId(null)
      setCheckedIds(new Set())
      setMobileDetailOpen(false)
      return
    }
    if (detailId && !filtered.some((p) => p.id === detailId)) {
      setDetailId(null)
      setMobileDetailOpen(false)
    }
    setCheckedIds((prev) => {
      const next = new Set<string>()
      for (const id of prev) {
        if (filtered.some((p) => p.id === id)) next.add(id)
      }
      return next
    })
  }, [filtered, detailId])

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if (e.key !== 'Escape') return
      if (checkedIds.size > 0) {
        setCheckedIds(new Set())
        anchorIdRef.current = null
      }
      closeDetail()
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [checkedIds.size])

  const kindOptions = useMemo(() => pluginKindsFromPacks(packs), [packs])
  const tagOptions = useMemo(() => pluginTagsFromPacks(packs), [packs])

  const kindCounts = useMemo(() => {
    const counts = new Map<string, number>()
    for (const pack of packs) {
      counts.set(pack.kind, (counts.get(pack.kind) ?? 0) + 1)
    }
    return counts
  }, [packs])

  const tagCounts = useMemo(() => {
    const counts = new Map<string, number>()
    for (const pack of packs) {
      for (const tag of pack.tags ?? []) {
        const key = tag.trim()
        if (!key) continue
        counts.set(key, (counts.get(key) ?? 0) + 1)
      }
    }
    return counts
  }, [packs])

  function selectRange(toId: string) {
    const anchorId = anchorIdRef.current
    if (!anchorId) {
      setCheckedIds(new Set([toId]))
      return
    }
    const fromIndex = filtered.findIndex((p) => p.id === anchorId)
    const toIndex = filtered.findIndex((p) => p.id === toId)
    if (fromIndex < 0 || toIndex < 0) {
      setCheckedIds(new Set([toId]))
      return
    }
    const start = Math.min(fromIndex, toIndex)
    const end = Math.max(fromIndex, toIndex)
    const next = new Set(checkedIds)
    for (let i = start; i <= end; i++) {
      next.add(filtered[i]!.id)
    }
    setCheckedIds(next)
  }

  function toggleCheck(packId: string) {
    setCheckedIds((prev) => {
      const next = new Set(prev)
      if (next.has(packId)) next.delete(packId)
      else next.add(packId)
      return next
    })
    anchorIdRef.current = packId
    closeDetail()
  }

  function handleRowClick(packId: string, event: MouseEvent<HTMLElement>) {
    if (event.shiftKey) {
      closeDetail()
      selectRange(packId)
      return
    }

    if (event.metaKey || event.ctrlKey) {
      toggleCheck(packId)
      return
    }

    // Plain click: open detail (clear multi-select)
    setDetailId(packId)
    setMobileDetailOpen(true)
    anchorIdRef.current = packId
    setCheckedIds(new Set())
  }

  async function handleMultiAdd() {
    if (checkedPacks.length < 2) return
    const opened = await tryOpenForjaBatchInstallDeepLink(
      checkedPacks.map((pack) => ({
        manifestUrl: pack.manifestUrl,
        name: pack.name,
        version: pack.version,
      })),
    )
    if (opened) {
      setCheckedIds(new Set())
      anchorIdRef.current = null
      return
    }
    batchInstall.openDialog(checkedPacks)
  }

  async function handleBatchConfirm(
    items: Parameters<typeof batchInstall.confirmBatch>[0],
  ) {
    const ok = await batchInstall.confirmBatch(items)
    if (ok) {
      setCheckedIds(new Set())
      anchorIdRef.current = null
    }
  }

  if (error) {
    return (
      <div className="rounded-xl border border-white/10 bg-[#121110] p-8 text-center text-sm text-[rgba(237,230,218,0.6)]">
        {error.message}
      </div>
    )
  }

  return (
    <>
      <div className="flex flex-col gap-3">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="relative min-w-0 flex-1 sm:max-w-md">
            <Search
              className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-[rgba(237,230,218,0.35)]"
              aria-hidden
            />
            <input
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search packs…"
              className="h-10 w-full rounded-xl border border-white/10 bg-white/[0.04] pl-9 pr-3 text-sm text-[#EDE6DA] placeholder:text-[rgba(237,230,218,0.35)] outline-none focus:border-forja-green/40 focus:ring-1 focus:ring-forja-green/25"
            />
          </div>
          <p className="shrink-0 font-mono-ui text-[10px] uppercase tracking-wider text-[rgba(237,230,218,0.4)]">
            {isLoading
              ? 'Loading…'
              : filtered.length === 0
                ? '0 packs'
                : `${pageSlice.start}-${pageSlice.end} of ${filtered.length}`}
          </p>
        </div>

        <div className="flex flex-col gap-2">
          <div className="flex gap-1.5 overflow-x-auto pb-0.5 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
            <FilterChip
              active={kindFilter === 'all'}
              onClick={() => setKindFilter('all')}
              label="All"
              count={packs.length}
            />
            {kindOptions.map((kind) => (
              <FilterChip
                key={kind}
                active={kindFilter === kind}
                onClick={() => setKindFilter(kind)}
                label={pluginKindLabel(kind)}
                count={kindCounts.get(kind)}
              />
            ))}
          </div>
          {tagOptions.length > 0 ? (
            <div className="flex gap-1.5 overflow-x-auto pb-0.5 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
              <FilterChip
                active={tagFilter === 'all'}
                onClick={() => setTagFilter('all')}
                label="Topics"
                count={packs.filter((p) => (p.tags?.length ?? 0) > 0).length}
              />
              {tagOptions.map((tag) => (
                <FilterChip
                  key={tag}
                  active={tagFilter === tag}
                  onClick={() => setTagFilter(tag)}
                  label={pluginTagLabel(tag)}
                  count={tagCounts.get(tag)}
                />
              ))}
            </div>
          ) : null}
        </div>

        <div
          className={cn(
            'overflow-hidden rounded-xl border border-white/10 bg-[#121110]',
            showDetail && CATALOG_PANE_HEIGHT_CLASS,
          )}
        >
          <div
            className={cn(
              'grid h-full',
              showDetail
                ? 'lg:grid-cols-[minmax(0,1fr)_minmax(300px,380px)]'
                : 'lg:grid-cols-1',
            )}
          >
            <div
              className={cn(
                'flex min-h-0 min-w-0 flex-col border-white/10',
                showDetail && 'lg:border-r',
                mobileDetailOpen && showDetail ? 'hidden lg:flex' : 'flex',
              )}
            >
              {showMultiAdd ? (
                <div className="flex flex-wrap items-center justify-between gap-2 border-b border-forja-green/25 bg-forja-green/10 px-3 py-2.5 sm:px-4">
                  <p className="font-mono-ui text-[10px] uppercase tracking-wider text-forja-green">
                    {checkedIds.size} packs selected
                    <span className="ml-2 text-[rgba(237,230,218,0.45)]">
                      Shift+click range · Esc clear
                    </span>
                  </p>
                  <button
                    type="button"
                    data-hover=""
                    disabled={batchInstall.busy}
                    onClick={() => void handleMultiAdd()}
                    className="btn-magnet inline-flex items-center justify-center gap-2 rounded-full px-5 py-2 font-mono-ui text-[10px] font-bold uppercase tracking-[0.12em] shadow-[0_0_24px_rgba(28,231,131,0.28)] will-change-transform sm:text-[11px]"
                  >
                    <Plus className="size-3.5" />
                    Add {checkedIds.size} to Forja
                  </button>
                </div>
              ) : (
                <div className="border-b border-white/[0.06] px-3 py-2 sm:px-4">
                  <p className="font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.35)]">
                    Packs · click for details · checkbox or Shift+click to select
                  </p>
                </div>
              )}

              <div className="min-h-0 flex-1 overflow-y-auto">
                {isLoading ? (
                  <ListSkeleton />
                ) : filtered.length === 0 ? (
                  <p className="px-4 py-8 text-center text-sm text-[rgba(237,230,218,0.45)]">
                    No packs match your search.
                  </p>
                ) : (
                  pageSlice.items.map((pack) => (
                    <PluginListRow
                      key={pack.id}
                      pack={pack}
                      focused={showDetail && detail?.id === pack.id}
                      checked={checkedIds.has(pack.id)}
                      onRowClick={(event) => handleRowClick(pack.id, event)}
                      onToggleCheck={() => toggleCheck(pack.id)}
                    />
                  ))
                )}
              </div>

              {!isLoading && pageSlice.totalPages > 1 ? (
                <div className="flex shrink-0 items-center justify-between gap-3 border-t border-white/[0.06] px-3 py-2.5 sm:px-4">
                  <span className="font-mono-ui text-[10px] uppercase tracking-wider text-[rgba(237,230,218,0.4)]">
                    Page {pageSlice.page} of {pageSlice.totalPages}
                  </span>
                  <div className="flex items-center gap-1">
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="h-8 w-8 p-0 text-[rgba(237,230,218,0.6)] hover:text-[#EDE6DA]"
                      disabled={pageSlice.page <= 1}
                      aria-label="Previous page"
                      onClick={() => setPage(pageSlice.page - 1)}
                    >
                      <ChevronLeft className="size-4" />
                    </Button>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="h-8 w-8 p-0 text-[rgba(237,230,218,0.6)] hover:text-[#EDE6DA]"
                      disabled={pageSlice.page >= pageSlice.totalPages}
                      aria-label="Next page"
                      onClick={() => setPage(pageSlice.page + 1)}
                    >
                      <ChevronRight className="size-4" />
                    </Button>
                  </div>
                </div>
              ) : null}
            </div>

            {showDetail && detail ? (
              <aside className="hidden h-full min-h-0 flex-col lg:flex">
                <PluginDetailPanel pack={detail} onClose={closeDetail} />
              </aside>
            ) : null}
          </div>
        </div>

        {mobileDetailOpen && detail && showDetail ? (
          <div className="fixed inset-0 z-50 lg:hidden">
            <button
              type="button"
              className="absolute inset-0 bg-black/60 backdrop-blur-sm"
              aria-label="Close details"
              onClick={closeDetail}
            />
            <div className="absolute inset-x-0 bottom-0 top-[18%] flex flex-col overflow-hidden rounded-t-2xl border border-white/10 bg-[#121110] shadow-2xl">
              <PluginDetailPanel pack={detail} onClose={closeDetail} />
            </div>
          </div>
        ) : null}
      </div>

      <PluginBatchInstallDialog
        open={batchInstall.dialogOpen}
        packs={batchInstall.dialogPacks}
        installedPacks={batchInstall.installedPacks}
        initialSelection={batchInstall.initialSelection}
        busy={batchInstall.busy}
        onConfirm={(items) => void handleBatchConfirm(items)}
        onCancel={batchInstall.closeDialog}
      />
    </>
  )
}

function FilterChip({
  active,
  onClick,
  label,
  count,
}: {
  active: boolean
  onClick: () => void
  label: string
  count?: number
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'inline-flex shrink-0 items-center gap-1.5 rounded-lg border px-2.5 py-1.5 font-mono-ui text-[10px] uppercase tracking-wider transition-colors',
        active
          ? 'border-forja-green/40 bg-forja-green/15 text-forja-green'
          : 'border-white/10 text-[rgba(237,230,218,0.45)] hover:border-white/20 hover:text-[#EDE6DA]',
      )}
    >
      {label}
      {count != null ? (
        <span className={cn('tabular-nums', active ? 'opacity-80' : 'opacity-50')}>
          {count}
        </span>
      ) : null}
    </button>
  )
}

function ListSkeleton() {
  return (
    <div className="animate-pulse">
      {Array.from({ length: 8 }).map((_, i) => (
        <div
          key={i}
          className="flex items-center gap-3 border-b border-white/[0.06] px-4 py-3"
        >
          <div className="size-4 rounded-sm bg-white/10" />
          <div className="flex-1 space-y-1.5">
            <div className="h-2.5 w-16 rounded bg-white/5" />
            <div className="h-3 w-32 rounded bg-white/10" />
          </div>
        </div>
      ))}
    </div>
  )
}
