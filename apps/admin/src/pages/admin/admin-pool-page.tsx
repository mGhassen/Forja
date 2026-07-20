import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { ArrowDown, ArrowUp, Radio } from 'lucide-react'
import { IptvPortalPeopleDialog } from '@/components/iptv-assign-dialog'
import {
  IptvPortalActionRow,
  IptvPortalEditDialog,
  decryptPortalPassword,
  errMessage,
  type IptvPortalEditForm,
} from '@/components/iptv-portal-row'
import { PageHeader } from '@/components/admin-ui'
import { Button } from '@/components/ui/button'
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
  createPortalShare,
  formatShareCode,
} from '@/lib/iptv-portal-share'
import { cn } from '@/lib/utils'

type Cand = {
  id: string
  url: string
  username: string
  alive: boolean | null
  expiry: string | null
  max_connections: string | null
  region_primary: string
  dealt_count: number
  catalog_pool: boolean
  updated_at: string
  last_checked_at: string | null
}

type HostGroup = {
  host: string
  rows: Cand[]
  alive: number
  lastScrapedAt: string | null
}

type SortKey = 'host' | 'accounts' | 'alive' | 'scraped'
type SortDir = 'asc' | 'desc'

function candidateHost(url: string): string {
  try {
    const u = new URL(url.includes('://') ? url : `http://${url}`)
    return u.host || url
  } catch {
    return url
  }
}

function groupByHost(rows: Cand[]): HostGroup[] {
  const map = new Map<string, Cand[]>()
  for (const row of rows) {
    const host = candidateHost(row.url)
    const list = map.get(host)
    if (list) list.push(row)
    else map.set(host, [row])
  }
  return [...map.entries()].map(([host, groupRows]) => {
    let lastScrapedAt: string | null = null
    for (const r of groupRows) {
      const t = r.last_checked_at || r.updated_at
      if (
        t &&
        (!lastScrapedAt ||
          new Date(t).getTime() > new Date(lastScrapedAt).getTime())
      ) {
        lastScrapedAt = t
      }
    }
    return {
      host,
      rows: groupRows,
      alive: groupRows.filter((r) => r.alive === true).length,
      lastScrapedAt,
    }
  })
}

function sortHostGroups(
  groups: HostGroup[],
  key: SortKey,
  dir: SortDir,
): HostGroup[] {
  const mul = dir === 'asc' ? 1 : -1
  return [...groups].sort((a, b) => {
    let cmp = 0
    switch (key) {
      case 'host':
        cmp = a.host.localeCompare(b.host)
        break
      case 'accounts':
        cmp = a.rows.length - b.rows.length
        break
      case 'alive':
        cmp = a.alive - b.alive
        break
      case 'scraped': {
        const at = a.lastScrapedAt
          ? new Date(a.lastScrapedAt).getTime()
          : 0
        const bt = b.lastScrapedAt
          ? new Date(b.lastScrapedAt).getTime()
          : 0
        cmp = at - bt
        break
      }
    }
    if (cmp !== 0) return cmp * mul
    return a.host.localeCompare(b.host)
  })
}

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

