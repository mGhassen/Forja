import {
  useEffect,
  useMemo,
  useState,
  type Dispatch,
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
import { scrapeControl } from '@/lib/scrape-control'
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

type ScrapeRun = {
  id: string
  started_at: string
  finished_at: string | null
  status: string
  posts_seen: number
  l1_extract_count: number
  candidates_upserted: number
  alive_count: number
  error?: string | null
}

type HostGroup = {
  host: string
  rows: Cand[]
  alive: number
  lastScrapedAt: string | null
}

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
  return [...map.entries()]
    .map(([host, groupRows]) => {
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

/** Same row chrome as Account → IPTV portals. */
function CandidateRow({
  c,
  sharing,
  shareCode,
  deleting,
  onShare,
  onEdit,
  onDelete,
}: {
  c: Cand
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

  return (
    <li className="flex min-h-22 items-center gap-2 px-0.5 py-2.5">
      {confirmDelete ? (
        <div className="min-w-0 flex-1">
          <p className="text-[13px] font-semibold text-red-400">
            Delete this portal?
          </p>
        </div>
      ) : shareCode || sharing ? (
        <div className="min-w-0 flex-1">
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
          <p className="truncate text-[13px] font-semibold text-forja-text">
            {c.username}
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

      <div className="flex shrink-0 items-center self-center">
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
              disabled={sharing}
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
              aria-label="Delete portal"
              onClick={() => setConfirmDelete(true)}
            >
              <Trash2 className="size-4" />
            </Button>
          </>
        )}
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
          'id, started_at, finished_at, status, posts_seen, l1_extract_count, candidates_upserted, alive_count, error',
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

  const list = useQuery({
    queryKey: ['admin', 'pool'],
    queryFn: async () => {
      const { data, error } = await adminDb
        .from('iptv_catalog_candidates')
        .select(
          'id, url, username, alive, expiry, max_connections, region_primary, dealt_count, updated_at, last_checked_at',
        )
        .order('updated_at', { ascending: false })
        .limit(300)
      if (error) throw error
      return (data ?? []) as Cand[]
    },
    refetchInterval: running ? 8_000 : false,
  })

  const groups = useMemo(() => groupByHost(list.data ?? []), [list.data])

  const startScrape = useMutation({
    mutationFn: () => scrapeControl('start'),
    onSuccess: async () => {
      setActionError(null)
      await qc.invalidateQueries({ queryKey: ['admin', 'scrape_runs'] })
    },
    onError: (e) => {
      setActionError(errMessage(e, 'Could not start scrape'))
    },
  })

  const stopScrape = useMutation({
    mutationFn: () =>
      scrapeControl('stop', { runId: latestRun?.id }),
    onSuccess: async () => {
      setActionError(null)
      await qc.invalidateQueries({ queryKey: ['admin', 'scrape_runs'] })
    },
    onError: (e) => {
      setActionError(errMessage(e, 'Could not stop scrape'))
    },
  })

  const markStuck = useMutation({
    mutationFn: () => scrapeControl('mark_stuck'),
    onSuccess: async () => {
      setActionError(null)
      await qc.invalidateQueries({ queryKey: ['admin', 'scrape_runs'] })
    },
    onError: (e) => {
      setActionError(errMessage(e, 'Could not mark stuck'))
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
    <div className="space-y-6">
      <div>
        <h1 className="font-disp text-xl font-bold tracking-tight">
          Catalog pool
        </h1>
        <p className="mt-1 text-sm text-forja-muted">
          Grouped by host. Copy, edit, or delete like Account → IPTV.
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
            href="http://127.0.0.1:8288"
            target="_blank"
            rel="noreferrer"
            className="text-forja-green hover:underline"
          >
            :8288
          </a>
        </p>
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

      <div className="space-y-3">
        {list.isLoading ? (
          <p className="text-sm text-forja-muted">Loading…</p>
        ) : groups.length === 0 ? (
          <p className="text-sm text-forja-muted">Pool is empty.</p>
        ) : (
          groups.map((g) => {
            const expanded = open.has(g.host)
            return (
              <div
                key={g.host}
                className="overflow-hidden rounded-xl border border-forja-border"
              >
                <button
                  type="button"
                  onClick={() => toggle(g.host)}
                  aria-expanded={expanded}
                  className="flex w-full items-start gap-3 px-4 py-3.5 text-left hover:bg-white/[0.03]"
                >
                  <span
                    className="mt-0.5 w-4 shrink-0 text-forja-muted"
                    aria-hidden
                  >
                    {expanded ? '▾' : '▸'}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[15px] font-semibold text-forja-text">
                      {g.host}
                    </p>
                    <p className="mt-1 text-sm text-forja-muted">
                      {g.rows.length} account{g.rows.length === 1 ? '' : 's'}
                      {g.alive > 0 ? ` · ${g.alive} alive` : ''}
                    </p>
                    <p className="mt-0.5 text-sm text-forja-muted">
                      Scraped {relativeTime(g.lastScrapedAt)}
                    </p>
                  </div>
                </button>
                {expanded ? (
                  <ul className="divide-y divide-forja-border border-t border-forja-border px-4">
                    {g.rows.map((c) => (
                      <CandidateRow
                        key={c.id}
                        c={c}
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
