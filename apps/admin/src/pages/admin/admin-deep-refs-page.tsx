import {
  Fragment,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type PointerEvent as ReactPointerEvent,
} from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import {
  ChevronDown,
  ChevronRight,
  FileCode2,
  PanelRightClose,
  PanelRightOpen,
  X,
} from 'lucide-react'
import {
  EmptyState,
  MetricChip,
  PageHeader,
  TablePagination,
  tableClassName,
  tableWrapClassName,
  tdClassName,
  thClassName,
} from '@/components/admin-ui'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { adminDb } from '@/lib/admin-db'
import { fetchAllRows } from '@/lib/fetch-all-rows'
import { fetchPasteBodyForAdmin } from '@/lib/paste-body'
import { useTablePagination } from '@/lib/use-table-pagination'
import { cn } from '@/lib/utils'

export const DEEP_REFS_KEY = ['admin', 'deep_refs'] as const

const PASTE_PANEL_WIDTH_KEY = 'admin.deep-refs.paste-panel-width'
const PASTE_PANEL_MIN = 280
const PASTE_PANEL_MAX = 900
const PASTE_PANEL_DEFAULT = 420

type DeepRefPortalRow = {
  id: string
  platform: string
  type: string
  output: string
  url: string
  username: string
  password: string
  was_existing: boolean
  portal_id: string | null
  created_at: string
}

type DeepRefRow = {
  id: string
  post_id: string
  scrape_run_id: string | null
  base64: string
  paste_url: string
  ref_host: string
  payload_hash: string
  fetch_ok: boolean | null
  extract_count: number
  needs_recheck: boolean
  created_at: string
  iptv_scrape_deep_ref_portals: DeepRefPortalRow[] | null
}

type FilterStatus = 'all' | 'recheck' | 'ok' | 'has_portals' | 'existing_only'

async function fetchDeepRefs(): Promise<DeepRefRow[]> {
  return fetchAllRows(async (from, to) => {
    const { data, error } = await adminDb
      .from('iptv_scrape_deep_refs')
      .select(
        `id, post_id, scrape_run_id, base64, paste_url, ref_host,
         payload_hash, fetch_ok, extract_count, needs_recheck, created_at,
         iptv_scrape_deep_ref_portals (
           id, platform, type, output, url, username, password, was_existing, portal_id, created_at
         )`,
      )
      .order('created_at', { ascending: false })
      .range(from, to)
    if (error) throw error
    return (data ?? []) as DeepRefRow[]
  })
}

function clampPanelWidth(w: number) {
  return Math.min(
    PASTE_PANEL_MAX,
    Math.max(PASTE_PANEL_MIN, Math.round(w)),
  )
}

function readStoredPanelWidth(): number {
  try {
    const raw = localStorage.getItem(PASTE_PANEL_WIDTH_KEY)
    if (!raw) return PASTE_PANEL_DEFAULT
    const n = Number(raw)
    return Number.isFinite(n) ? clampPanelWidth(n) : PASTE_PANEL_DEFAULT
  } catch {
    return PASTE_PANEL_DEFAULT
  }
}