export function AdminPoolPage() {
  const qc = useQueryClient()
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
  const [statusFilter, setStatusFilter] = useState<
    'all' | 'alive' | 'dead' | 'unchecked'
  >('all')
  const [inventoryFilter, setInventoryFilter] = useState<
    'all' | 'pool' | 'nonpool'
  >('all')
  const [regionFilter, setRegionFilter] = useState<string>('all')
  const [sortKey, setSortKey] = useState<SortKey>('accounts')
  const [sortDir, setSortDir] = useState<SortDir>('desc')
  const [peopleFor, setPeopleFor] = useState<{
    id: string
    label: string
  } | null>(null)

  const list = useQuery({
    queryKey: ['admin', 'pool'],
    queryFn: async () => {
      const { data, error } = await adminDb
        .from('iptv_portals')
        .select(
          'id, url, username, alive, expiry, max_connections, region_primary, dealt_count, catalog_pool, updated_at, last_checked_at',
        )
        .order('updated_at', { ascending: false })
        .limit(5000)
      if (error) throw error
      return (data ?? []) as Cand[]
    },
  })

  const regionOptions = useMemo(() => {
    const set = new Set<string>()
    for (const c of list.data ?? []) {
      const r = (c.region_primary || 'UNKNOWN').trim() || 'UNKNOWN'
      set.add(r)
    }
    return [...set].sort((a, b) => a.localeCompare(b))
  }, [list.data])

  const filteredRows = useMemo(() => {
    const rows = list.data ?? []
    return rows.filter((c) => {
      if (inventoryFilter === 'pool' && c.catalog_pool !== true) return false
      if (inventoryFilter === 'nonpool' && c.catalog_pool === true) return false
      if (statusFilter === 'alive' && c.alive !== true) return false
      if (statusFilter === 'dead' && c.alive !== false) return false
      if (statusFilter === 'unchecked' && c.alive != null) return false
      if (
        regionFilter !== 'all' &&
        (c.region_primary || 'UNKNOWN') !== regionFilter
      ) {
        return false
      }
      return true
    })
  }, [list.data, inventoryFilter, statusFilter, regionFilter])

  const groups = useMemo(
    () => sortHostGroups(groupByHost(filteredRows), sortKey, sortDir),
    [filteredRows, sortKey, sortDir],
  )

  function toggleSort(key: SortKey) {
    if (sortKey === key) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'))
      return
    }
    setSortKey(key)
    setSortDir(key === 'host' ? 'asc' : 'desc')
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
      await qc.invalidateQueries({ queryKey: ['admin', 'pool'] })
    },
    onError: (e) => {
      setEditError(e instanceof Error ? e.message : 'Save failed')
    },
  })

  const remove = useMutation({
    mutationFn: async (id: string) => {
      // Leave the portal row (may be assigned to users) — drop from pool only.
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
      await qc.invalidateQueries({ queryKey: ['admin', 'pool'] })
    },
    onError: (e) => {
      setActionError(e instanceof Error ? e.message : 'Delete failed')
    },
  })

  function toggle(host: string) {
    setOpen((prev) => {
      const next = new Set(prev)
      if (next.has(host)) next.delete(host)
      else next.add(host)
      return next
    })
  }

  async function beginEdit(c: Cand) {
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

  async function copyShare(c: Cand) {
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
        await navigator.clipboard.writeText(code)
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

  async function checkPortal(c: Cand) {
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
      await qc.invalidateQueries({ queryKey: ['admin', 'pool'] })
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
      await qc.invalidateQueries({ queryKey: ['admin', 'pool'] })
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

      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
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
          {filteredRows.length}
          {(list.data?.length ?? 0) !== filteredRows.length
            ? ` / ${list.data?.length ?? 0}`
            : ''}{' '}
          portals
        </p>
      </div>

      <div className="overflow-hidden rounded-xl border border-forja-border">
        {list.isLoading ? (
          <p className="px-4 py-4 text-sm text-forja-muted">Loading…</p>
        ) : (list.data?.length ?? 0) === 0 ? (
          <p className="px-4 py-4 text-sm text-forja-muted">No portals.</p>
        ) : groups.length === 0 ? (
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
            {groups.map((g) => {
              const expanded = open.has(g.host)
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
                      {g.rows.length}
                    </span>
                    <span className="text-right text-sm tabular-nums text-forja-muted">
                      {g.alive}
                    </span>
                    <span className="text-right text-sm text-forja-muted">
                      {relativeTime(g.lastScrapedAt)}
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
                    <ul className="grid grid-cols-1 border-t border-forja-border bg-forja-surface/20 sm:grid-cols-2 sm:[&>li:nth-child(odd)]:border-r sm:[&>li:nth-child(odd)]:border-forja-border/70">
                      {g.rows.map((c) => (
                        <IptvPortalActionRow
                          key={c.id}
                          portal={c}
                          sharing={sharingId === c.id}
                          shareCode={shareFlash[c.id] ?? null}
                          deleting={remove.isPending}
                          checking={
                            checkingId === c.id || checkingHost === g.host
                          }
                          deleteConfirmLabel="Remove from catalog pool?"
                          deleteDisabled={c.catalog_pool !== true}
                          deleteTitle={
                            c.catalog_pool
                              ? 'Remove from catalog pool'
                              : 'Not in catalog pool'
                          }
                          onShare={() => void copyShare(c)}
                          onEdit={() => void beginEdit(c)}
                          onDelete={() => remove.mutate(c.id)}
                          onCheck={() => void checkPortal(c)}
                          onPeople={() =>
                            setPeopleFor({
                              id: c.id,
                              label: `${c.username} · ${c.url}`,
                            })
                          }
                        />
                      ))}
                    </ul>
                  ) : null}
                </div>
              )
            })}
          </>
        )}
      </div>
    </div>
  )
}
