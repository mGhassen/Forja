import {
  useEffect,
  useMemo,
  useState,
  type Dispatch,
  type SetStateAction,
} from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowDown,
  ArrowUp,
  CalendarDays,
  Check,
  Copy,
  Pencil,
  Radio,
  Share2,
  Trash2,
  Users,
  X,
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { PasswordInput } from '@/components/ui/password-input'
import { adminDb } from '@/lib/admin-db'
import { catalogVerify } from '@/lib/catalog-verify'
import { INNGEST_UI_URL, isInngestLocalUi } from '@/lib/inngest-ui'
import {
  createPortalShare,
  formatShareCode,
} from '@/lib/iptv-portal-share'
import { scrapeControl } from '@/lib/scrape-control'
import {
  SCRAPE_RUNS_LATEST_KEY,
  fetchScrapeRuns,
  markRunsStoppedInCache,
  prependOptimisticRun,
  refreshScrapeRuns,
  subscribeScrapeRuns,
  type ScrapeRunRow,
} from '@/lib/scrape-runs'
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
  updated_at: string
  last_checked_at: string | null
}

type ScrapeRun = ScrapeRunRow

type HostGroup = {
  host: string
  rows: Cand[]
  alive: number
  lastScrapedAt: string | null
}

type SortKey = 'host' | 'accounts' | 'alive' | 'scraped'
type SortDir = 'asc' | 'desc'

type EditForm = {
  url: string
  username: string
  password: string
  region_primary: string
}

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

function shortRunId(id: string): string {
  return id.replace(/-/g, '').slice(0, 8)
}

function portalExpiryTone(expiry?: string | null): {
  label: string
  className: string
} {
  const label = (expiry ?? '').trim() || 'Unknown'
  const end = (() => {
    const d = new Date(label)
    return Number.isNaN(d.getTime()) ? null : d
  })()
  if (!end) {
    return {
      label: label === 'Unknown' ? 'Ends: Unknown' : `Ends: ${label}`,
      className: 'text-forja-muted',
    }
  }
  const today = new Date()
  const midnight = new Date(
    today.getFullYear(),
    today.getMonth(),
    today.getDate(),
  )
  const days = Math.floor((end.getTime() - midnight.getTime()) / 86_400_000)
  const className =
    days < 0
      ? 'text-red-400'
      : days <= 7
        ? 'text-amber-400'
        : days <= 30
          ? 'text-yellow-400'
          : 'text-forja-green'
  return {
    label: `${days < 0 ? 'Expired' : 'Ends'} ${label}`,
    className,
  }
}

function seatsTone(max?: string | null) {
  const cap = (max ?? '').trim() || '?'
  return {
    label: `Max ${cap}`,
    className: 'text-sky-400',
  }
}

function errMessage(e: unknown, fallback: string): string {
  if (e instanceof Error && e.message) return e.message
  if (typeof e === 'object' && e && 'message' in e) {
    const m = (e as { message: unknown }).message
    if (typeof m === 'string' && m.trim()) return m
  }
  if (typeof e === 'string' && e.trim()) return e
  return fallback
}

async function decryptPassword(id: string): Promise<string> {
  const { data, error } = await adminDb.rpc(
    'admin_iptv_catalog_candidate_password',
    { p_id: id },
  )
  if (error) {
    const msg = errMessage(error, 'decrypt failed')
    if (/does not exist|could not find.*function/i.test(msg)) {
      throw new Error(
        'Missing RPC admin_iptv_catalog_candidate_password — apply migration 20260719015100_admin_catalog_candidate_ops',
      )
    }
    throw new Error(msg)
  }
  return typeof data === 'string' ? data : ''
}

