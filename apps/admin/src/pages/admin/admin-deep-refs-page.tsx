import {
  Fragment,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type PointerEvent as ReactPointerEvent,
} from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useSearch } from '@tanstack/react-router'
import {
  ChevronDown,
  ChevronRight,
  FileCode2,
  PanelRightClose,
  PanelRightOpen,
  RefreshCw,
  Search,
  X,
} from 'lucide-react'
import {
  EmptyState,
  MetricChip,
  PageHeader,
  Panel,
  PanelLabel,
  StatusBadge,
  TablePagination,
  tableClassName,
  tableWrapClassName,
  tdClassName,
  thClassName,
} from '@/components/admin-ui'
import { PromoteBackfillDialog } from '@/components/confirm-dialog'
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
import { reprocessDeepRefForAdmin } from '@/lib/deep-ref-reprocess'
import { fetchAllRows } from '@/lib/fetch-all-rows'
import { fetchPasteBodyForAdmin } from '@/lib/paste-body'
import {
  cancelPromoteBackfill,
  countPromoteBackfillPending,
  startPromoteBackfill,
} from '@/lib/promote-backfill'
import { formatAdminDateTime } from '@/lib/iptv-portal-expiry'
import { runDurationLabel } from '@/lib/ops-overview'
import {
  SCRAPE_RUNS_LATEST_KEY,
  fetchScrapeRuns,
  isPromoteBackfillRun,
  markRunsStoppedInCache,
  prependOptimisticRun,
  refreshScrapeRuns,
  scrapeRunMetricChips,
  subscribeScrapeRuns,
} from '@/lib/scrape-runs'
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
  /** Last collect/process upsert; falls back to created_at pre-migration. */
  updated_at: string | null
  iptv_scrape_runs: { started_at: string } | null
  iptv_scrape_deep_ref_portals: DeepRefPortalRow[] | null
}

function deepRefLastAt(r: DeepRefRow): string {
  return (
    r.updated_at ||
    r.iptv_scrape_runs?.started_at ||
    r.created_at
  )
}

type FilterStatus = 'all' | 'recheck' | 'ok' | 'has_portals' | 'existing_only'

