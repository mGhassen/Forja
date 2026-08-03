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
  paste_body: string | null
  ref_host: string
  payload_hash: string
  fetch_ok: boolean | null
  extract_count: number
  needs_recheck: boolean
  created_at: string
  iptv_scrape_deep_ref_portals: DeepRefPortalRow[] | null
}

type FilterStatus = 'all' | 'recheck' | 'ok' | 'has_portals' | 'existing_only'

async function fetchDeepRefs(limit = 200): Promise<DeepRefRow[]> {
  const { data, error } = await adminDb
    .from('iptv_scrape_deep_refs')
    .select(
      `id, post_id, scrape_run_id, base64, paste_url, paste_body, ref_host,
       payload_hash, fetch_ok, extract_count, needs_recheck, created_at,
       iptv_scrape_deep_ref_portals (
         id, platform, type, output, url, username, password, was_existing, portal_id, created_at
       )`,
    )
    .order('created_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return (data ?? []) as DeepRefRow[]
}

export function AdminDeepRefsPage() {
  const list = useQuery({
    queryKey: DEEP_REFS_KEY,
    queryFn: () => fetchDeepRefs(300),
    refetchInterval: 12_000,
  })

  const [q, setQ] = useState('')
  const [statusFilter, setStatusFilter] = useState<FilterStatus>('all')
  const [openId, setOpenId] = useState<string | null>(null)

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
        r.paste_body ?? '',
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

  return (
    <div className="space-y-6">
      <PageHeader
        title="Deep refs"
        description="One row per find: base64 + paste.sh URL. Under each ref: portals with platform (xtream/m3u/stalker) and get.php type/output."
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

      <Panel>
        <PanelLabel>Filters</PanelLabel>
        <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <div className="space-y-2 sm:col-span-2">
            <Label htmlFor="deep-q">Search</Label>
            <Input
              id="deep-q"
              placeholder="base64, paste URL, portal output…"
              value={q}
              onChange={(e) => setQ(e.target.value)}
            />
          </div>
          <div className="space-y-2">
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
                <SelectItem value="ok">Parsed ok</SelectItem>
                <SelectItem value="recheck">Needs recheck</SelectItem>
                <SelectItem value="has_portals">Has portals</SelectItem>
                <SelectItem value="existing_only">Had existing portal</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
      </Panel>

      <Panel>
        <PanelLabel>Finds ({filtered.length})</PanelLabel>
        {list.isError ? (
          <p className="mt-3 text-sm text-red-400">
            {(list.error as Error).message}
          </p>
        ) : list.isLoading ? (
          <p className="mt-3 text-sm text-forja-muted">Loading…</p>
        ) : filtered.length === 0 ? (
          <EmptyState
            title="No deep refs yet"
            description="Run a full scrape. Each base64→paste.sh pair becomes one row here."
          />
        ) : (
          <div className={cn(tableWrapClassName, 'mt-3')}>
            <table className={tableClassName}>
              <thead>
                <tr>
                  <th className={thClassName} />
                  <th className={thClassName}>When</th>
                  <th className={thClassName}>Post</th>
                  <th className={thClassName}>Paste URL</th>
                  <th className={thClassName}>Portals</th>
                  <th className={thClassName}>Recheck</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((r) => {
                  const portals = r.iptv_scrape_deep_ref_portals ?? []
                  const open = openId === r.id
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
                        <td
                          className={cn(
                            tdClassName,
                            'whitespace-nowrap text-xs',
                          )}
                        >
                          {new Date(r.created_at).toLocaleString()}
                        </td>
                        <td className={cn(tdClassName, 'font-mono-ui text-xs')}>
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
                      </tr>
                      {open ? (
                        <tr className="border-t border-forja-border/40 bg-black/20">
                          <td className={tdClassName} colSpan={6}>
                            <div className="space-y-4 py-2">
                              <div>
                                <p className="mb-1 text-[11px] font-medium uppercase tracking-wide text-forja-muted">
                                  Base64
                                </p>
                                <pre className="max-h-28 overflow-auto rounded-lg border border-forja-border bg-black/30 p-3 font-mono-ui text-[11px] leading-relaxed text-forja-muted whitespace-pre-wrap break-all">
                                  {r.base64 || '—'}
                                </pre>
                              </div>
                              <div>
                                <p className="mb-1 text-[11px] font-medium uppercase tracking-wide text-forja-muted">
                                  Paste URL
                                </p>
                                <pre className="overflow-auto rounded-lg border border-forja-border bg-black/30 p-3 font-mono-ui text-[11px] leading-relaxed text-forja-text whitespace-pre-wrap break-all">
                                  {r.paste_url || '—'}
                                </pre>
                              </div>
                              {r.paste_body ? (
                                <div>
                                  <p className="mb-1 text-[11px] font-medium uppercase tracking-wide text-forja-muted">
                                    Paste body
                                    {r.fetch_ok === false
                                      ? ' (fetch failed)'
                                      : ''}
                                  </p>
                                  <pre className="max-h-40 overflow-auto rounded-lg border border-forja-border bg-black/30 p-3 font-mono-ui text-[11px] leading-relaxed text-forja-muted whitespace-pre-wrap break-words">
                                    {r.paste_body}
                                  </pre>
                                </div>
                              ) : null}
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
                                  <div className="overflow-x-auto rounded-lg border border-forja-border">
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
                                        {portals.map((p) => (
                                          <tr
                                            key={p.id}
                                            className="border-t border-forja-border/50"
                                          >
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
                                              {p.platform === 'stalker' ? (
                                                <span className="text-forja-muted">
                                                  saved (not pool)
                                                </span>
                                              ) : p.was_existing ? (
                                                <span className="text-amber-300">
                                                  Already in DB
                                                </span>
                                              ) : (
                                                <span className="text-forja-green">
                                                  New insert
                                                </span>
                                              )}
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
        )}
      </Panel>
    </div>
  )
}