function EditDialog({
  form,
  setForm,
  saving,
  error,
  onClose,
  onSave,
}: {
  form: EditForm
  setForm: Dispatch<SetStateAction<EditForm>>
  saving: boolean
  error: string | null
  onClose: () => void
  onSave: () => void
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
      role="presentation"
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="edit-cand-title"
        className="w-full max-w-lg border border-forja-border bg-forja-elevated p-5 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-center justify-between gap-2">
          <h2 id="edit-cand-title" className="text-sm font-semibold">
            Edit portal
          </h2>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="h-8 w-8 p-0"
            aria-label="Close"
            onClick={onClose}
          >
            <X className="size-4" />
          </Button>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="space-y-2 sm:col-span-2">
            <Label htmlFor="cand-url">Panel URL</Label>
            <Input
              id="cand-url"
              value={form.url}
              onChange={(e) => setForm((f) => ({ ...f, url: e.target.value }))}
              autoFocus
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="cand-user">Username</Label>
            <Input
              id="cand-user"
              value={form.username}
              onChange={(e) =>
                setForm((f) => ({ ...f, username: e.target.value }))
              }
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="cand-pass">Password</Label>
            <PasswordInput
              id="cand-pass"
              value={form.password}
              onChange={(e) =>
                setForm((f) => ({ ...f, password: e.target.value }))
              }
            />
          </div>
          <div className="space-y-2 sm:col-span-2">
            <Label htmlFor="cand-region">Region</Label>
            <Input
              id="cand-region"
              value={form.region_primary}
              onChange={(e) =>
                setForm((f) => ({ ...f, region_primary: e.target.value }))
              }
            />
          </div>
          {error ? (
            <p className="text-sm text-red-400 sm:col-span-2">{error}</p>
          ) : null}
          <div className="flex gap-2 sm:col-span-2">
            <Button
              type="button"
              variant="secondary"
              disabled={
                saving || !form.url.trim() || !form.username.trim()
              }
              onClick={onSave}
            >
              {saving ? 'Saving…' : 'Save portal'}
            </Button>
            <Button type="button" variant="ghost" onClick={onClose}>
              Cancel
            </Button>
          </div>
        </div>
      </div>
    </div>
  )
}

const ACTION_RAIL_W = 144

function aliveTone(alive: boolean | null): {
  label: string
  className: string
  dotClass: string
} {
  if (alive === true)
    return {
      label: 'Alive',
      className: 'text-forja-green',
      dotClass: 'bg-forja-green shadow-[0_0_8px_rgba(28,231,131,0.55)]',
    }
  if (alive === false)
    return {
      label: 'Dead',
      className: 'text-red-400',
      dotClass: 'bg-red-500',
    }
  return {
    label: 'Unchecked',
    className: 'text-forja-muted',
    dotClass: 'bg-white/25',
  }
}

