import { useEffect, useMemo, useState } from 'react'
import {
  Check,
  ChevronLeft,
  ChevronRight,
  Copy,
  Puzzle,
  Search,
  X,
} from 'lucide-react'
import { AddToForjaButton } from '@/components/add-to-forja-button'
import { Button } from '@/components/ui/button'
import type { ForjaPluginPackLive } from '@/lib/forja-plugin-catalog'
import {
  isOfficialPluginPack,
  packAuthorLabel,
  pluginKindLabel,
  pluginKindsFromPacks,
} from '@/lib/forja-plugin-catalog'
import { cn } from '@/lib/utils'

const PAGE_SIZE = 20

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
  const [copied, setCopied] = useState(false)
  const official = isOfficialPluginPack(pack)
  const author = packAuthorLabel(pack)

  async function copyManifest() {
    try {
      await navigator.clipboard.writeText(pack.manifestUrl)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 2000)
    } catch {
      // ignore
    }
  }

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
          {pack.version ? (
            <span className="font-mono-ui text-[10px] text-[rgba(237,230,218,0.45)]">
              v{pack.version}
            </span>
          ) : null}
          {onClose ? (
            <button
              type="button"
              onClick={onClose}
              className="flex size-8 items-center justify-center rounded-lg text-[rgba(237,230,218,0.5)] hover:bg-white/8 hover:text-[#EDE6DA] lg:hidden"
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

        <dl className="grid grid-cols-2 gap-3 text-sm">
          {pack.pluginCount != null ? (
            <div className="rounded-lg border border-white/8 bg-white/[0.02] px-3 py-2">
              <dt className="font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.4)]">
                Plugins
              </dt>
              <dd className="mt-0.5 text-[#EDE6DA]">{pack.pluginCount}</dd>
            </div>
          ) : null}
          {author ? (
            <div className="rounded-lg border border-white/8 bg-white/[0.02] px-3 py-2">
              <dt className="font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.4)]">
                Author
              </dt>
              <dd className="mt-0.5 truncate text-[#EDE6DA]" title={author}>
                {author}
              </dd>
            </div>
          ) : null}
        </dl>

        <div>
          <p className="mb-1.5 font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.4)]">
            Manifest URL
          </p>
          <div className="flex gap-2">
            <code className="min-w-0 flex-1 truncate rounded-lg border border-white/8 bg-black/20 px-2.5 py-2 font-mono text-[11px] text-[rgba(237,230,218,0.55)]">
              {pack.manifestUrl}
            </code>
            <button
              type="button"
              onClick={() => void copyManifest()}
              className="flex shrink-0 items-center gap-1.5 rounded-lg border border-white/10 px-2.5 py-2 font-mono-ui text-[10px] uppercase tracking-wider text-[rgba(237,230,218,0.55)] hover:border-white/20 hover:text-[#EDE6DA]"
            >
              {copied ? (
                <Check className="size-3.5 text-forja-green" />
              ) : (
                <Copy className="size-3.5" />
              )}
              {copied ? 'OK' : 'Copy'}
            </button>
          </div>
        </div>
      </div>

      <div className="border-t border-white/10 p-4 sm:p-5">
        <AddToForjaButton pack={pack} variant="magnet" className="w-full" />
      </div>
    </div>
  )
}