function DeepRefPortalsTable({ portals }: { portals: DeepRefPortalRow[] }) {
  const paging = useTablePagination(portals, { initialPageSize: 25 })
  return (
    <div className="overflow-hidden border border-forja-border">
      <div className="overflow-x-auto">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-forja-border/80 text-[11px] uppercase tracking-wide text-forja-muted">
              <th className="px-3 py-2">Platform</th>
              <th className="px-3 py-2">Type</th>
              <th className="px-3 py-2">Output</th>
              <th className="px-3 py-2">URL</th>
              <th className="px-3 py-2">User</th>
              <th className="px-3 py-2">Status</th>
            </tr>
          </thead>
          <tbody>
            {paging.pageRows.map((p) => (
              <tr key={p.id} className="border-t border-forja-border/50">
                <td className="px-3 py-2 font-mono-ui text-xs text-forja-green">
                  {p.platform}
                </td>
                <td className="px-3 py-2 font-mono-ui text-xs">
                  {p.type || '—'}
                </td>
                <td className="px-3 py-2 font-mono-ui text-xs">
                  {p.output || '—'}
                </td>
                <td className="max-w-[160px] truncate px-3 py-2 font-mono-ui text-xs">
                  {p.url}
                </td>
                <td className="px-3 py-2 font-mono-ui text-xs">
                  {p.username || '—'}
                </td>
                <td className="px-3 py-2 text-xs">
                  {!p.portal_id ? (
                    <span className="text-forja-muted">Not promoted</span>
                  ) : p.was_existing ? (
                    <span className="text-amber-300">Already in DB</span>
                  ) : (
                    <span className="text-forja-green">New insert</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <TablePagination
        page={paging.page}
        pageSize={paging.pageSize}
        total={paging.total}
        onPageChange={paging.setPage}
        onPageSizeChange={paging.setPageSize}
        pageSizeOptions={[10, 25, 50]}
      />
    </div>
  )
}

function decodeInlineBase64(raw: string): string | null {
  const s = raw.trim()
  if (!s) return null
  try {
    const bin = atob(s)
    const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0))
    return new TextDecoder().decode(bytes)
  } catch {
    return null
  }
}

function PasteBodyContent({
  pasteUrl,
  base64,
  fetchOk,
}: {
  pasteUrl: string
  base64: string
  fetchOk: boolean | null
}) {
  const url = pasteUrl.trim()
  const pasteQuery = useQuery({
    queryKey: ['admin', 'paste_body', url],
    queryFn: () => fetchPasteBodyForAdmin(url),
    enabled: Boolean(url),
    staleTime: 5 * 60_000,
    retry: 1,
  })

  if (url) {
    if (pasteQuery.isLoading) {
      return <p className="text-sm text-forja-muted">Fetching paste…</p>
    }
    if (pasteQuery.isError) {
      return (
        <p className="text-sm text-red-400">
          {(pasteQuery.error as Error).message}
        </p>
      )
    }
    return (
      <pre className="font-mono-ui text-[11px] leading-relaxed text-forja-muted whitespace-pre-wrap break-words">
        {pasteQuery.data}
      </pre>
    )
  }

  const decoded = decodeInlineBase64(base64)
  if (!decoded) {
    return (
      <p className="text-sm text-forja-muted">No paste URL or decodable base64.</p>
    )
  }
  return (
    <div className="space-y-2">
      {fetchOk === false ? (
        <p className="text-xs text-amber-300">Scrape fetch failed</p>
      ) : null}
      <p className="text-[11px] font-medium uppercase tracking-wide text-forja-muted">
        Decoded base64
      </p>
      <pre className="font-mono-ui text-[11px] leading-relaxed text-forja-muted whitespace-pre-wrap break-words">
        {decoded}
      </pre>
    </div>
  )
}

function PasteSidePanel({
  row,
  width,
  onWidthChange,
  onClose,
}: {
  row: DeepRefRow
  width: number
  onWidthChange: (w: number) => void
  onClose: () => void
}) {
  const dragRef = useRef<{ startX: number; startW: number } | null>(null)

  const onPointerDown = useCallback(
    (e: ReactPointerEvent<HTMLDivElement>) => {
      e.preventDefault()
      dragRef.current = { startX: e.clientX, startW: width }
      e.currentTarget.setPointerCapture(e.pointerId)
    },
    [width],
  )

  const onPointerMove = useCallback(
    (e: ReactPointerEvent<HTMLDivElement>) => {
      const drag = dragRef.current
      if (!drag) return
      // Dragging left edge: moving left increases width
      onWidthChange(clampPanelWidth(drag.startW + (drag.startX - e.clientX)))
    },
    [onWidthChange],
  )

  const endDrag = useCallback((e: ReactPointerEvent<HTMLDivElement>) => {
    if (!dragRef.current) return
    dragRef.current = null
    try {
      e.currentTarget.releasePointerCapture(e.pointerId)
    } catch {
      /* already released */
    }
  }, [])

  const title = row.paste_url.trim()
    ? row.fetch_ok === false
      ? 'Paste body (scrape fetch failed)'
      : 'Paste body · live from paste host'
    : 'Decoded base64'

  return (
    <aside
      className="relative sticky top-0 flex h-dvh shrink-0 flex-col border-l border-forja-border bg-forja-bg"
      style={{ width }}
      aria-label="Paste body panel"
    >
      <div
        role="separator"
        aria-orientation="vertical"
        aria-valuenow={width}
        aria-valuemin={PASTE_PANEL_MIN}
        aria-valuemax={PASTE_PANEL_MAX}
        tabIndex={0}
        className="absolute inset-y-0 left-0 z-10 w-1.5 -translate-x-1/2 cursor-col-resize touch-none hover:bg-forja-green/40 active:bg-forja-green/60"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
        onKeyDown={(e) => {
          if (e.key === 'ArrowLeft') {
            e.preventDefault()
            onWidthChange(clampPanelWidth(width + 24))
          } else if (e.key === 'ArrowRight') {
            e.preventDefault()
            onWidthChange(clampPanelWidth(width - 24))
          }
        }}
      />
      <div className="flex shrink-0 items-start gap-2 border-b border-forja-border/80 px-3 py-2.5">
        <div className="min-w-0 flex-1">
          <p className="text-[11px] font-medium uppercase tracking-wide text-forja-muted">
            {title}
          </p>
          <p
            className="mt-0.5 truncate font-mono-ui text-[11px] text-forja-text"
            title={row.paste_url || row.post_id}
          >
            {row.paste_url || row.post_id}
          </p>
        </div>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="size-7 shrink-0 p-0"
          onClick={onClose}
          aria-label="Close paste panel"
        >
          <X className="size-4" />
        </Button>
      </div>
      <div className="min-h-0 flex-1 overflow-y-auto px-3 py-3">
        <PasteBodyContent
          pasteUrl={row.paste_url}
          base64={row.base64}
          fetchOk={row.fetch_ok}
        />
      </div>
    </aside>
  )
}

export function AdminDeepRefsPage() {
  const list = useQuery({
    queryKey: DEEP_REFS_KEY,
    queryFn: fetchDeepRefs,
    refetchInterval: 12_000,
  })

  const [q, setQ] = useState('')
  const [statusFilter, setStatusFilter] = useState<FilterStatus>('all')
  const [openId, setOpenId] = useState<string | null>(null)
  const [pastePanelId, setPastePanelId] = useState<string | null>(null)
  const [panelWidth, setPanelWidth] = useState(PASTE_PANEL_DEFAULT)

  useEffect(() => {
    setPanelWidth(readStoredPanelWidth())
  }, [])

  const onWidthChange = useCallback((w: number) => {
    const next = clampPanelWidth(w)
    setPanelWidth(next)
    try {
      localStorage.setItem(PASTE_PANEL_WIDTH_KEY, String(next))
    } catch {
      /* ignore */
    }
  }, [])

  const rows = list.data ?? []

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    return rows.filter((r) => {
      if (statusFilter === 'recheck' && !r.needs_recheck) return false
      if (statusFilter === 'ok' && r.needs_recheck) return false
      const portals = r.iptv_scrape_deep_ref_portals ?? []
      if (statusFilter === 'has_portals' && portals.length === 0) return false
      if (
        statusFilter === 'existing_only' &&
        !portals.some((p) => p.was_existing)
      ) {
        return false
      }
      if (!needle) return true
      const hay = [
        r.post_id,
        r.base64,
        r.paste_url,
        r.ref_host,
        ...portals.flatMap((p) => [
          p.platform,
          p.type,
          p.output,
          p.url,
          p.username,
        ]),
      ]
        .join(' ')
        .toLowerCase()
      return hay.includes(needle)
    })
  }, [rows, q, statusFilter])

  const paging = useTablePagination(filtered, {
    initialPageSize: 50,
    resetKey: `${q}|${statusFilter}`,
  })

  const stats = useMemo(() => {
    let recheck = 0
    let withPaste = 0
    let portalHits = 0
    for (const r of rows) {
      if (r.needs_recheck) recheck++
      if (r.paste_url) withPaste++
      portalHits += r.iptv_scrape_deep_ref_portals?.length ?? 0
    }
    return { total: rows.length, recheck, withPaste, portalHits }
  }, [rows])

  const pasteRow = useMemo(
    () => (pastePanelId ? rows.find((r) => r.id === pastePanelId) : undefined),
    [pastePanelId, rows],
  )

  const togglePastePanel = (id: string) => {
    setPastePanelId((cur) => (cur === id ? null : id))
  }

  return (
    <div className="-mx-4 flex sm:-mx-6">
      <div className="min-w-0 flex-1 space-y-6 px-4 sm:px-6">
        <PageHeader
          title="Deep refs"
          description="One row per find: base64 + paste URL only. Open the paste panel to fetch the body live."
          actions={
            <Button type="button" variant="ghost" size="sm" asChild>
              <Link to="/scrape">← Scrape</Link>
            </Button>
          }
        />

        <div className="flex flex-wrap gap-2">
          <MetricChip label="Refs" value={stats.total} />
          <MetricChip label="With paste URL" value={stats.withPaste} />
          <MetricChip label="Portal hits" value={stats.portalHits} />
          <MetricChip label="Recheck" value={stats.recheck} />
        </div>

        <div className="flex flex-wrap items-end gap-3">
          <div className="min-w-[16rem] flex-1 space-y-1.5">
            <Label
              htmlFor="deep-q"
              className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted"
            >
              Search
            </Label>
            <Input
              id="deep-q"
              placeholder="base64, paste URL, portal output…"
              value={q}
              onChange={(e) => setQ(e.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <Label className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted">
              Status
            </Label>
            <Select
              value={statusFilter}
              onValueChange={(v) => setStatusFilter(v as FilterStatus)}
            >
              <SelectTrigger className="w-[11rem]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All</SelectItem>
                <SelectItem value="ok">Parsed ok</SelectItem>
                <SelectItem value="recheck">Needs recheck</SelectItem>
                <SelectItem value="has_portals">Has portals</SelectItem>
                <SelectItem value="existing_only">Had existing portal</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <p className="pb-2 text-xs text-forja-muted">
            {filtered.length}
            {rows.length !== filtered.length ? ` / ${rows.length}` : ''} refs
          </p>
        </div>

        {list.isError ? (
          <p className="text-sm text-red-400">
            {(list.error as Error).message}
          </p>
        ) : list.isLoading ? (
          <p className="text-sm text-forja-muted">Loading…</p>
        ) : filtered.length === 0 ? (
          <EmptyState
            title="No deep refs yet"
            description="Run a full scrape. Each base64→paste.sh pair becomes one row here."
          />
        ) : (
          <div className={tableWrapClassName}>
            <div className="overflow-x-auto">
              <table className={tableClassName}>
                <thead>
                  <tr>
                    <th className={thClassName} />
                    <th className={thClassName}>When</th>
                    <th className={thClassName}>Post</th>
                    <th className={thClassName}>Paste URL</th>
                    <th className={thClassName}>Portals</th>
                    <th className={thClassName}>Recheck</th>
                    <th className={thClassName}>Paste</th>
                  </tr>
                </thead>
                <tbody>
                  {paging.pageRows.map((r) => {
                    const portals = r.iptv_scrape_deep_ref_portals ?? []
                    const open = openId === r.id
                    const pasteOpen = pastePanelId === r.id
                    return (
                      <Fragment key={r.id}>
                        <tr
                          className={cn(
                            'border-t border-forja-border/80 transition-colors hover:bg-white/[0.02]',
                            open && 'bg-forja-green/[0.04]',
                            pasteOpen && 'bg-forja-green/[0.06]',
                          )}
                        >
                          <td className={tdClassName}>
                            <button
                              type="button"
                              className="inline-flex size-7 items-center justify-center rounded-md text-forja-muted hover:bg-white/[0.06] hover:text-forja-text"
                              onClick={() => setOpenId(open ? null : r.id)}
                              aria-expanded={open}
                              aria-label={open ? 'Collapse' : 'Expand'}
                            >
                              {open ? (
                                <ChevronDown className="size-4" />
                              ) : (
                                <ChevronRight className="size-4" />
                              )}
                            </button>
                          </td>
                          <td
                            className={cn(
                              tdClassName,
                              'whitespace-nowrap text-xs',
                            )}
                          >
                            {new Date(r.created_at).toLocaleString()}
                          </td>
                          <td
                            className={cn(tdClassName, 'font-mono-ui text-xs')}
                          >
                            {r.post_id}
                          </td>
                          <td className={cn(tdClassName, 'max-w-[280px]')}>
                            <div className="truncate font-mono-ui text-xs">
                              {r.paste_url || '—'}
                            </div>
                            <div className="truncate font-mono-ui text-[11px] text-forja-muted">
                              {r.base64
                                ? `b64 ${r.base64.slice(0, 24)}…`
                                : 'no base64'}
                            </div>
                          </td>
                          <td className={cn(tdClassName, 'tabular-nums')}>
                            {portals.length || r.extract_count}
                          </td>
                          <td className={tdClassName}>
                            {r.needs_recheck ? (
                              <span className="text-xs text-amber-300">yes</span>
                            ) : (
                              <span className="text-xs text-forja-muted">no</span>
                            )}
                          </td>
                          <td className={tdClassName}>
                            <Button
                              type="button"
                              variant="ghost"
                              size="sm"
                              className={cn(
                                'gap-1.5 px-2',
                                pasteOpen && 'text-forja-green',
                              )}
                              onClick={() => togglePastePanel(r.id)}
                              aria-pressed={pasteOpen}
                              title={
                                pasteOpen
                                  ? 'Hide paste panel'
                                  : 'Show paste panel'
                              }
                            >
                              {pasteOpen ? (
                                <PanelRightClose className="size-3.5" />
                              ) : (
                                <PanelRightOpen className="size-3.5" />
                              )}
                              <span className="sr-only sm:not-sr-only">
                                {pasteOpen ? 'Hide' : 'Show'}
                              </span>
                            </Button>
                          </td>
                        </tr>
                        {open ? (
                          <tr className="border-t border-forja-border/40 bg-black/20">
                            <td className={tdClassName} colSpan={7}>
                              <div className="space-y-4 py-2">
                                <div className="grid gap-3 sm:grid-cols-2">
                                  <div>
                                    <p className="mb-1 text-[11px] font-medium uppercase tracking-wide text-forja-muted">
                                      Base64
                                    </p>
                                    <pre className="max-h-28 overflow-auto border border-forja-border bg-black/30 p-3 font-mono-ui text-[11px] leading-relaxed text-forja-muted whitespace-pre-wrap break-all">
                                      {r.base64 || '—'}
                                    </pre>
                                  </div>
                                  <div>
                                    <p className="mb-1 text-[11px] font-medium uppercase tracking-wide text-forja-muted">
                                      Paste URL
                                    </p>
                                    <pre className="max-h-28 overflow-auto border border-forja-border bg-black/30 p-3 font-mono-ui text-[11px] leading-relaxed text-forja-text whitespace-pre-wrap break-all">
                                      {r.paste_url || '—'}
                                    </pre>
                                  </div>
                                </div>
                                <div>
                                  <p className="mb-2 flex items-center gap-1.5 text-[11px] font-medium uppercase tracking-wide text-forja-muted">
                                    <FileCode2 className="size-3.5" />
                                    Portals (platform · type · output)
                                  </p>
                                  {portals.length === 0 ? (
                                    <p className="text-sm text-forja-muted">
                                      No portals extracted
                                      {r.needs_recheck
                                        ? ' — flagged for recheck'
                                        : ''}
                                      .
                                    </p>
                                  ) : (
                                    <DeepRefPortalsTable portals={portals} />
                                  )}
                                </div>
                              </div>
                            </td>
                          </tr>
                        ) : null}
                      </Fragment>
                    )
                  })}
                </tbody>
              </table>
            </div>
            <TablePagination
              page={paging.page}
              pageSize={paging.pageSize}
              total={paging.total}
              onPageChange={paging.setPage}
              onPageSizeChange={paging.setPageSize}
            />
          </div>
        )}
      </div>

      {pasteRow ? (
        <PasteSidePanel
          row={pasteRow}
          width={panelWidth}
          onWidthChange={onWidthChange}
          onClose={() => setPastePanelId(null)}
        />
      ) : null}
    </div>
  )
}