/** Table-style portal row — Account→IPTV content, actions on hover. */
function CandidateRow({
  c,
  sharing,
  shareCode,
  deleting,
  checking,
  onShare,
  onEdit,
  onDelete,
  onCheck,
}: {
  c: Cand
  sharing: boolean
  shareCode: string | null
  deleting: boolean
  checking: boolean
  onShare: () => void
  onEdit: () => void
  onDelete: () => void
  onCheck: () => void
}) {
  const [confirmDelete, setConfirmDelete] = useState(false)
  const expiry = portalExpiryTone(c.expiry)
  const seats = seatsTone(c.max_connections)
  const status = aliveTone(c.alive)
  const pinRail = confirmDelete || sharing || !!shareCode || checking

  return (
    <li
      className={cn(
        'group flex min-h-22 items-stretch border-b border-forja-border/70 last:border-b-0',
        'hover:bg-white/[0.03] focus-within:bg-white/[0.03]',
        pinRail && 'bg-white/[0.03]',
      )}
    >
      <div className="flex min-w-0 flex-1 items-center px-3 py-2.5">
        {confirmDelete ? (
          <p className="text-[13px] font-semibold text-red-400">
            Delete this portal?
          </p>
        ) : shareCode || sharing ? (
          <div className="min-w-0">
            {sharing && !shareCode ? (
              <p className="text-sm text-forja-muted">Creating share code…</p>
            ) : (
              <>
                <p className="text-[10px] font-semibold tracking-wider text-forja-muted">
                  SHARE CODE
                </p>
                <p className="mt-1 font-mono text-lg font-bold tracking-[0.18em] text-forja-green">
                  {shareCode}
                </p>
              </>
            )}
          </div>
        ) : (
          <div className="min-w-0 flex-1 space-y-1">
            <p
              className={cn(
                'flex items-center gap-1.5 text-[11px] font-semibold',
                expiry.className,
              )}
            >
              <CalendarDays className="size-3 shrink-0" />
              <span className="truncate">{expiry.label}</span>
            </p>
            <p className="flex min-w-0 items-center gap-2">
              <span
                className={cn(
                  'size-2 shrink-0 rounded-full',
                  checking ? 'animate-pulse bg-amber-400' : status.dotClass,
                )}
                title={checking ? 'Checking…' : status.label}
                aria-label={checking ? 'Checking status' : status.label}
              />
              <span className="truncate text-[13px] font-semibold text-forja-text">
                {c.username}
              </span>
            </p>
            <p className="truncate text-sm text-white/55">{c.url}</p>
            <p
              className={cn(
                'flex items-center gap-1.5 text-[11px] font-semibold',
                seats.className,
              )}
            >
              <Users className="size-3 shrink-0" />
              <span>{seats.label}</span>
            </p>
          </div>
        )}
      </div>

      <div
        className={cn(
          'flex shrink-0 items-center justify-end overflow-hidden transition-[width] duration-180 ease-out',
          pinRail
            ? 'w-[144px]'
            : 'w-0 group-hover:w-[144px] group-focus-within:w-[144px]',
        )}
      >
        <div
          className="flex h-full shrink-0 items-center justify-end pr-1"
          style={{ width: ACTION_RAIL_W }}
        >
          {confirmDelete ? (
            <>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0 text-red-400 hover:text-red-300"
                disabled={deleting}
                aria-label="Confirm delete"
                onClick={() => {
                  setConfirmDelete(false)
                  onDelete()
                }}
              >
                <Check className="size-4" />
              </Button>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0"
                aria-label="Cancel delete"
                onClick={() => setConfirmDelete(false)}
              >
                <X className="size-4" />
              </Button>
            </>
          ) : (
            <>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0"
                disabled={checking || sharing}
                aria-label="Check portal status"
                title="Check portal status"
                onClick={onCheck}
              >
                <Radio
                  className={cn(
                    'size-4',
                    checking && 'animate-pulse text-amber-400',
                  )}
                />
              </Button>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0"
                disabled={sharing || checking}
                aria-label="Copy share code"
                title="Copy share code"
                onClick={onShare}
              >
                {sharing ? (
                  <Share2 className="size-4 animate-pulse" />
                ) : shareCode ? (
                  <Check className="size-4 text-forja-green" />
                ) : (
                  <Copy className="size-4" />
                )}
              </Button>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0"
                disabled={checking}
                aria-label="Edit portal"
                onClick={onEdit}
              >
                <Pencil className="size-4" />
              </Button>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0 text-red-400 hover:text-red-300"
                disabled={checking}
                aria-label="Delete portal"
                onClick={() => setConfirmDelete(true)}
              >
                <Trash2 className="size-4" />
              </Button>
            </>
          )}
        </div>
      </div>
    </li>
  )
}

