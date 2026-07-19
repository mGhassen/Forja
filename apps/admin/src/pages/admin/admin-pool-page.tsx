import {
  useEffect,
  useMemo,
  useState,
  type Dispatch,
  type ReactNode,
  type SetStateAction,
} from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  CalendarDays,
  Check,
  Copy,
  Pencil,
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
import {
  createPortalShare,
  formatShareCode,
} from '@/lib/iptv-portal-share'
import { supabase } from '@/lib/supabase'
import { cn } from '@/lib/utils'

type Cand = {
  id: string
  url: string
  username: string
  alive: boolean | null
  expiry: string | null
  max_connections: string | null
  region_primary: string
  region_confidence: number | null
  dealt_count: number
  created_at: string
  updated_at: string
  last_checked_at: string | null
}

type ScrapeRun = {
  id: string
  started_at: string
  finished_at: string | null
  status: string
  posts_seen: number
  l1_extract_count: number
  candidates_upserted: number
  alive_count: number
  source?: string | null
  error?: string | null
}

type HostGroup = {
  host: string
  rows: Cand[]
  alive: number
  newCount: number
  lastScrapedAt: string | null
}

type EditForm = {
  url: string
  username: string
  password: string
  region_primary: string
}

const ACTION_RAIL_W = 108

function candidateHost(url: string): string {
  try {
    const u = new URL(url.includes('://') ? url : `http://${url}`)
    return u.host || url
  } catch {
    return url
  }
}

function isNewCandidate(c: Cand, sinceIso: string | null): boolean {
  if (!sinceIso) {
    const age = Date.now() - new Date(c.created_at).getTime()
    return age >= 0 && age < 48 * 60 * 60 * 1000
  }
  return new Date(c.created_at).getTime() >= new Date(sinceIso).getTime()
}

function groupByHost(rows: Cand[], sinceIso: string | null): HostGroup[] {
  const map = new Map<string, Cand[]>()
  for (const row of rows) {
    const host = candidateHost(row.url)
    const list = map.get(host)
    if (list) list.push(row)
    else map.set(host, [row])
  }
  return [...map.entries()]
    .map(([host, groupRows]) => {
      let lastScrapedAt: string | null = null
      let newCount = 0
      for (const r of groupRows) {
        if (isNewCandidate(r, sinceIso)) newCount++
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
        newCount,
        lastScrapedAt,
      }
    })
    .sort((a, b) => b.rows.length - a.rows.length || a.host.localeCompare(b.host))
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
  const day = Math.round(hr / 24)
  return `${day}d ago`
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

function RailAction({
  label,
  onClick,
  disabled,
  className,
  children,
}: {
  label: string
  onClick: () => void
  disabled?: boolean
  className?: string
  children: ReactNode
}) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      disabled={disabled}
      onClick={(e) => {
        e.stopPropagation()
        onClick()
      }}
      className={cn(
        'inline-flex size-8 shrink-0 items-center justify-center rounded-md text-white/60 transition-colors',
        'hover:bg-white/5 hover:text-white disabled:pointer-events-none disabled:opacity-40',
        className,
      )}
    >
      {children}
    </button>
  )
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

