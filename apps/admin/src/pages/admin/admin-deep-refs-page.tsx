import { Fragment, useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { ChevronDown, ChevronRight, FileCode2 } from 'lucide-react'
import {
  EmptyState,
  MetricChip,
  PageHeader,
  Panel,
  PanelLabel,
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
import { cn } from '@/lib/utils'

export const DEEP_REFS_KEY = ['admin', 'deep_refs'] as const

type DeepRefPortalRow = {
  id: string
  url: string
  username: string
  was_existing: boolean
  portal_id: string | null
  created_at: string
}

type DeepRefRow = {
  id: string
  post_id: string
  scrape_run_id: string | null
  ref_type: string
  ref_host: string
  payload_hash: string
  raw_ref: string
  payload_text: string | null
  fetch_ok: boolean | null
  extract_count: number
  needs_recheck: boolean
  created_at: string
  iptv_scrape_deep_ref_portals: DeepRefPortalRow[] | null
}

type FilterType = 'all' | 'b64_url' | 'b64_text' | 'paste_url'
type FilterStatus = 'all' | 'recheck' | 'ok' | 'has_portals' | 'existing_only'

async function fetchDeepRefs(limit = 200): Promise<DeepRefRow[]> {
  const { data, error } = await adminDb
    .from('iptv_scrape_deep_refs')
    .select(
      `id, post_id, scrape_run_id, ref_type, ref_host, payload_hash, raw_ref,
       payload_text, fetch_ok, extract_count, needs_recheck, created_at,
       iptv_scrape_deep_ref_portals ( id, url, username, was_existing, portal_id, created_at )`,
    )
    .order('created_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as DeepRefRow[]
}

function typeLabel(t: string): string {
  if (t === 'b64_url') return 'Base64 → paste URL'
  if (t === 'b64_text') return 'Base64 text'
  if (t === 'paste_url') return 'Paste URL'
  return t
}

function insidePreview(row: DeepRefRow): string {
  if (row.payload_text?.trim()) return row.payload_text.trim()
  if (row.ref_type === 'b64_url' && row.payload_text) return row.payload_text
  return ''
}

export function AdminDeepRefsPage() {
  const list = useQuery({
    queryKey: DEEP_REFS_KEY,
    queryFn: () => fetchDeepRefs(300),
    refetchInterval: 12_000,
  })

  const [q, setQ] = useState('')
  const [typeFilter, setTypeFilter] = useState<FilterType>('all')
  const [statusFilter, setStatusFilter] = useState<FilterStatus>('all')
  const [openId, setOpenId] = useState<string | null>(null)

  const rows = list.data ?? []

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    return rows.filter((r) => {
      if (typeFilter !== 'all' && r.ref_type !== typeFilter) return false
      const portals = r.iptv_scrape_deep_ref_portals ?? []
      const existing = portals.filter((p) => p.was_existing).length
      const inserted = portals.length - existing
      if (statusFilter === 'recheck' && !r.needs_recheck) return false
      if (statusFilter === 'ok' && r.needs_recheck) return false
      if (statusFilter === 'has_portals' && portals.length === 0) return false
      if (statusFilter === 'existing_only' && !(portals.length > 0 && inserted === 0))
        return false
      if (!needle) return true
      const hay = [
        r.post_id,
        r.ref_type,
        r.ref_host,
        r.raw_ref,
        r.payload_text ?? '',
        ...portals.map((p) => `${p.url} ${p.username}`),
      ]
        .join('\n')
        .toLowerCase()
      return hay.includes(needle)
    })
  }, [rows, q, typeFilter, statusFilter])

  const stats = useMemo(() => {
    let portals = 0
    let existing = 0
    let inserted = 0
    let recheck = 0
    for (const r of rows) {
      if (r.needs_recheck) recheck++
      for (const p of r.iptv_scrape_deep_ref_portals ?? []) {
        portals++
        if (p.was_existing) existing++
        else inserted++
      }
    }
    return {
      refs: rows.length,
      portals,
      existing,
      inserted,
      recheck,
    }
  }, [rows])

  return (
    <div className="space-y-8">
      <PageHeader
        title="Deep refs"
        description="Base64 and paste payloads from scrape — decoded content, portals found, and whether each was already in the pool."
        actions={
          <>
            <Button asChild variant="ghost" size="sm">
              <Link to="/scrape">Scrape</Link>
            </Button>
            <Button asChild variant="secondary" size="sm">
              <Link to="/pool">Pool</Link>
            </Button>
          </>
        }
      />

      <Panel tone="accent">
        <PanelLabel>Inventory</PanelLabel>
        <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-5">
          <MetricChip label="Refs" value={stats.refs} />
          <MetricChip label="Portals found" value={stats.portals} />
          <MetricChip label="Already in DB" value={stats.existing} />
          <MetricChip label="Inserted / new" value={stats.inserted} />
          <MetricChip label="Needs recheck" value={stats.recheck} />
        </div>
        <p className="mt-3 text-xs text-forja-muted">
          “Already in DB” = url+user existed in <code className="font-mono-ui">iptv_portals</code> before
          this scrape hit (still upserted; no duplicate row). Empty until you run scrape after the
          deep_ref_portals migration.
        </p>
      </Panel>

      <Panel>
        <div className="flex flex-wrap items-end gap-3">
          <div className="min-w-[200px] flex-1 space-y-1.5">
            <Label htmlFor="deep-q">Search</Label>
            <Input
              id="deep-q"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="post id, host, base64, url, user…"
            />
          </div>
          <div className="w-[160px] space-y-1.5">
            <Label>Type</Label>
            <Select
              value={typeFilter}
              onValueChange={(v) => setTypeFilter(v as FilterType)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All types</SelectItem>
                <SelectItem value="b64_url">Base64 → URL</SelectItem>
                <SelectItem value="b64_text">Base64 text</SelectItem>
                <SelectItem value="paste_url">Paste URL</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="w-[180px] space-y-1.5">
            <Label>Status</Label>
            <Select
              value={statusFilter}
              onValueChange={(v) => setStatusFilter(v as FilterStatus)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All</SelectItem>
                <SelectItem value="has_portals">Has portals</SelectItem>
                <SelectItem value="existing_only">All already in DB</SelectItem>
                <SelectItem value="recheck">Needs recheck</SelectItem>
                <SelectItem value="ok">Extracted OK</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
      </Panel>

      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
      ) : null}

      {!list.isLoading && filtered.length === 0 ? (
        <EmptyState
          title="No deep refs"
          description="Run a catalog scrape (after migrations) to populate base64 / paste rows."
        />
      ) : (
        <div className={tableWrapClassName}>
          <div className="overflow-x-auto">
            <table className={tableClassName}>
              <thead>
                <tr>
                  <th className={thClassName} />
                  <th className={thClassName}>When</th>
                  <th className={thClassName}>Type</th>
                  <th className={thClassName}>Host / post</th>
                  <th className={thClassName}>Portals</th>
                  <th className={thClassName}>New</th>
                  <th className={thClassName}>Already</th>
                  <th className={thClassName}>Recheck</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((r) => {
                  const portals = r.iptv_scrape_deep_ref_portals ?? []
                  const existing = portals.filter((p) => p.was_existing).length
                  const inserted = portals.length - existing
                  const open = openId === r.id
                  const preview = insidePreview(r)
                  return (
                    <Fragment key={r.id}>
                      <tr
                        className={cn(
                          'border-t border-forja-border/80 transition-colors hover:bg-white/[0.02]',
                          open && 'bg-forja-green/[0.04]',
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
                        <td className={cn(tdClassName, 'whitespace-nowrap text-xs')}>
                          {new Date(r.created_at).toLocaleString()}
                        </td>
                        <td className={cn(tdClassName, 'text-xs')}>
                          <span className="inline-flex items-center gap-1">
                            <FileCode2 className="size-3.5 opacity-70" />
                            {typeLabel(r.ref_type)}
                          </span>
                        </td>
                        <td className={cn(tdClassName, 'max-w-[220px]')}>
                          <div className="truncate font-mono-ui text-xs">
                            {r.ref_host || '—'}
                          </div>
                          <div className="truncate font-mono-ui text-[11px] text-forja-muted">
                            {r.post_id}
                          </div>
                        </td>
                        <td className={cn(tdClassName, 'tabular-nums')}>
                          {portals.length || r.extract_count}
                        </td>
                        <td
                          className={cn(
                            tdClassName,
                            'tabular-nums',
                            inserted > 0 && 'text-forja-green',
                          )}
                        >
                          {inserted}
                        </td>
                        <td
                          className={cn(
                            tdClassName,
                            'tabular-nums',
                            existing > 0 && 'text-amber-300',
                          )}
                        >
                          {existing}
                        </td>
                        <td className={tdClassName}>
                          {r.needs_recheck ? (
                            <span className="text-xs text-amber-300">yes</span>
                          ) : (
                            <span className="text-xs text-forja-muted">no</span>
                          )}
                        </td>
                      </tr>
                      {open ? (
                        <tr className="border-t border-forja-border/40 bg-black/20">
                          <td className={tdClassName} colSpan={8}>
                            <div className="space-y-4 py-2">
                              <div>
                                <p className="mb-1 text-[11px] font-medium uppercase tracking-wide text-forja-muted">
                                  Raw ref (base64 / URL)
                                </p>
                                <pre className="max-h-28 overflow-auto rounded-lg border border-forja-border bg-black/30 p-3 font-mono-ui text-[11px] leading-relaxed text-forja-muted whitespace-pre-wrap break-all">
                                  {r.raw_ref || '—'}
                                </pre>
                              </div>
                              <div>
                                <p className="mb-1 text-[11px] font-medium uppercase tracking-wide text-forja-muted">
                                  What’s inside
                                  {r.fetch_ok === false
                                    ? ' (fetch failed)'
                                    : r.fetch_ok === true
                                      ? ' (paste body)'
                                      : r.ref_type === 'b64_text'
                                        ? ' (decoded)'
                                        : ''}
                                </p>
                                <pre className="max-h-56 overflow-auto rounded-lg border border-forja-border bg-black/30 p-3 font-mono-ui text-[11px] leading-relaxed text-forja-text whitespace-pre-wrap break-words">
                                  {preview ||
                                    (r.ref_type === 'b64_url'
                                      ? '(pointer only — open the paste_url row for body)'
                                      : '— no payload stored')}
                                </pre>
                              </div>
                              <div>
                                <p className="mb-2 text-[11px] font-medium uppercase tracking-wide text-forja-muted">
                                  Portals from this ref
                                </p>
                                {portals.length === 0 ? (
                                  <p className="text-sm text-forja-muted">
                                    No portals extracted
                                    {r.needs_recheck ? ' — flagged for recheck' : ''}.
                                  </p>
                                ) : (
                                  <div className="overflow-x-auto rounded-lg border border-forja-border">
                                    <table className="w-full text-left text-sm">
                                      <thead>
                                        <tr className="border-b border-forja-border/80 text-[11px] uppercase tracking-wide text-forja-muted">
                                          <th className="px-3 py-2">Status</th>
                                          <th className="px-3 py-2">URL</th>
                                          <th className="px-3 py-2">User</th>
                                          <th className="px-3 py-2">Portal id</th>
                                        </tr>
                                      </thead>
                                      <tbody>
                                        {portals.map((p) => (
                                          <tr
                                            key={p.id}
                                            className="border-t border-forja-border/50"
                                          >
                                            <td className="px-3 py-2">
                                              {p.was_existing ? (
                                                <span className="rounded-md bg-amber-400/15 px-2 py-0.5 text-xs text-amber-300">
                                                  Already in DB
                                                </span>
                                              ) : (
                                                <span className="rounded-md bg-forja-green/15 px-2 py-0.5 text-xs text-forja-green">
                                                  New insert
                                                </span>
                                              )}
                                            </td>
                                            <td className="max-w-[280px] truncate px-3 py-2 font-mono-ui text-xs">
                                              {p.url}
                                            </td>
                                            <td className="px-3 py-2 font-mono-ui text-xs">
                                              {p.username}
                                            </td>
                                            <td className="px-3 py-2 font-mono-ui text-[11px] text-forja-muted">
                                              {p.portal_id
                                                ? `${p.portal_id.slice(0, 8)}…`
                                                : '—'}
                                            </td>
                                          </tr>
                                        ))}
                                      </tbody>
                                    </table>
                                  </div>
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
        </div>
      )}
    </div>
  )
}