export function AdminPoolPage() {
  const qc = useQueryClient()
  const [open, setOpen] = useState<Set<string>>(() => new Set())
  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState<EditForm>({
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
  const [regionFilter, setRegionFilter] = useState<string>('all')
  const [sortKey, setSortKey] = useState<SortKey>('accounts')
  const [sortDir, setSortDir] = useState<SortDir>('desc')

  const runs = useQuery({
    queryKey: SCRAPE_RUNS_LATEST_KEY,
    queryFn: () => fetchScrapeRuns(5),
    refetchInterval: (q) =>
      q.state.data?.some((r) => r.status === 'running') ? 1_500 : 10_000,
    refetchOnWindowFocus: true,
  })

  useEffect(() => {
    return subscribeScrapeRuns(() => {
      void refreshScrapeRuns(qc)
    })
  }, [qc])

  const latestRun = runs.data?.[0] ?? null
  const running = latestRun?.status === 'running'

  const list = useQuery({
    queryKey: ['admin', 'pool'],
    queryFn: async () => {
      const { data, error } = await adminDb
        .from('iptv_portals')
        .select(
          'id, url, username, alive, expiry, max_connections, region_primary, dealt_count, updated_at, last_checked_at',
        )
        .eq('catalog_pool', true)
        .order('updated_at', { ascending: false })
        .limit(300)
      if (error) throw error
      return (data ?? []) as Cand[]
    },
    refetchInterval: running ? 8_000 : false,
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
  }, [list.data, statusFilter, regionFilter])

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

  const startScrape = useMutation({
    mutationFn: () => scrapeControl('start'),
    onSuccess: async (res) => {
      setActionError(null)
      if (res.run) prependOptimisticRun(qc, res.run)
      else if (res.runId) {
        prependOptimisticRun(qc, {
          id: res.runId,
          started_at: new Date().toISOString(),
          status: 'running',
          source: 'manual-admin',
        })
      }
      await refreshScrapeRuns(qc)
    },
    onError: (e) => {
      setActionError(errMessage(e, 'Could not start scrape'))
    },
  })

  const stopScrape = useMutation({
    mutationFn: () =>
      scrapeControl('stop', { runId: latestRun?.id }),
    onMutate: async () => {
      await qc.cancelQueries({ queryKey: ['admin', 'scrape_runs'] })
      markRunsStoppedInCache(qc, {
        runId: latestRun?.id,
        error: 'Stop requested from admin',
      })
    },
    onSuccess: async () => {
      setActionError(null)
      await refreshScrapeRuns(qc)
    },
    onError: async (e) => {
      setActionError(errMessage(e, 'Could not stop scrape'))
      await refreshScrapeRuns(qc)
    },
  })

  const markStuck = useMutation({
    mutationFn: () => scrapeControl('mark_stuck'),
    onMutate: async () => {
      await qc.cancelQueries({ queryKey: ['admin', 'scrape_runs'] })
      markRunsStoppedInCache(qc, {
        error: 'Marked stuck from admin (Inngest may have died)',
      })
    },
    onSuccess: async () => {
      setActionError(null)
      await refreshScrapeRuns(qc)
    },
    onError: async (e) => {
      setActionError(errMessage(e, 'Could not mark stuck'))
      await refreshScrapeRuns(qc)
    },
  })

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
        .eq('catalog_pool', true)
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
      const pw = await decryptPassword(id)
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
      const password = await decryptPassword(c.id)
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
      <div>
        <h1 className="font-disp text-xl font-bold tracking-tight">
          Catalog pool
        </h1>
        <p className="mt-1 text-sm text-forja-muted">
          Grouped by host. Check status, copy, edit, or delete.
        </p>
      </div>

      <div className="rounded-xl border border-forja-border bg-forja-elevated/40 px-5 py-4">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div className="min-w-0 space-y-1">
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted">
              Scrape
            </p>
            {latestRun ? (
              <>
                <p
                  className={cn(
                    'text-base font-semibold capitalize',
                    latestRun.status === 'running' && 'text-amber-400',
                    latestRun.status === 'ok' && 'text-forja-green',
                    latestRun.status === 'error' && 'text-red-400',
                  )}
                >
                  {latestRun.status}
                </p>
                <p className="text-sm text-forja-muted">
                  Started {relativeTime(latestRun.started_at)}
                  {latestRun.status === 'running'
                    ? ` · ${latestRun.posts_seen} posts`
                    : ` · ${latestRun.candidates_upserted} upserted · ${latestRun.alive_count} alive`}
                </p>
                <p className="font-mono-ui text-xs text-forja-muted/80">
                  {shortRunId(latestRun.id)}
                </p>
              </>
            ) : (
              <p className="text-sm text-forja-muted">No scrape runs yet.</p>
            )}
            {latestRun?.error ? (
              <p className="text-sm text-red-400">{latestRun.error}</p>
            ) : null}
          </div>
          <div className="flex flex-wrap gap-2">
            {running ? (
              <>
                <Button
                  type="button"
                  variant="secondary"
                  disabled={stopScrape.isPending || markStuck.isPending}
                  onClick={() => stopScrape.mutate()}
                >
                  {stopScrape.isPending ? 'Stopping…' : 'Stop'}
                </Button>
                <Button
                  type="button"
                  variant="ghost"
                  disabled={stopScrape.isPending || markStuck.isPending}
                  onClick={() => markStuck.mutate()}
                >
                  Mark stuck
                </Button>
              </>
            ) : (
              <Button
                type="button"
                variant="secondary"
                disabled={startScrape.isPending}
                onClick={() => startScrape.mutate()}
              >
                {startScrape.isPending ? 'Starting…' : 'Start scrape'}
              </Button>
            )}
          </div>
        </div>
        <p className="mt-3 text-xs text-forja-muted">
          Logs + cron: open{' '}
          <a href="/scrape" className="text-forja-green hover:underline">
            Scrape
          </a>{' '}
          · Inngest{' '}
          <a
            href={INNGEST_UI_URL}
            target="_blank"
            rel="noreferrer"
            className="text-forja-green hover:underline"
          >
            {isInngestLocalUi ? ':8288' : 'Cloud'}
          </a>
        </p>
      </div>

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
        <EditDialog
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

      <div className="flex flex-wrap items-end gap-3">
        <div className="space-y-1.5">
          <label
            htmlFor="pool-status-filter"
            className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted"
          >
            Status
          </label>
          <select
            id="pool-status-filter"
            value={statusFilter}
            onChange={(e) =>
              setStatusFilter(
                e.target.value as 'all' | 'alive' | 'dead' | 'unchecked',
              )
            }
            className="h-9 rounded-md border border-forja-border bg-forja-elevated px-2.5 text-sm text-forja-text outline-none focus:border-forja-green/50"
          >
            <option value="all">All</option>
            <option value="alive">Alive</option>
            <option value="dead">Dead</option>
            <option value="unchecked">Unchecked</option>
          </select>
        </div>
        <div className="space-y-1.5">
          <label
            htmlFor="pool-region-filter"
            className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted"
          >
            Region
          </label>
          <select
            id="pool-region-filter"
            value={regionFilter}
            onChange={(e) => setRegionFilter(e.target.value)}
            className="h-9 min-w-[8rem] rounded-md border border-forja-border bg-forja-elevated px-2.5 text-sm text-forja-text outline-none focus:border-forja-green/50"
          >
            <option value="all">All</option>
            {regionOptions.map((r) => (
              <option key={r} value={r}>
                {r}
              </option>
            ))}
          </select>
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
          <p className="px-4 py-4 text-sm text-forja-muted">Pool is empty.</p>
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
                        <CandidateRow
                          key={c.id}
                          c={c}
                          sharing={sharingId === c.id}
                          shareCode={shareFlash[c.id] ?? null}
                          deleting={remove.isPending}
                          checking={
                            checkingId === c.id || checkingHost === g.host
                          }
                          onShare={() => void copyShare(c)}
                          onEdit={() => void beginEdit(c)}
                          onDelete={() => remove.mutate(c.id)}
                          onCheck={() => void checkPortal(c)}
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