function CandidateCard({
  c,
  isNew,
  sharing,
  shareCode,
  deleting,
  onShare,
  onEdit,
  onDelete,
}: {
  c: Cand
  isNew: boolean
  sharing: boolean
  shareCode: string | null
  deleting: boolean
  onShare: () => void
  onEdit: () => void
  onDelete: () => void
}) {
  const [confirmDelete, setConfirmDelete] = useState(false)
  const expiry = portalExpiryTone(c.expiry)
  const seats = seatsTone(c.max_connections)
  const pinRail = confirmDelete || sharing || !!shareCode

  return (
    <li
      className={cn(
        'group flex min-h-[88px] items-stretch border border-forja-border/80 bg-forja-surface/40 transition-colors duration-180',
        'hover:bg-white/[0.04] focus-within:bg-white/[0.04]',
        pinRail && 'bg-white/[0.04]',
        isNew && !pinRail && 'border-l-[3px] border-l-forja-green bg-forja-green/[0.06]',
      )}
    >
      <div className="flex min-w-0 flex-1 items-center px-3 py-2.5">
        <div className="min-w-0 flex-1 space-y-1.5">
          {confirmDelete ? (
            <p className="text-[13px] font-semibold text-red-400">
              Delete this portal?
            </p>
          ) : shareCode || sharing ? (
            sharing && !shareCode ? (
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
            )
          ) : (
            <>
              <p
                className={cn(
                  'flex items-center gap-1 text-[11px] font-semibold',
                  expiry.className,
                )}
              >
                <CalendarDays className="size-3 shrink-0" />
                <span className="truncate">{expiry.label}</span>
                {c.alive === true ? (
                  <span className="text-forja-green">· alive</span>
                ) : c.alive === false ? (
                  <span className="text-red-400">· dead</span>
                ) : (
                  <span className="text-forja-muted">· ?</span>
                )}
              </p>
              <p className="flex min-w-0 items-center gap-1.5">
                {isNew ? (
                  <span className="shrink-0 rounded px-1 py-0.5 text-[9px] font-bold tracking-wider text-forja-green ring-1 ring-forja-green/50">
                    NEW
                  </span>
                ) : null}
                <span
                  className={cn(
                    'truncate text-[13px] font-semibold',
                    isNew ? 'text-forja-green' : 'text-forja-text',
                  )}
                >
                  {c.username}
                </span>
              </p>
              <p className="truncate text-[11px] text-white/40">{c.url}</p>
              <p
                className={cn(
                  'flex flex-wrap items-center gap-x-2 gap-y-0.5 text-[11px] font-semibold',
                  seats.className,
                )}
              >
                <span className="inline-flex items-center gap-1">
                  <Users className="size-3 shrink-0" />
                  {seats.label}
                </span>
                <span className="font-normal text-forja-muted">
                  {c.region_primary}
                  {c.dealt_count > 0 ? ` · dealt ${c.dealt_count}` : ''}
                  {c.last_checked_at
                    ? ` · checked ${relativeTime(c.last_checked_at)}`
                    : ''}
                </span>
              </p>
            </>
          )}
        </div>
      </div>

      <div
        className={cn(
          'flex shrink-0 items-center justify-end overflow-hidden transition-[width] duration-180 ease-out',
          pinRail
            ? 'w-[108px]'
            : 'w-0 group-hover:w-[108px] group-focus-within:w-[108px]',
        )}
      >
        <div
          className="flex h-full shrink-0 items-center justify-end pr-1"
          style={{ width: ACTION_RAIL_W }}
        >
          {confirmDelete ? (
            <>
              <RailAction
                label="Yes"
                className="text-red-400 hover:text-red-300"
                disabled={deleting}
                onClick={() => {
                  setConfirmDelete(false)
                  onDelete()
                }}
              >
                <Check className="size-4" />
              </RailAction>
              <RailAction
                label="No"
                onClick={() => setConfirmDelete(false)}
              >
                <X className="size-4" />
              </RailAction>
            </>
          ) : (
            <>
              <RailAction
                label="Copy share code"
                disabled={sharing}
                onClick={onShare}
              >
                {sharing ? (
                  <Share2 className="size-4 animate-pulse" />
                ) : shareCode ? (
                  <Check className="size-4 text-forja-green" />
                ) : (
                  <Copy className="size-4" />
                )}
              </RailAction>
              <RailAction label="Edit" onClick={onEdit}>
                <Pencil className="size-4" />
              </RailAction>
              <RailAction
                label="Delete"
                className="text-red-400 hover:text-red-300"
                onClick={() => setConfirmDelete(true)}
              >
                <Trash2 className="size-4" />
              </RailAction>
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
  const [actionError, setActionError] = useState<string | null>(null)

  const runs = useQuery({
    queryKey: ['admin', 'scrape_runs', 'latest'],
    queryFn: async () => {
      const { data, error } = await adminDb
        .from('iptv_scrape_runs')
        .select(
          'id, started_at, finished_at, status, posts_seen, l1_extract_count, candidates_upserted, alive_count, source, error',
        )
        .order('started_at', { ascending: false })
        .limit(5)
      if (error) throw error
      return (data ?? []) as ScrapeRun[]
    },
    refetchInterval: (q) =>
      q.state.data?.some((r) => r.status === 'running') ? 4_000 : 20_000,
  })

  const latestRun = runs.data?.[0] ?? null
  const running = latestRun?.status === 'running'
  const newSince = latestRun?.started_at ?? null

  const list = useQuery({
    queryKey: ['admin', 'pool'],
    queryFn: async () => {
      const { data, error } = await adminDb
        .from('iptv_catalog_candidates')
        .select(
          'id, url, username, alive, expiry, max_connections, region_primary, region_confidence, dealt_count, created_at, updated_at, last_checked_at',
        )
        .order('updated_at', { ascending: false })
        .limit(300)
      if (error) throw error
      return (data ?? []) as Cand[]
    },
    refetchInterval: running ? 8_000 : false,
  })

  const groups = useMemo(
    () => groupByHost(list.data ?? [], newSince),
    [list.data, newSince],
  )

  const startScrape = useMutation({
    mutationFn: async () => {
      const {
        data: { session },
      } = await supabase.auth.getSession()
      if (!session?.access_token) throw new Error('Not signed in')
      const res = await fetch('/api/iptv-catalog-scrape', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({}),
      })
      const json = (await res.json().catch(() => ({}))) as {
        error?: string
        ok?: boolean
      }
      if (!res.ok) {
        throw new Error(json.error || 'Could not start scrape')
      }
    },
    onSuccess: async () => {
      setActionError(null)
      await qc.invalidateQueries({ queryKey: ['admin', 'scrape_runs'] })
    },
    onError: (e) => {
      setActionError(errMessage(e, 'Could not start scrape'))
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
        .from('iptv_catalog_candidates')
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
      const { error } = await adminDb
        .from('iptv_catalog_candidates')
        .delete()
        .eq('id', id)
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

  return (
    <div className="space-y-4">
      <h1 className="font-disp text-xl font-bold tracking-tight">
        Catalog pool
      </h1>
      <p className="text-sm text-forja-muted">
        Grouped by host · NEW = created since latest scrape run · hover for
        copy / edit / delete.
      </p>

      <div className="flex flex-wrap items-start justify-between gap-3 rounded-xl border border-forja-border bg-forja-elevated/40 px-4 py-3">
        <div className="min-w-0 space-y-1">
          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-forja-muted">
            Scrape
          </p>
          {latestRun ? (
            <p className="text-sm text-forja-text">
              <span
                className={cn(
                  'font-semibold',
                  latestRun.status === 'running' && 'text-amber-400',
                  latestRun.status === 'ok' && 'text-forja-green',
                  latestRun.status === 'error' && 'text-red-400',
                )}
              >
                {latestRun.status}
              </span>
              <span className="text-forja-muted">
                {' '}
                · run{' '}
                <code className="font-mono-ui text-xs">
                  {shortRunId(latestRun.id)}
                </code>{' '}
                · started {relativeTime(latestRun.started_at)}
                {latestRun.status !== 'running'
                  ? ` · upserted ${latestRun.candidates_upserted} · alive ${latestRun.alive_count}`
                  : ` · posts ${latestRun.posts_seen} · L1 ${latestRun.l1_extract_count}`}
              </span>
            </p>
          ) : (
            <p className="text-sm text-forja-muted">No scrape runs yet.</p>
          )}
          {latestRun?.error ? (
            <p className="text-xs text-red-400">{latestRun.error}</p>
          ) : null}
        </div>
        <Button
          type="button"
          variant="secondary"
          disabled={running || startScrape.isPending}
          onClick={() => startScrape.mutate()}
        >
          {running
            ? 'Scraping…'
            : startScrape.isPending
              ? 'Starting…'
              : 'Start scrape'}
        </Button>
      </div>

      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
      ) : null}
      {actionError ? (
        <p className="text-sm text-red-400">{actionError}</p>
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

      <div className="overflow-hidden rounded-xl border border-forja-border">
        {list.isLoading ? (
          <p className="px-3 py-4 text-sm text-forja-muted">Loading…</p>
        ) : groups.length === 0 ? (
          <p className="px-3 py-4 text-sm text-forja-muted">Pool is empty.</p>
        ) : (
          groups.map((g) => {
            const expanded = open.has(g.host)
            return (
              <div
                key={g.host}
                className="border-t border-forja-border first:border-t-0"
              >
                <button
                  type="button"
                  onClick={() => toggle(g.host)}
                  aria-expanded={expanded}
                  className="flex w-full flex-wrap items-center gap-x-2 gap-y-1 bg-forja-elevated/60 px-3 py-2.5 text-left hover:bg-white/5"
                >
                  <span
                    className="inline-block w-3 shrink-0 font-mono-ui text-xs text-forja-muted"
                    aria-hidden
                  >
                    {expanded ? '▾' : '▸'}
                  </span>
                  <span className="font-mono-ui text-xs font-semibold text-forja-text">
                    {g.host}
                  </span>
                  <span className="font-sans text-xs text-forja-muted">
                    {g.rows.length} acct
                    {g.rows.length === 1 ? '' : 's'}
                    {g.alive > 0 ? ` · ${g.alive} alive` : ''}
                    {g.newCount > 0 ? (
                      <span className="text-forja-green">
                        {` · ${g.newCount} new`}
                      </span>
                    ) : null}
                    {` · scraped ${relativeTime(g.lastScrapedAt)}`}
                    {latestRun
                      ? ` · run ${shortRunId(latestRun.id)} ${relativeTime(latestRun.started_at)}`
                      : ''}
                  </span>
                </button>
                {expanded ? (
                  <ul className="grid grid-cols-1 gap-2 p-2 sm:grid-cols-2">
                    {g.rows.map((c) => (
                      <CandidateCard
                        key={c.id}
                        c={c}
                        isNew={isNewCandidate(c, newSince)}
                        sharing={sharingId === c.id}
                        shareCode={shareFlash[c.id] ?? null}
                        deleting={remove.isPending}
                        onShare={() => void copyShare(c)}
                        onEdit={() => void beginEdit(c)}
                        onDelete={() => remove.mutate(c.id)}
                      />
                    ))}
                  </ul>
                ) : null}
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}