async function fetchDeepRefs(): Promise<DeepRefRow[]> {
  const rows = await fetchAllRows(async (from, to) => {
    const { data, error } = await adminDb
      .from('iptv_scrape_deep_refs')
      .select(
        `id, post_id, scrape_run_id, base64, paste_url, ref_host,
         payload_hash, fetch_ok, extract_count, needs_recheck, created_at, updated_at,
         iptv_scrape_runs ( started_at ),
         iptv_scrape_deep_ref_portals (
           id, platform, type, output, url, username, password, was_existing, portal_id, created_at
         )`,
      )
      .order('id', { ascending: false })
      .range(from, to)
    if (error && /updated_at/i.test(error.message)) {
      const retry = await adminDb
        .from('iptv_scrape_deep_refs')
        .select(
          `id, post_id, scrape_run_id, base64, paste_url, ref_host,
           payload_hash, fetch_ok, extract_count, needs_recheck, created_at,
           iptv_scrape_runs ( started_at ),
           iptv_scrape_deep_ref_portals (
             id, platform, type, output, url, username, password, was_existing, portal_id, created_at
           )`,
        )
        .order('id', { ascending: false })
        .range(from, to)
      if (retry.error) throw retry.error
      return (retry.data ?? []).map((r) => ({
        ...(r as Omit<DeepRefRow, 'updated_at'>),
        updated_at: null,
      }))
    }
    if (error) throw error
    return (data ?? []) as DeepRefRow[]
  })
  // One row per paste (post_id+hash). Force-full re-upserts same rows — sort by last touch.
  return [...rows].sort((a, b) => {
    const tb = Date.parse(deepRefLastAt(b))
    const ta = Date.parse(deepRefLastAt(a))
    if (tb !== ta) return tb - ta
    return b.id.localeCompare(a.id)
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
                  {p.portal_id ? (
                    <Link
                      to="/pool"
                      search={{
                        portal: p.portal_id,
                        url: p.url,
                        user: p.username,
                      }}
                      className="text-forja-text underline-offset-2 hover:text-forja-green hover:underline"
                      title="Open in Pool"
                    >
                      {p.url}
                    </Link>
                  ) : (
                    p.url
                  )}
                </td>
                <td className="px-3 py-2 font-mono-ui text-xs">
                  {p.portal_id ? (
                    <Link
                      to="/pool"
                      search={{
                        portal: p.portal_id,
                        url: p.url,
                        user: p.username,
                      }}
                      className="text-forja-text underline-offset-2 hover:text-forja-green hover:underline"
                      title="Open in Pool"
                    >
                      {p.username || '—'}
                    </Link>
                  ) : (
                    p.username || '—'
                  )}
                </td>
                <td className="px-3 py-2 text-xs">
                  {!p.portal_id ? (
                    <span className="text-forja-muted">Not promoted</span>
                  ) : (
                    <Link
                      to="/pool"
                      search={{
                        portal: p.portal_id,
                        url: p.url,
                        user: p.username,
                      }}
                      className={cn(
                        'underline-offset-2 hover:underline',
                        p.was_existing
                          ? 'text-amber-300'
                          : 'text-forja-green',
                      )}
                      title="Open in Pool"
                    >
                      {p.was_existing ? 'Already in DB' : 'New insert'}
                      <span className="ml-1 text-forja-muted">→ Pool</span>
                    </Link>
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
  onReprocess,
  reprocessing,
}: {
  row: DeepRefRow
  width: number
  onWidthChange: (w: number) => void
  onClose: () => void
  onReprocess: () => void
  reprocessing: boolean
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

  const canReprocess = Boolean(row.paste_url.trim() || row.base64.trim())

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
          className="h-7 shrink-0 gap-1 px-2"
          disabled={!canReprocess || reprocessing}
          onClick={onReprocess}
          title="Re-fetch paste, extract portals, upsert into pool"
        >
          <RefreshCw
            className={cn('size-3.5', reprocessing && 'animate-spin')}
          />
          <span className="text-xs">
            {reprocessing ? '…' : 'Reprocess'}
          </span>
        </Button>
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
  const qc = useQueryClient()
  const search = useSearch({ from: '/_ops/deep-refs' })
  const focusRefId = search.ref?.trim() || null
  const focusedOnce = useRef<string | null>(null)
  const runs = useQuery({
    queryKey: SCRAPE_RUNS_LATEST_KEY,
    queryFn: () => fetchScrapeRuns(8),
    refetchInterval: (q) =>
      q.state.data?.some((r) => r.status === 'running') ? 1_500 : 8_000,
    refetchOnWindowFocus: true,
  })
  const backfillRun =
    runs.data?.find(
      (r) => r.status === 'running' && isPromoteBackfillRun(r),
    ) ?? null
  const list = useQuery({
    queryKey: DEEP_REFS_KEY,
    queryFn: fetchDeepRefs,
    refetchInterval: backfillRun ? 2_000 : 12_000,
  })

  const [q, setQ] = useState(() => focusRefId ?? '')
  const [statusFilter, setStatusFilter] = useState<FilterStatus>('all')
  const [openId, setOpenId] = useState<string | null>(() => focusRefId)
  const [pastePanelId, setPastePanelId] = useState<string | null>(null)
  const [panelWidth, setPanelWidth] = useState(PASTE_PANEL_DEFAULT)
  const [reprocessingId, setReprocessingId] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const [actionInfo, setActionInfo] = useState<string | null>(null)
  const [backfillOpen, setBackfillOpen] = useState(false)
  const [backfillBusy, setBackfillBusy] = useState(false)
  const [backfillPending, setBackfillPending] = useState<number | null>(null)
  const [backfillPendingLoading, setBackfillPendingLoading] = useState(false)

  useEffect(() => {
    setPanelWidth(readStoredPanelWidth())
  }, [])

  useEffect(() => {
    return subscribeScrapeRuns(() => {
      void refreshScrapeRuns(qc)
    })
  }, [qc])

  const backfillWasRunning = useRef(false)
  useEffect(() => {
    if (backfillRun) {
      backfillWasRunning.current = true
      return
    }
    if (!backfillWasRunning.current) return
    backfillWasRunning.current = false
    void qc.invalidateQueries({ queryKey: DEEP_REFS_KEY })
    void qc.invalidateQueries({ queryKey: ['admin', 'pool'] })
  }, [backfillRun, qc])

  useEffect(() => {
    if (!focusRefId) return
    setQ(focusRefId)
    setOpenId(focusRefId)
  }, [focusRefId])

  useEffect(() => {
    if (!backfillOpen) return
    let cancelled = false
    setBackfillPendingLoading(true)
    void countPromoteBackfillPending()
      .then((n) => {
        if (!cancelled) setBackfillPending(n)
      })
      .catch((e) => {
        if (!cancelled) {
          setActionError(
            e instanceof Error ? e.message : 'Failed to count pending',
          )
          setBackfillPending(null)
        }
      })
      .finally(() => {
        if (!cancelled) setBackfillPendingLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [backfillOpen])

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

  const reprocess = useCallback(
    async (id: string) => {
      setActionError(null)
      setActionInfo(null)
      setReprocessingId(id)
      try {
        const pasteUrl = (list.data ?? []).find((r) => r.id === id)?.paste_url
          ?.trim()
        const result = await reprocessDeepRefForAdmin(id)
        await qc.invalidateQueries({ queryKey: DEEP_REFS_KEY })
        await qc.invalidateQueries({ queryKey: ['admin', 'pool'] })
        if (pasteUrl) {
          await qc.invalidateQueries({
            queryKey: ['admin', 'paste_body', pasteUrl],
          })
        }
        setActionInfo(
          `Reprocessed · ${result.hitCount} portals · ${result.promoted} promoted` +
            (result.wasExisting ? ` (${result.wasExisting} already in DB)` : ''),
        )
      } catch (e) {
        setActionError(e instanceof Error ? e.message : 'Reprocess failed')
      } finally {
        setReprocessingId(null)
      }
    },
    [qc, list.data],
  )

  const startBackfill = useCallback(
    async (opts: { limit: number; chunkSize: number }) => {
      setActionError(null)
      setActionInfo(null)
      setBackfillBusy(true)
      try {
        const result = await startPromoteBackfill(opts)
        setBackfillOpen(false)
        if (result.run) {
          prependOptimisticRun(qc, result.run)
        } else if (result.runId) {
          prependOptimisticRun(qc, {
            id: result.runId,
            started_at: new Date().toISOString(),
            status: 'running',
            source: 'promote-backfill',
          })
        }
        await refreshScrapeRuns(qc)
        setActionInfo(
          `Promote backfill running · ≤${result.limit?.toLocaleString() ?? opts.limit} · chunk ${result.chunkSize ?? opts.chunkSize}`,
        )
      } catch (e) {
        setActionError(
          e instanceof Error ? e.message : 'Promote backfill failed',
        )
      } finally {
        setBackfillBusy(false)
      }
    },
    [qc],
  )

  const stopBackfill = useCallback(async () => {
    if (!backfillRun) return
    setActionError(null)
    setBackfillBusy(true)
    try {
      await qc.cancelQueries({ queryKey: ['admin', 'scrape_runs'] })
      markRunsStoppedInCache(qc, {
        runId: backfillRun.id,
        error: 'Stop requested from admin',
      })
      await cancelPromoteBackfill({ runId: backfillRun.id })
      await refreshScrapeRuns(qc)
      await qc.invalidateQueries({ queryKey: DEEP_REFS_KEY })
      setActionInfo('Promote backfill stopped')
    } catch (e) {
      await refreshScrapeRuns(qc)
      setActionError(
        e instanceof Error ? e.message : 'Stop promote backfill failed',
      )
    } finally {
      setBackfillBusy(false)
    }
  }, [backfillRun, qc])

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
        r.id,
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
          p.portal_id,
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

  useEffect(() => {
    if (!focusRefId || !list.data?.length) return
    if (focusedOnce.current === focusRefId) return
    const exists = list.data.some((r) => r.id === focusRefId)
    if (!exists) return
    focusedOnce.current = focusRefId
    const t = window.setTimeout(() => {
      document
        .getElementById(`deep-ref-${focusRefId}`)
        ?.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }, 80)
    return () => window.clearTimeout(t)
  }, [focusRefId, list.data, paging.page])

  const stats = useMemo(() => {
    let recheck = 0
    let withPaste = 0
    let portalHits = 0
    let notPromoted = 0
    for (const r of rows) {
      if (r.needs_recheck) recheck++
      if (r.paste_url) withPaste++
      const portals = r.iptv_scrape_deep_ref_portals ?? []
      portalHits += portals.length
      for (const p of portals) {
        if (!p.portal_id) notPromoted++
      }
    }
    return { total: rows.length, recheck, withPaste, portalHits, notPromoted }
  }, [rows])

  const pasteRow = useMemo(
    () => (pastePanelId ? rows.find((r) => r.id === pastePanelId) : undefined),
    [pastePanelId, rows],
  )

  const togglePastePanel = (id: string) => {
    setPastePanelId((cur) => (cur === id ? null : id))
  }

  return (
    <div
      className={cn(
        'flex',
        // Cancel main px; when paste open, bleed past max-w-7xl to viewport right edge.
        pasteRow
          ? '-ml-4 mr-[calc(50%-50vw)] sm:-ml-6'
          : '-mx-4 sm:-mx-6',
      )}
    >
      <div className="min-w-0 flex-1 space-y-6 px-4 sm:px-6">
        <PageHeader
          title="Deep refs"
          description="One row per find: base64 + paste URL only. Open the paste panel to fetch the body live."
          actions={
            <div className="flex flex-wrap items-center gap-2">
              <Button
                type="button"
                variant="secondary"
                size="sm"
                className="text-amber-300"
                disabled={Boolean(backfillRun) || backfillBusy}
                onClick={() => setBackfillOpen(true)}
              >
                {backfillRun ? 'Backfill running' : 'Backfill promote'}
              </Button>
              <Button type="button" variant="ghost" size="sm" asChild>
                <Link to="/scrape">← Scrape</Link>
              </Button>
            </div>
          }
        />

        {actionError ? (
          <p className="text-sm text-red-400">{actionError}</p>
        ) : null}
        {actionInfo && !backfillRun ? (
          <p className="text-sm text-forja-muted">{actionInfo}</p>
        ) : null}

        {backfillRun ? (
          <Panel tone="accent">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="min-w-0 space-y-3">
                <PanelLabel>Backfill promote</PanelLabel>
                <div className="flex flex-wrap items-center gap-2">
                  <StatusBadge status={backfillRun.status} />
                  <span className="text-xs text-forja-muted">
                    {formatAdminDateTime(backfillRun.started_at)} ·{' '}
                    {runDurationLabel(backfillRun)}
                    {backfillRun.status === 'running' ? ' · in progress' : ''}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
                  {scrapeRunMetricChips(backfillRun).map((c) => (
                    <MetricChip
                      key={c.label}
                      label={c.label}
                      value={c.value}
                    />
                  ))}
                </div>
                {backfillRun.error ? (
                  <p className="text-sm text-red-400">{backfillRun.error}</p>
                ) : null}
              </div>
              <div className="flex flex-wrap gap-2">
                <Button asChild variant="ghost" size="sm">
                  <Link to="/scrape">View on Scrape</Link>
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={backfillBusy}
                  onClick={() => void stopBackfill()}
                >
                  {backfillBusy ? 'Stopping…' : 'Stop'}
                </Button>
              </div>
            </div>
          </Panel>
        ) : null}
        <div className="flex flex-wrap gap-2">
          <MetricChip label="Refs" value={stats.total} />
          <MetricChip label="With paste URL" value={stats.withPaste} />
          <MetricChip label="Portal hits" value={stats.portalHits} />
          <MetricChip label="Not promoted" value={stats.notPromoted} />
          <MetricChip label="Recheck" value={stats.recheck} />
        </div>

        <div className="flex flex-wrap items-end gap-3">
          <div className="relative min-w-[16rem] flex-1 space-y-1.5">
            <Label
              htmlFor="deep-q"
              className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted"
            >
              Search
            </Label>
            <div className="relative">
              <Search
                className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-forja-muted"
                aria-hidden
              />
              <Input
                id="deep-q"
                className="pl-9"
                placeholder="base64, paste URL, host, user, portal id…"
                value={q}
                onChange={(e) => setQ(e.target.value)}
              />
            </div>
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
            <span className="text-forja-muted">
              {' '}
              · one row per paste (run L2 portals are hits inside these)
            </span>
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
                    <th
                      className={thClassName}
                      title="Last scrape touch (force-full reuses the same paste row)"
                    >
                      Last
                    </th>
                    <th className={thClassName}>Post</th>
                    <th className={thClassName}>Paste URL</th>
                    <th
                      className={thClassName}
                      title="Portal hits on this paste (not scrape-run L2 total)"
                    >
                      Portals
                    </th>
                    <th className={thClassName}>Recheck</th>
                    <th className={thClassName}>Paste</th>
                    <th className={thClassName}>Reprocess</th>
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
                          id={`deep-ref-${r.id}`}
                          className={cn(
                            'border-t border-forja-border/80 transition-colors hover:bg-white/[0.02]',
                            open && 'bg-forja-green/[0.04]',
                            pasteOpen && 'bg-forja-green/[0.06]',
                            focusRefId === r.id &&
                              'bg-forja-green/[0.08] ring-1 ring-inset ring-forja-green/35',
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
                            title={
                              r.created_at !== deepRefLastAt(r)
                                ? `First seen ${formatAdminDateTime(r.created_at)}`
                                : undefined
                            }
                          >
                            {formatAdminDateTime(deepRefLastAt(r))}
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
                          <td className={tdClassName}>
                            <Button
                              type="button"
                              variant="ghost"
                              size="sm"
                              className="gap-1.5 px-2"
                              disabled={
                                reprocessingId != null ||
                                (!r.paste_url.trim() && !r.base64.trim())
                              }
                              onClick={() => void reprocess(r.id)}
                              title="Re-fetch paste, extract portals, upsert into pool"
                            >
                              <RefreshCw
                                className={cn(
                                  'size-3.5',
                                  reprocessingId === r.id && 'animate-spin',
                                )}
                              />
                              <span className="sr-only sm:not-sr-only">
                                {reprocessingId === r.id ? '…' : 'Run'}
                              </span>
                            </Button>
                          </td>
                        </tr>
                        {open ? (
                          <tr className="border-t border-forja-border/40 bg-black/20">
                            <td className={tdClassName} colSpan={8}>
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
          onReprocess={() => void reprocess(pasteRow.id)}
          reprocessing={reprocessingId === pasteRow.id}
        />
      ) : null}

      <PromoteBackfillDialog
        open={backfillOpen}
        busy={backfillBusy}
        pending={backfillPending}
        pendingLoading={backfillPendingLoading}
        onClose={() => {
          if (!backfillBusy) setBackfillOpen(false)
        }}
        onConfirm={(opts) => void startBackfill(opts)}
      />
    </div>
  )
}
