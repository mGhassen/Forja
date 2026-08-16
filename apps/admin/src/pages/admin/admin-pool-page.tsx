import { useEffect, useMemo, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useSearch } from '@tanstack/react-router'
import { ArrowDown, ArrowUp, Radio, Search } from 'lucide-react'
import { IptvPortalPeopleDialog } from '@/components/iptv-assign-dialog'
import {
  IptvPortalActionRow,
  IptvPortalEditDialog,
  decryptPortalPassword,
  errMessage,
  type IptvPortalEditForm,
} from '@/components/iptv-portal-row'
import { PageHeader, TablePagination } from '@/components/admin-ui'
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
import { catalogVerify } from '@/lib/catalog-verify'
import {
  candidateHost,
  fetchPoolHostPortals,
  fetchPoolHosts,
  fetchPoolPortalById,
  poolHostKey,
  resolvePoolFocusPortalId,
  type PoolCand,
  type PortalPlatform,
} from '@/lib/iptv-pool'
import {
  createPortalShare,
  formatShareCode,
} from '@/lib/iptv-portal-share'
import { cn } from '@/lib/utils'

type SortKey = 'host' | 'accounts' | 'alive' | 'scraped'
type SortDir = 'asc' | 'desc'

function relativeTime(iso: string | null | undefined): string {
  if (!iso) return '—'
  const t = new Date(iso).getTime()
  if (Number.isNaN(t)) return '—'
  const sec = Math.round((Date.now() - t) / 1000)
  if (sec < 60) return 'just now'
  const min = Math.round(sec / 60)
  if (min < 60) return `${min}m ago`
  const hr = Math.round(min / 60)
  if (hr < 48) return `${hr}h ago`
  return `${Math.round(hr / 24)}d ago`
}

function useDebounced<T>(value: T, ms: number): T {
  const [debounced, setDebounced] = useState(value)
  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(value), ms)
    return () => window.clearTimeout(t)
  }, [value, ms])
  return debounced
}

function HostPortals({
  host,
  filters,
  highlightedId,
  sharingId,
  shareFlash,
  checkingId,
  checkingHost,
  removePending,
  onShare,
  onEdit,
  onDelete,
  onCheck,
  onPeople,
}: {
  host: string
  filters: {
    q: string
    inventory: 'all' | 'pool' | 'nonpool'
    platform: 'all' | PortalPlatform
    status: 'all' | 'alive' | 'dead' | 'unchecked'
    region: string
  }
  highlightedId: string | null
  sharingId: string | null
  shareFlash: Record<string, string>
  checkingId: string | null
  checkingHost: string | null
  removePending: boolean
  onShare: (c: PoolCand) => void
  onEdit: (c: PoolCand) => void
  onDelete: (id: string) => void
  onCheck: (c: PoolCand) => void
  onPeople: (c: PoolCand) => void
}) {
  const [page, setPage] = useState(0)
  const [pageSize, setPageSize] = useState(50)

  useEffect(() => {
    setPage(0)
  }, [host, filters, pageSize])

  const portals = useQuery({
    queryKey: [
      'admin',
      'pool',
      'portals',
      poolHostKey(host),
      filters,
      page,
      pageSize,
    ],
    queryFn: () =>
      fetchPoolHostPortals(host, {
        ...filters,
        limit: pageSize,
        offset: page * pageSize,
      }),
  })

  if (portals.isLoading) {
    return (
      <p className="border-t border-forja-border px-3 py-3 text-sm text-forja-muted">
        Loading portals…
      </p>
    )
  }
  if (portals.error) {
    return (
      <p className="border-t border-forja-border px-3 py-3 text-sm text-red-400">
        {(portals.error as Error).message}
      </p>
    )
  }
  const rows = portals.data?.portals ?? []
  const total = portals.data?.total ?? 0
  if (total === 0) {
    return (
      <p className="border-t border-forja-border px-3 py-3 text-sm text-forja-muted">
        No portals match these filters.
      </p>
    )
  }

  return (
    <div className="border-t border-forja-border bg-forja-surface/20">
      <ul className="grid grid-cols-1 sm:grid-cols-2 sm:[&>li:nth-child(odd)]:border-r sm:[&>li:nth-child(odd)]:border-forja-border/70">
        {rows.map((c) => (
          <IptvPortalActionRow
            key={c.id}
            portal={c}
            highlighted={highlightedId === c.id}
            sharing={sharingId === c.id}
            shareCode={shareFlash[c.id] ?? null}
            deleting={removePending}
            checking={checkingId === c.id || checkingHost === host}
            deleteConfirmLabel="Remove from catalog pool?"
            deleteDisabled={c.catalog_pool !== true}
            deleteTitle={
              c.catalog_pool ? 'Remove from catalog pool' : 'Not in catalog pool'
            }
            onShare={() => onShare(c)}
            onEdit={() => onEdit(c)}
            onDelete={() => onDelete(c.id)}
            onCheck={() => onCheck(c)}
            onPeople={() => onPeople(c)}
          />
        ))}
      </ul>
      {total > pageSize || page > 0 ? (
        <TablePagination
          page={page}
          pageSize={pageSize}
          total={total}
          onPageChange={setPage}
          onPageSizeChange={setPageSize}
          pageSizeOptions={[25, 50, 100]}
        />
      ) : null}
    </div>
  )
}