function PluginListRow({
  pack,
  selected,
  onSelect,
}: {
  pack: ForjaPluginPackLive
  selected: boolean
  onSelect: () => void
}) {
  const official = isOfficialPluginPack(pack)
  const author = packAuthorLabel(pack)

  return (
    <button
      type="button"
      onClick={onSelect}
      className={cn(
        'flex w-full items-center gap-3 border-b border-white/[0.06] px-3 py-2.5 text-left transition-colors sm:px-4',
        selected
          ? 'bg-forja-green/10'
          : 'hover:bg-white/[0.04]',
      )}
    >
      <Puzzle
        className={cn(
          'size-4 shrink-0',
          selected
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
      </div>
      {pack.version ? (
        <span className="shrink-0 font-mono-ui text-[10px] text-[rgba(237,230,218,0.35)]">
          v{pack.version}
        </span>
      ) : null}
    </button>
  )
}

type PluginCatalogBrowserProps = {
  packs: ForjaPluginPackLive[]
  isLoading?: boolean
  error?: Error | null
}

export function PluginCatalogBrowser({
  packs,
  isLoading,
  error,
}: PluginCatalogBrowserProps) {
  const [query, setQuery] = useState('')
  const [kindFilter, setKindFilter] = useState<string | 'all'>('all')
  const [page, setPage] = useState(1)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [mobileDetailOpen, setMobileDetailOpen] = useState(false)

  const filtered = useMemo(() => {
    let list = [...packs]
    if (kindFilter !== 'all') {
      list = list.filter((p) => p.kind === kindFilter)
    }
    const q = query.trim().toLowerCase()
    if (q) {
      list = list.filter(
        (p) =>
          p.name.toLowerCase().includes(q) ||
          p.description.toLowerCase().includes(q) ||
          p.author?.toLowerCase().includes(q) ||
          pluginKindLabel(p.kind).toLowerCase().includes(q) ||
          p.id.toLowerCase().includes(q),
      )
    }
    return list.sort((a, b) => a.name.localeCompare(b.name))
  }, [packs, kindFilter, query])

  const pageSlice = useMemo(
    () => paginate(filtered, page),
    [filtered, page],
  )

  const selected =
    filtered.find((p) => p.id === selectedId) ??
    filtered[0] ??
    null

  useEffect(() => {
    setPage(1)
  }, [query, kindFilter])

  useEffect(() => {
    if (page > pageSlice.totalPages) {
      setPage(pageSlice.totalPages)
    }
  }, [page, pageSlice.totalPages])

  useEffect(() => {
    if (filtered.length === 0) {
      setSelectedId(null)
      setMobileDetailOpen(false)
      return
    }
    if (!selectedId || !filtered.some((p) => p.id === selectedId)) {
      setSelectedId(filtered[0]!.id)
    }
  }, [filtered, selectedId])

  const kindOptions = useMemo(() => pluginKindsFromPacks(packs), [packs])

  const kindCounts = useMemo(() => {
    const counts = new Map<string, number>()
    for (const pack of packs) {
      counts.set(pack.kind, (counts.get(pack.kind) ?? 0) + 1)
    }
    return counts
  }, [packs])

  function selectPack(id: string) {
    setSelectedId(id)
    setMobileDetailOpen(true)
  }

  if (error) {
    return (
      <div className="rounded-xl border border-white/10 bg-[#121110] p-8 text-center text-sm text-[rgba(237,230,218,0.6)]">
        {error.message}
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-3">
      {/* Toolbar */}
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

      {/* Kind filters */}
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
      <div className="overflow-hidden rounded-xl border border-white/10 bg-[#121110]">
        <div className="grid min-h-[min(70vh,640px)] lg:grid-cols-[minmax(0,1fr)_minmax(280px,360px)]">
          {/* List */}
          <div
            className={cn(
              'flex flex-col border-white/10 lg:border-r',
              mobileDetailOpen ? 'hidden lg:flex' : 'flex',
            )}
          >
            <div className="border-b border-white/[0.06] px-3 py-2 sm:px-4">
              <p className="font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.35)]">
                Packs
              </p>
            </div>
            <div className="flex-1 overflow-y-auto">
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
                    selected={selected?.id === pack.id}
                    onSelect={() => selectPack(pack.id)}
                  />
                ))
              )}
            </div>
            {!isLoading && filtered.length > PAGE_SIZE ? (
              <div className="flex items-center justify-between gap-3 border-t border-white/[0.06] px-3 py-2.5 sm:px-4">
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

          {/* Detail - desktop */}
          <div className="hidden flex-col bg-[#0f0e0d] lg:flex">
            {selected ? (
              <PluginDetailPanel pack={selected} />
            ) : (
              <EmptyDetail />
            )}
          </div>
        </div>
      </div>

      {/* Detail - mobile sheet */}
      {mobileDetailOpen && selected ? (
        <div className="fixed inset-0 z-50 lg:hidden">
          <button
            type="button"
            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
            aria-label="Close details"
            onClick={() => setMobileDetailOpen(false)}
          />
          <div className="absolute inset-x-0 bottom-0 top-[18%] flex flex-col overflow-hidden rounded-t-2xl border border-white/10 bg-[#121110] shadow-2xl">
            <PluginDetailPanel
              pack={selected}
              onClose={() => setMobileDetailOpen(false)}
            />
          </div>
        </div>
      ) : null}
    </div>
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

function EmptyDetail() {
  return (
    <div className="flex flex-1 flex-col items-center justify-center px-6 text-center">
      <p className="text-sm text-[rgba(237,230,218,0.45)]">
        Select a pack to see details and install.
      </p>
    </div>
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