export function AdminPoolPage() {
  const qc = useQueryClient()
  const search = useSearch({ from: '/_ops/pool' })
  const focusKey = `${search.portal ?? ''}|${search.url ?? ''}|${search.user ?? ''}`
  const focusedOnce = useRef<string | null>(null)
  const [resolvedFocusId, setResolvedFocusId] = useState<string | null>(null)
  const [open, setOpen] = useState<Set<string>>(() => new Set())
  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState<IptvPortalEditForm>({
    url: '',
    username: '',
    password: '',
    region_primary: 'UNKNOWN',
  })
  const [editError, setEditError] = useState<string | null>(null)
  const [shareFlash, setShareFlash] = useState<Record<string, string>>({})
  const [sharingId, setSharingId] = useState<string | null>(null)
  const [checkingId, setCheckingId] = useState<string | null>(null)
  const [checkingHost, setCheckingHost] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const [actionInfo, setActionInfo] = useState<string | null>(null)
  const [q, setQ] = useState('')
  const debouncedQ = useDebounced(q, 250)
  const [statusFilter, setStatusFilter] = useState<
    'all' | 'alive' | 'dead' | 'unchecked'
  >('all')
  const [inventoryFilter, setInventoryFilter] = useState<
    'all' | 'pool' | 'nonpool'
  >('all')
  const [platformFilter, setPlatformFilter] = useState<'all' | PortalPlatform>(
    'all',
  )
  const [regionFilter, setRegionFilter] = useState<string>('all')
  const [sortKey, setSortKey] = useState<SortKey>('accounts')
  const [sortDir, setSortDir] = useState<SortDir>('desc')
  const [page, setPage] = useState(0)
  const [pageSize, setPageSize] = useState(50)
  const [peopleFor, setPeopleFor] = useState<{
    id: string
    label: string
  } | null>(null)

  const filters = useMemo(
    () => ({
      q: debouncedQ,
      inventory: inventoryFilter,
      platform: platformFilter,
      status: statusFilter,
      region: regionFilter,
    }),
    [debouncedQ, inventoryFilter, platformFilter, statusFilter, regionFilter],
  )

  useEffect(() => {
    setPage(0)
  }, [filters, sortKey, sortDir, pageSize])

  const hostsQuery = useQuery({
    queryKey: [
      'admin',
      'pool',
      'hosts',
      filters,
      sortKey,
      sortDir,
      page,
      pageSize,
    ],
    queryFn: () =>
      fetchPoolHosts({
        ...filters,
        sort: sortKey,
        dir: sortDir,
        limit: pageSize,
        offset: page * pageSize,
      }),
  })

  const hosts = hostsQuery.data?.hosts ?? []
  const hostCount = hostsQuery.data?.host_count ?? 0
  const portalCount = hostsQuery.data?.portal_count ?? 0
  const regionOptions = hostsQuery.data?.regions ?? []

  // Deep-refs → Pool: resolve id, seed search, expand host.
  useEffect(() => {
    if (!search.portal && !search.url) {
      setResolvedFocusId(null)
      return
    }
    if (focusedOnce.current === focusKey) return

    let cancelled = false
    void (async () => {
      try {
        const id = await resolvePoolFocusPortalId({
          portal: search.portal,
          url: search.url,
          user: search.user,
        })
        if (cancelled) return
        if (!id) {
          focusedOnce.current = focusKey
          setResolvedFocusId(null)
          setActionError(
            search.portal
              ? `Portal ${search.portal} not found (stale deep-ref link — reprocess to refresh)`
              : 'Portal not found for url/user',
          )
          return
        }
        const row = await fetchPoolPortalById(id)
        if (cancelled) return
        if (!row) {
          focusedOnce.current = focusKey
          setResolvedFocusId(null)
          setActionError(`Portal ${id} not found`)
          return
        }
        focusedOnce.current = focusKey
        const host = candidateHost(row.url)
        setResolvedFocusId(id)
        setQ(row.username.trim() || host)
        setInventoryFilter('all')
        setPlatformFilter('all')
        setStatusFilter('all')
        setRegionFilter('all')
        setPage(0)
        setActionError(null)
        setActionInfo(`Focused portal ${row.username} @ ${host}`)
        setOpen(new Set([host]))
      } catch (e) {
        if (cancelled) return
        focusedOnce.current = focusKey
        setResolvedFocusId(null)
        setActionError(errMessage(e, 'Focus failed'))
      }
    })()

    return () => {
      cancelled = true
    }
  }, [focusKey, search.portal, search.url, search.user])

  useEffect(() => {
    if (!resolvedFocusId) return
    const t = window.setTimeout(() => {
      document
        .getElementById(`pool-portal-${resolvedFocusId}`)
        ?.scrollIntoView({ block: 'center', behavior: 'smooth' })
    }, 120)
    return () => window.clearTimeout(t)
  }, [resolvedFocusId, hosts, open, debouncedQ])

  function toggleSort(key: SortKey) {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'))
      return
    }
    setSortKey(key)
    setSortDir(key === 'host' ? 'asc' : 'desc')
  }

  function invalidatePool() {
    return qc.invalidateQueries({ queryKey: ['admin', 'pool'] })
  }

  const saveEdit = useMutation({
    mutationFn: async () => {
      if (!editingId) return
      const patch: Record<string, string> = {
        url: form.url.trim(),
        username: form.username.trim(),
        region_primary: form.region_primary.trim() || 'UNKNOWN',
      }
      if (form.password.trim()) patch.password = form.password
      const { error } = await adminDb
        .from('iptv_portals')
        .update(patch)
        .eq('id', editingId)
      if (error) throw error
    },
    onSuccess: async () => {
      setEditingId(null)
      setEditError(null)
      setActionError(null)
      await invalidatePool()
    },
    onError: (e) => {
      setEditError(e instanceof Error ? e.message : 'Save failed')
    },
  })

  const remove = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await adminDb
        .from('iptv_portals')
        .update({ catalog_pool: false })
        .eq('id', id)
        .eq('catalog_pool', true)
      if (error) throw error
    },
    onSuccess: async (_void, id) => {
      setActionError(null)
      if (editingId === id) setEditingId(null)
      await invalidatePool()
    },
    onError: (e) => {
      setActionError(e instanceof Error ? e.message : 'Delete failed')
    },
  })

  function toggle(host: string) {
    const key = poolHostKey(host)
    setOpen((prev) => {
      const next = new Set(prev)
      if (next.has(key)) next.delete(key)
      else next.add(key)
      return next
    })
  }

  async function beginEdit(c: PoolCand) {
    const id = c.id
    setEditError(null)
    setActionError(null)
    setEditingId(id)
    setForm({
      url: c.url,
      username: c.username,
      password: '',
      region_primary: c.region_primary,
    })
    try {
      const pw = await decryptPortalPassword(id)
      setEditingId((cur) => {
        if (cur === id) setForm((f) => ({ ...f, password: pw }))
        return cur
      })
    } catch (e) {
      setEditError(errMessage(e, 'Could not decrypt password'))
    }
  }

  async function copyShare(c: PoolCand) {
    setSharingId(c.id)
    setActionError(null)
    setActionInfo(null)
    try {
      const password = await decryptPortalPassword(c.id)
      const code = await createPortalShare({
        url: c.url,
        username: c.username,
        password,
      })
      const formatted = formatShareCode(code)
      try {
        await navigator.clipboard.writeText(formatted)
      } catch {
        // still show code if clipboard denied
      }
      setShareFlash((prev) => ({ ...prev, [c.id]: formatted }))
      window.setTimeout(() => {
        setShareFlash((prev) => {
          const next = { ...prev }
          delete next[c.id]
          return next
        })
      }, 8000)
    } catch (e) {
      setActionError(errMessage(e, 'Could not create share code'))
    } finally {
      setSharingId(null)
    }
  }

  async function checkPortal(c: PoolCand) {
    setCheckingId(c.id)
    setActionError(null)
    setActionInfo(null)
    try {
      const res = await catalogVerify({ candidateId: c.id })
      const r = res.results[0]
      setActionInfo(
        r
          ? `${c.username}: ${r.alive ? 'alive' : 'dead'} (${r.status})${
              r.error ? ` — ${r.error}` : ''
            }`
          : `Checked ${res.checked}`,
      )
      await invalidatePool()
    } catch (e) {
      setActionError(errMessage(e, 'Status check failed'))
    } finally {
      setCheckingId(null)
    }
  }

  async function checkHost(host: string) {
    setCheckingHost(host)
    setActionError(null)
    setActionInfo(null)
    try {
      const res = await catalogVerify({ host })
      setActionInfo(
        `${host}: ${res.alive} alive · ${res.dead} dead · ${res.checked} checked`,
      )
      await invalidatePool()
    } catch (e) {
      setActionError(errMessage(e, 'Host status check failed'))
    } finally {
      setCheckingHost(null)
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Pool"
        description="All portals, grouped by host. Filter deal inventory vs the rest. Check status, assign, or remove from the deal pool."
        actions={
          <Button asChild variant="ghost" size="sm">
            <Link to="/scrape">Scrape control</Link>
          </Button>
        }
      />

      {hostsQuery.error ? (
        <p className="text-sm text-red-400">
          {(hostsQuery.error as Error).message}
        </p>
      ) : null}
      {actionError ? (
        <p className="text-sm text-red-400">{actionError}</p>
      ) : null}
      {actionInfo ? (
        <p className="text-sm text-forja-muted">{actionInfo}</p>
      ) : null}

      {editingId ? (
        <IptvPortalEditDialog
          form={form}
          setForm={setForm}
          saving={saveEdit.isPending}
          error={editError}
          onClose={() => {
            setEditingId(null)
            setEditError(null)
          }}
          onSave={() => saveEdit.mutate()}
        />
      ) : null}

      {peopleFor ? (
        <IptvPortalPeopleDialog
          portalId={peopleFor.id}
          portalLabel={peopleFor.label}
          onClose={() => setPeopleFor(null)}
        />
      ) : null}

      <div className="flex flex-wrap items-end gap-3">
        <div className="relative min-w-[16rem] flex-1 space-y-1.5">
          <Label
            htmlFor="pool-q"
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
              id="pool-q"
              className="pl-9"
              placeholder="host, url, user, region, portal id…"
              value={q}
              onChange={(e) => setQ(e.target.value)}
            />
          </div>
        </div>
        <div className="space-y-1.5">
          <Label
            htmlFor="pool-inventory-filter"
            className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted"
          >
            Inventory
          </Label>
          <Select
            value={inventoryFilter}
            onValueChange={(v) =>
              setInventoryFilter(v as 'all' | 'pool' | 'nonpool')
            }
          >
            <SelectTrigger id="pool-inventory-filter" className="w-[9.5rem]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All</SelectItem>
              <SelectItem value="pool">Deal pool</SelectItem>
              <SelectItem value="nonpool">Not in pool</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label
            htmlFor="pool-platform-filter"
            className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted"
          >
            Type
          </Label>
          <Select
            value={platformFilter}
            onValueChange={(v) =>
              setPlatformFilter(v as 'all' | PortalPlatform)
            }
          >
            <SelectTrigger id="pool-platform-filter" className="w-[9rem]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All</SelectItem>
              <SelectItem value="xtream">Xtream</SelectItem>
              <SelectItem value="m3u">M3U</SelectItem>
              <SelectItem value="stalker">Stalker</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label
            htmlFor="pool-status-filter"
            className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted"
          >
            Status
          </Label>
          <Select
            value={statusFilter}
            onValueChange={(v) =>
              setStatusFilter(v as 'all' | 'alive' | 'dead' | 'unchecked')
            }
          >
            <SelectTrigger id="pool-status-filter" className="w-[9rem]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All</SelectItem>
              <SelectItem value="alive">Alive</SelectItem>
              <SelectItem value="dead">Dead</SelectItem>
              <SelectItem value="unchecked">Unchecked</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label
            htmlFor="pool-region-filter"
            className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted"
          >
            Region
          </Label>
          <Select value={regionFilter} onValueChange={setRegionFilter}>
            <SelectTrigger id="pool-region-filter" className="min-w-[8rem]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All</SelectItem>
              {regionOptions.map((r) => (
                <SelectItem key={r} value={r}>
                  {r}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <p className="pb-2 text-xs text-forja-muted">
          {portalCount.toLocaleString()} portals · {hostCount.toLocaleString()}{' '}
          hosts
        </p>
      </div>

      <div className="overflow-hidden rounded-xl border border-forja-border">
        {hostsQuery.isLoading ? (
          <p className="px-4 py-4 text-sm text-forja-muted">Loading…</p>
        ) : hostCount === 0 ? (
          <p className="px-4 py-4 text-sm text-forja-muted">
            No portals match these filters.
          </p>
        ) : (
          <>
            <div className="grid grid-cols-[minmax(0,1fr)_5.5rem_4.5rem_7rem_2.5rem] gap-3 border-b border-forja-border bg-forja-elevated/50 px-3 py-2 text-xs font-medium text-forja-muted sm:grid-cols-[minmax(0,1.4fr)_6rem_5rem_8rem_2.5rem]">
              {(
                [
                  { key: 'host', label: 'Host', align: 'left' },
                  { key: 'accounts', label: 'Accounts', align: 'right' },
                  { key: 'alive', label: 'Alive', align: 'right' },
                  { key: 'scraped', label: 'Scraped', align: 'right' },
                ] as const
              ).map((col) => {
                const active = sortKey === col.key
                const Icon = sortDir === 'asc' ? ArrowUp : ArrowDown
                return (
                  <button
                    key={col.key}
                    type="button"
                    onClick={() => toggleSort(col.key)}
                    aria-sort={
                      active
                        ? sortDir === 'asc'
                          ? 'ascending'
                          : 'descending'
                        : 'none'
                    }
                    className={cn(
                      'inline-flex items-center gap-1 hover:text-forja-text',
                      col.align === 'right' && 'justify-self-end',
                      active && 'text-forja-text',
                      col.key !== 'host' && 'tabular-nums',
                    )}
                  >
                    {col.label}
                    {active ? (
                      <Icon className="size-3 shrink-0" aria-hidden />
                    ) : null}
                  </button>
                )
              })}
              <span className="sr-only">Check</span>
            </div>
            {hosts.map((g) => {
              const hostKey = poolHostKey(g.host)
              const expanded = open.has(hostKey)
              const hostBusy = checkingHost === g.host
              return (
                <div
                  key={g.host}
                  className="border-t border-forja-border first:border-t-0"
                >
                  <div className="group/host grid grid-cols-[minmax(0,1fr)_5.5rem_4.5rem_7rem_2.5rem] items-center gap-3 px-3 py-2.5 hover:bg-white/[0.03] focus-within:bg-white/[0.03] sm:grid-cols-[minmax(0,1.4fr)_6rem_5rem_8rem_2.5rem]">
                    <button
                      type="button"
                      onClick={() => toggle(g.host)}
                      aria-expanded={expanded}
                      className="flex min-w-0 items-center gap-2 text-left"
                    >
                      <span
                        className="w-3 shrink-0 text-forja-muted"
                        aria-hidden
                      >
                        {expanded ? '▾' : '▸'}
                      </span>
                      <span className="truncate text-sm font-semibold text-forja-text">
                        {g.host}
                      </span>
                    </button>
                    <span className="text-right text-sm tabular-nums text-forja-muted">
                      {g.accounts}
                    </span>
                    <span className="text-right text-sm tabular-nums text-forja-muted">
                      {g.alive}
                    </span>
                    <span className="text-right text-sm text-forja-muted">
                      {relativeTime(g.last_scraped_at)}
                    </span>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className={cn(
                        'h-8 w-8 justify-self-end p-0 transition-opacity',
                        hostBusy
                          ? 'opacity-100'
                          : 'opacity-0 group-hover/host:opacity-100 group-focus-within/host:opacity-100',
                      )}
                      disabled={hostBusy || checkingId != null}
                      aria-label={`Check all portals on ${g.host}`}
                      title="Check server status"
                      onClick={() => void checkHost(g.host)}
                    >
                      <Radio
                        className={cn(
                          'size-4',
                          hostBusy && 'animate-pulse text-amber-400',
                        )}
                      />
                    </Button>
                  </div>
                  {expanded ? (
                    <HostPortals
                      host={g.host}
                      filters={filters}
                      highlightedId={resolvedFocusId}
                      sharingId={sharingId}
                      shareFlash={shareFlash}
                      checkingId={checkingId}
                      checkingHost={checkingHost}
                      removePending={remove.isPending}
                      onShare={(c) => void copyShare(c)}
                      onEdit={(c) => void beginEdit(c)}
                      onDelete={(id) => remove.mutate(id)}
                      onCheck={(c) => void checkPortal(c)}
                      onPeople={(c) =>
                        setPeopleFor({
                          id: c.id,
                          label: `${c.username} · ${c.url}`,
                        })
                      }
                    />
                  ) : null}
                </div>
              )
            })}
          </>
        )}
      </div>

      {hostCount > 0 ? (
        <TablePagination
          page={page}
          pageSize={pageSize}
          total={hostCount}
          onPageChange={setPage}
          onPageSizeChange={setPageSize}
          pageSizeOptions={[25, 50, 100]}
        />
      ) : null}
    </div>
  )
}
