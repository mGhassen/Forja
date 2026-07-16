import { useEffect, useMemo, useRef, useState } from 'react'
import {
  CalendarDays,
  Check,
  ChevronLeft,
  ChevronRight,
  Copy,
  Download,
  Pencil,
  Plus,
  Search,
  Share2,
  Star,
  Trash2,
  Upload,
  Users,
  X,
} from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { SettingsSection } from '@/components/settings-section'
import { useUserSetting } from '@/hooks/use-user-setting'
import {
  downloadTextFile,
  iptvPortalsCsvFilename,
  mergePortalsFromCsv,
  parsePortalsCsv,
  portalsToCsv,
  type MergePortalsCsvLogEntry,
} from '@/lib/iptv-portal-csv'
import {
  createPortalShare,
  formatShareCode,
  isValidShareCode,
  normalizeShareCode,
  resolvePortalShare,
} from '@/lib/iptv-portal-share'
import {
  emptyIptvPayload,
  portalDisplayLabel,
  portalKey,
  SYNC_DOMAINS,
  type IptvPayload,
  type IptvPortalRow,
  type M3uPlaylistRow,
} from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

const PAGE_SIZE = 10

function newM3uId() {
  return `${Date.now().toString(16)}_${Math.random().toString(16).slice(2, 10)}`
}

/** Match desktop `_portalExpiryTone` (iptv_catalog_portal_form.dart). */
function portalExpiryTone(expiry?: string): { label: string; className: string } {
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
  const midnight = new Date(today.getFullYear(), today.getMonth(), today.getDate())
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

function seatsTone(active?: string, max?: string) {
  const used = (active ?? '').trim() || '0'
  const cap = (max ?? '').trim() || '?'
  const activeN = Number.parseInt(used, 10)
  const maxN = Number.parseInt(cap, 10)
  const full =
    Number.isFinite(activeN) &&
    Number.isFinite(maxN) &&
    maxN > 0 &&
    activeN >= maxN
  return {
    label: `${used}/${cap}`,
    className: full ? 'text-zinc-400' : 'text-sky-400',
  }
}

function pageSlice<T>(items: T[], page: number) {
  const totalPages = Math.max(1, Math.ceil(items.length / PAGE_SIZE))
  const safePage = Math.min(Math.max(page, 1), totalPages)
  const start = (safePage - 1) * PAGE_SIZE
  return {
    page: safePage,
    totalPages,
    start: items.length === 0 ? 0 : start + 1,
    end: Math.min(start + PAGE_SIZE, items.length),
    items: items.slice(start, start + PAGE_SIZE),
  }
}

function ListPager({
  page,
  totalPages,
  start,
  end,
  total,
  label,
  onPageChange,
}: {
  page: number
  totalPages: number
  start: number
  end: number
  total: number
  label: string
  onPageChange: (page: number) => void
}) {
  if (total === 0) return null
  return (
    <div className="mt-2 flex items-center justify-between gap-3 text-xs text-forja-muted">
      <span>
        {start}–{end} of {total} {label}
      </span>
      {totalPages > 1 ? (
        <div className="flex items-center gap-1">
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="h-7 w-7 p-0"
            disabled={page <= 1}
            aria-label="Previous page"
            onClick={() => onPageChange(page - 1)}
          >
            <ChevronLeft className="size-4" />
          </Button>
          <span className="min-w-12 text-center">
            {page}/{totalPages}
          </span>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="h-7 w-7 p-0"
            disabled={page >= totalPages}
            aria-label="Next page"
            onClick={() => onPageChange(page + 1)}
          >
            <ChevronRight className="size-4" />
          </Button>
        </div>
      ) : null}
    </div>
  )
}

type AddMode = 'share' | 'manual'

export function AccountSettingsIptvPage() {
  const { data, profileId, isLoading, save, isSaving, saveError } =
    useUserSetting<IptvPayload>(SYNC_DOMAINS.iptv)
  const [draft, setDraft] = useState<IptvPayload>(emptyIptvPayload())
  const [portalQuery, setPortalQuery] = useState('')
  const [m3uQuery, setM3uQuery] = useState('')
  const [addOpen, setAddOpen] = useState(false)
  const [addMode, setAddMode] = useState<AddMode>('share')
  const [shareCode, setShareCode] = useState('')
  const [shareBusy, setShareBusy] = useState(false)
  const [shareError, setShareError] = useState<string | null>(null)
  const [portalForm, setPortalForm] = useState({
    url: '',
    username: '',
    password: '',
    label: '',
  })
  const [editingKey, setEditingKey] = useState<string | null>(null)
  const [shareFlash, setShareFlash] = useState<Record<string, string>>({})
  const [sharingKey, setSharingKey] = useState<string | null>(null)
  const [m3uForm, setM3uForm] = useState({ name: '', sourceUrl: '' })
  const [savedFlash, setSavedFlash] = useState(false)
  const [csvLog, setCsvLog] = useState<MergePortalsCsvLogEntry[] | null>(null)
  const [csvLogSummary, setCsvLogSummary] = useState<string | null>(null)
  const [csvError, setCsvError] = useState<string | null>(null)
  const [csvImportBusy, setCsvImportBusy] = useState(false)
  const [portalPage, setPortalPage] = useState(1)
  const [m3uPage, setM3uPage] = useState(1)
  const csvInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    setDraft(emptyIptvPayload())
    setPortalQuery('')
    setM3uQuery('')
    setAddOpen(false)
    setEditingKey(null)
    setPortalPage(1)
    setM3uPage(1)
    setCsvLog(null)
    setCsvLogSummary(null)
    setCsvError(null)
  }, [profileId])

  useEffect(() => {
    setPortalPage(1)
  }, [portalQuery])

  useEffect(() => {
    setM3uPage(1)
  }, [m3uQuery])

  useEffect(() => {
    if (!data) return
    setDraft({
      portals: data.payload.portals ?? [],
      favoriteKeys: data.payload.favoriteKeys ?? [],
      m3uPlaylists: data.payload.m3uPlaylists ?? [],
    })
  }, [data])

  const favorites = useMemo(
    () => new Set(draft.favoriteKeys ?? []),
    [draft.favoriteKeys],
  )

  const sortedPortals = useMemo(() => {
    const list = [...draft.portals]
    list.sort((a, b) => {
      const aFav = favorites.has(portalKey(a)) ? 0 : 1
      const bFav = favorites.has(portalKey(b)) ? 0 : 1
      if (aFav !== bFav) return aFav - bFav
      const aName = portalDisplayLabel(a).toLowerCase()
      const bName = portalDisplayLabel(b).toLowerCase()
      return aName.localeCompare(bName)
    })
    return list
  }, [draft.portals, favorites])

  const filteredPortals = useMemo(() => {
    const q = portalQuery.trim().toLowerCase()
    if (!q) return sortedPortals
    return sortedPortals.filter((portal) => {
      const hay = [
        portal.label,
        portal.name,
        portal.url,
        portal.username,
        portal.source,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase()
      return hay.includes(q)
    })
  }, [sortedPortals, portalQuery])

  const filteredM3u = useMemo(() => {
    const list = draft.m3uPlaylists ?? []
    const q = m3uQuery.trim().toLowerCase()
    if (!q) return list
    return list.filter((playlist) =>
      [playlist.name, playlist.sourceUrl]
        .filter(Boolean)
        .join(' ')
        .toLowerCase()
        .includes(q),
    )
  }, [draft.m3uPlaylists, m3uQuery])

  const portalPager = useMemo(
    () => pageSlice(filteredPortals, portalPage),
    [filteredPortals, portalPage],
  )
  const m3uPager = useMemo(
    () => pageSlice(filteredM3u, m3uPage),
    [filteredM3u, m3uPage],
  )

  const toggleFavorite = (row: IptvPortalRow) => {
    const key = portalKey(row)
    const next = new Set(favorites)
    if (next.has(key)) next.delete(key)
    else next.add(key)
    setDraft((prev) => ({ ...prev, favoriteKeys: [...next] }))
  }

  const upsertPortal = (row: IptvPortalRow, replaceKey?: string | null) => {
    const key = portalKey(row)
    setDraft((prev) => {
      const without = prev.portals.filter((p) => {
        const pk = portalKey(p)
        if (replaceKey && pk === replaceKey) return false
        return pk !== key
      })
      const favoriteKeys = (prev.favoriteKeys ?? [])
        .map((fav) => (replaceKey && fav === replaceKey ? key : fav))
        .filter((fav, index, arr) => arr.indexOf(fav) === index)
      return {
        ...prev,
        portals: [...without, row],
        favoriteKeys,
      }
    })
  }

  const addPortalManual = () => {
    const url = portalForm.url.trim()
    const username = portalForm.username.trim()
    const password = portalForm.password
    if (!url || !username || !password) return
    const existing = editingKey
      ? draft.portals.find((p) => portalKey(p) === editingKey)
      : undefined
    const row: IptvPortalRow = {
      url,
      username,
      password,
      label: portalForm.label.trim(),
      name: existing?.name ?? '',
      source: existing?.source || 'web',
      expiry: existing?.expiry ?? '',
      max: existing?.max ?? '1',
      active: existing?.active ?? '0',
    }
    upsertPortal(row, editingKey)
    setPortalForm({ url: '', username: '', password: '', label: '' })
    setEditingKey(null)
    setAddOpen(false)
    setAddMode('share')
  }

  const beginEdit = (portal: IptvPortalRow) => {
    setEditingKey(portalKey(portal))
    setPortalForm({
      url: portal.url,
      username: portal.username,
      password: portal.password,
      label: portal.label?.trim() || '',
    })
    setAddMode('manual')
    setAddOpen(true)
    setShareError(null)
  }

  const removePortal = (key: string) => {
    setDraft((prev) => ({
      ...prev,
      portals: prev.portals.filter((p) => portalKey(p) !== key),
      favoriteKeys: (prev.favoriteKeys ?? []).filter((k) => k !== key),
    }))
    if (editingKey === key) {
      setEditingKey(null)
      setPortalForm({ url: '', username: '', password: '', label: '' })
    }
  }

  const importShareCode = async (raw: string) => {
    const code = normalizeShareCode(raw)
    if (!isValidShareCode(code)) return
    setShareBusy(true)
    setShareError(null)
    try {
      const portal = await resolvePortalShare(code)
      if (!portal) {
        setShareError('Share code not found or expired')
        return
      }
      const key = portalKey(portal)
      if (draft.portals.some((p) => portalKey(p) === key)) {
        setShareError('Portal already in your list')
        return
      }
      upsertPortal(portal)
      setShareCode('')
      setAddOpen(false)
    } catch (error) {
      setShareError(
        error instanceof Error ? error.message : 'Could not import share code',
      )
    } finally {
      setShareBusy(false)
    }
  }

  const exportPortalsCsv = () => {
    if (sortedPortals.length === 0) return
    setCsvError(null)
    const csv = portalsToCsv(sortedPortals, favorites)
    downloadTextFile(iptvPortalsCsvFilename(), csv)
  }

  const importPortalsCsv = async (file: File | null) => {
    if (!file) return
    setCsvImportBusy(true)
    setCsvError(null)
    setCsvLog(null)
    setCsvLogSummary(null)
    try {
      const text = await file.text()
      const parsed = parsePortalsCsv(text)
      const merged = mergePortalsFromCsv(
        draft.portals,
        draft.favoriteKeys ?? [],
        parsed.portals,
      )
      setDraft((prev) => ({
        ...prev,
        portals: merged.portals,
        favoriteKeys: merged.favoriteKeys,
      }))
      const parts = [
        merged.added > 0 ? `${merged.added} added` : null,
        merged.skippedExisting > 0
          ? `${merged.skippedExisting} already present`
          : null,
        parsed.skipped > 0 ? `${parsed.skipped} invalid` : null,
      ].filter(Boolean)
      setCsvLog(merged.log)
      setCsvLogSummary(
        parts.length > 0
          ? `${parts.join(' · ')} — Save to sync.`
          : 'No changes — Save to sync.',
      )
    } catch (error) {
      setCsvError(
        error instanceof Error ? error.message : 'Could not import CSV',
      )
      setCsvLog(null)
      setCsvLogSummary(null)
    } finally {
      setCsvImportBusy(false)
      if (csvInputRef.current) csvInputRef.current.value = ''
    }
  }

  const copyShare = async (portal: IptvPortalRow) => {
    const key = portalKey(portal)
    setSharingKey(key)
    setShareError(null)
    try {
      const code = await createPortalShare(portal)
      const formatted = formatShareCode(code)
      try {
        await navigator.clipboard.writeText(code)
      } catch {
        // Still show the code if clipboard permission is denied.
      }
      setShareFlash((prev) => ({ ...prev, [key]: formatted }))
      window.setTimeout(() => {
        setShareFlash((prev) => {
          const next = { ...prev }
          delete next[key]
          return next
        })
      }, 8000)
    } catch (error) {
      setShareError(
        error instanceof Error ? error.message : 'Could not create share code',
      )
    } finally {
      setSharingKey(null)
    }
  }

  const addM3u = () => {
    const name = m3uForm.name.trim()
    const sourceUrl = m3uForm.sourceUrl.trim()
    if (!name || !sourceUrl) return
    const now = Date.now()
    const row: M3uPlaylistRow = {
      id: newM3uId(),
      name,
      sourceUrl,
      addedAt: now,
      updatedAt: now,
      channels: [],
    }
    setDraft((prev) => ({
      ...prev,
      m3uPlaylists: [...(prev.m3uPlaylists ?? []), row],
    }))
    setM3uForm({ name: '', sourceUrl: '' })
  }

  const removeM3u = (id: string) => {
    setDraft((prev) => ({
      ...prev,
      m3uPlaylists: (prev.m3uPlaylists ?? []).filter((p) => p.id !== id),
    }))
  }

  const handleSave = async () => {
    await save(draft)
    setSavedFlash(true)
    window.setTimeout(() => setSavedFlash(false), 2500)
  }

  return (
    <AccountSettingsShell
      title="IPTV portals"
      description="Manage many Xtream portals and M3U URLs. Share codes work like the app: peer transfer, not an account invite."
      footer={
        <div className="flex flex-wrap items-center gap-3">
          <Button onClick={() => void handleSave()} disabled={isLoading || isSaving}>
            {isSaving ? 'Saving…' : 'Save changes'}
          </Button>
          {savedFlash ? (
            <span className="text-sm text-forja-green">Saved - open Forja to sync.</span>
          ) : null}
          {saveError ? (
            <span className="text-sm text-red-300">
              {saveError instanceof Error ? saveError.message : 'Save failed'}
            </span>
          ) : null}
          {shareError && !addOpen ? (
            <span className="text-sm text-red-300">{shareError}</span>
          ) : null}
        </div>
      }
    >
      <SettingsSection
        label="Xtream portals"
        description="Favorites stay on top. Search filters name, URL, and username. Import / Export CSV includes passwords."
      >
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <div className="relative min-w-0 flex-1">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-forja-muted" />
            <Input
              aria-label="Search portals"
              placeholder="Search portals…"
              value={portalQuery}
              onChange={(event) => setPortalQuery(event.target.value)}
              className="pl-9"
            />
          </div>
          <input
            ref={csvInputRef}
            type="file"
            accept=".csv,text/csv"
            className="hidden"
            aria-hidden="true"
            tabIndex={-1}
            onChange={(event) => {
              const file = event.target.files?.[0] ?? null
              void importPortalsCsv(file)
            }}
          />
          <Button
            type="button"
            variant="secondary"
            disabled={csvImportBusy}
            onClick={() => csvInputRef.current?.click()}
            title="Import portals from a CSV file (adds only portals not already in your list)"
          >
            <Upload className="mr-2 size-4" />
            {csvImportBusy ? 'Importing…' : 'Import CSV'}
          </Button>
          <Button
            type="button"
            variant="secondary"
            disabled={sortedPortals.length === 0}
            onClick={exportPortalsCsv}
            title={
              sortedPortals.length === 0
                ? 'Add portals before exporting'
                : 'Download all portals as CSV (includes passwords)'
            }
          >
            <Download className="mr-2 size-4" />
            Export CSV
          </Button>
          <Button
            type="button"
            variant="secondary"
            onClick={() => {
              setAddOpen((open) => !open)
              setAddMode('share')
              setEditingKey(null)
              setShareError(null)
              setPortalForm({ url: '', username: '', password: '', label: '' })
            }}
          >
            {addOpen ? <X className="mr-2 size-4" /> : <Plus className="mr-2 size-4" />}
            {addOpen ? 'Close' : 'Add'}
          </Button>
        </div>

        {csvError ? (
          <div
            role="alert"
            className="mb-3 rounded-md border border-red-500/40 bg-red-500/10 px-3 py-2 text-sm text-red-300"
          >
            {csvError}
          </div>
        ) : null}

        {csvLog ? (
          <div
            role="status"
            aria-label="CSV import log"
            className="mb-3 rounded-md border border-forja-border bg-forja-elevated/60"
          >
            <div className="flex items-center justify-between gap-2 border-b border-forja-border px-3 py-2">
              <div className="min-w-0">
                <p className="text-xs font-medium uppercase tracking-wide text-forja-muted">
                  Import log
                </p>
                {csvLogSummary ? (
                  <p className="truncate text-sm text-forja-green">{csvLogSummary}</p>
                ) : null}
              </div>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 shrink-0 p-0"
                aria-label="Close import log"
                onClick={() => {
                  setCsvLog(null)
                  setCsvLogSummary(null)
                }}
              >
                <X className="size-4" />
              </Button>
            </div>
            <ul className="max-h-48 overflow-y-auto px-3 py-2 font-mono text-xs leading-relaxed">
              {csvLog.map((entry, index) => (
                <li
                  key={`${entry.status}-${entry.url}-${entry.username}-${index}`}
                  className={cn(
                    'flex flex-wrap items-baseline gap-x-2 gap-y-0.5 py-0.5',
                    entry.status === 'added'
                      ? 'text-forja-green'
                      : 'text-forja-muted',
                  )}
                >
                  <span className="shrink-0 tabular-nums text-white/30">
                    {String(index + 1).padStart(2, '0')}
                  </span>
                  <span className="shrink-0 uppercase tracking-wide">
                    {entry.status === 'added' ? 'added' : 'skip'}
                  </span>
                  <span className="min-w-0 truncate font-sans text-[13px] text-white/90">
                    {entry.label}
                  </span>
                  <span className="min-w-0 truncate text-white/35">
                    {entry.username}@{entry.url}
                  </span>
                  {entry.status === 'already_present' ? (
                    <span className="text-amber-400/90">already present</span>
                  ) : null}
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        <p className="mb-2 text-xs text-forja-muted">
          {filteredPortals.length}
          {portalQuery.trim() ? ` of ${draft.portals.length}` : ''} portals
          {portalPager.totalPages > 1
            ? ` · page ${portalPager.page} of ${portalPager.totalPages}`
            : ''}
        </p>

        {addOpen ? (
          <div className="mb-4 rounded-md border border-forja-border bg-forja-elevated/60 p-4">
            <Tabs
              value={addMode}
              onValueChange={(value) => setAddMode(value as AddMode)}
            >
              <TabsList aria-label="Add portal method">
                <TabsTrigger value="share">Share code</TabsTrigger>
                <TabsTrigger value="manual">Manual</TabsTrigger>
              </TabsList>

              <TabsContent value="share" className="space-y-3">
                <Label htmlFor="share-code">Paste an 8-character code</Label>
                <Input
                  id="share-code"
                  placeholder="XXXX-XXXX"
                  value={shareCode}
                  maxLength={9}
                  disabled={shareBusy}
                  onChange={(event) => {
                    const next = formatShareCode(event.target.value)
                    setShareCode(next)
                    setShareError(null)
                    if (isValidShareCode(next)) void importShareCode(next)
                  }}
                />
                <div className="flex gap-2">
                  <Button
                    type="button"
                    disabled={shareBusy || !isValidShareCode(shareCode)}
                    onClick={() => void importShareCode(shareCode)}
                  >
                    {shareBusy ? 'Importing…' : 'Import portal'}
                  </Button>
                </div>
                {shareError ? (
                  <p className="text-sm text-red-300">{shareError}</p>
                ) : (
                  <p className="text-xs text-forja-muted">
                    Same share codes as the Forja app. Credentials never go through
                    your account sync, only encrypted ciphertext.
                  </p>
                )}
              </TabsContent>

              <TabsContent value="manual">
                <div className="grid gap-3 sm:grid-cols-2">
                  <div className="space-y-2 sm:col-span-2">
                    <Label htmlFor="portal-url">Panel URL</Label>
                    <Input
                      id="portal-url"
                      placeholder="http://example.com:8080"
                      value={portalForm.url}
                      onChange={(e) =>
                        setPortalForm((f) => ({ ...f, url: e.target.value }))
                      }
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="portal-user">Username</Label>
                    <Input
                      id="portal-user"
                      value={portalForm.username}
                      onChange={(e) =>
                        setPortalForm((f) => ({
                          ...f,
                          username: e.target.value,
                        }))
                      }
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="portal-pass">Password</Label>
                    <Input
                      id="portal-pass"
                      type="password"
                      value={portalForm.password}
                      onChange={(e) =>
                        setPortalForm((f) => ({
                          ...f,
                          password: e.target.value,
                        }))
                      }
                    />
                  </div>
                  <div className="space-y-2 sm:col-span-2">
                    <Label htmlFor="portal-name">Portal name (optional)</Label>
                    <Input
                      id="portal-name"
                      value={portalForm.label}
                      placeholder="My provider"
                      onChange={(e) =>
                        setPortalForm((f) => ({ ...f, label: e.target.value }))
                      }
                    />
                  </div>
                  <div className="sm:col-span-2">
                    <Button
                      type="button"
                      variant="secondary"
                      onClick={addPortalManual}
                    >
                      {editingKey ? 'Save portal' : 'Add portal'}
                    </Button>
                  </div>
                </div>
              </TabsContent>
            </Tabs>
          </div>
        ) : null}

        {isLoading ? (
          <p className="text-sm text-forja-muted">Loading…</p>
        ) : filteredPortals.length === 0 ? (
          <p className="text-sm text-forja-muted">
            {draft.portals.length === 0
              ? 'No portals yet. Add a share code or enter credentials.'
              : 'No portals match your search.'}
          </p>
        ) : (
          <>
            <ul className="divide-y divide-forja-border">
              {portalPager.items.map((portal) => {
                const key = portalKey(portal)
                const starred = favorites.has(key)
                const shownCode = shareFlash[key]
                const title = portalDisplayLabel(portal)
                const expiry = portalExpiryTone(portal.expiry)
                const seats = seatsTone(portal.active, portal.max)

                return (
                  <li
                    key={key}
                    className="flex min-h-22 items-center gap-2 px-0.5 py-2.5"
                  >
                    {shownCode || sharingKey === key ? (
                      <div className="min-w-0 flex-1">
                        {sharingKey === key && !shownCode ? (
                          <p className="text-sm text-forja-muted">
                            Creating share code…
                          </p>
                        ) : (
                          <>
                            <p className="text-[10px] font-semibold tracking-wider text-forja-muted">
                              SHARE CODE
                            </p>
                            <p className="mt-1 font-mono text-lg font-bold tracking-[0.18em] text-forja-green">
                              {shownCode}
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
                        <p
                          className={cn(
                            'truncate text-[13px] font-semibold',
                            starred ? 'text-amber-300' : 'text-forja-text',
                          )}
                        >
                          {title}
                        </p>
                        <p className="truncate text-[11px] text-white/40">
                          {portal.url}
                        </p>
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

                    <button
                      type="button"
                      className={cn(
                        'shrink-0 self-center p-1 text-white/30 hover:text-forja-green',
                        starred && 'text-amber-300 hover:text-amber-200',
                      )}
                      onClick={() => toggleFavorite(portal)}
                      aria-label={starred ? 'Remove favorite' : 'Mark favorite'}
                    >
                      <Star
                        className="size-4"
                        fill={starred ? 'currentColor' : 'none'}
                      />
                    </button>

                    <div className="flex shrink-0 items-center self-center">
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="h-8 w-8 p-0"
                        disabled={sharingKey === key}
                        aria-label="Copy share code"
                        title="Copy share code"
                        onClick={() => void copyShare(portal)}
                      >
                        {sharingKey === key ? (
                          <Share2 className="size-4 animate-pulse" />
                        ) : shownCode ? (
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
                        onClick={() => beginEdit(portal)}
                      >
                        <Pencil className="size-4" />
                      </Button>
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="h-8 w-8 p-0 text-red-400 hover:text-red-300"
                        aria-label="Delete portal"
                        onClick={() => removePortal(key)}
                      >
                        <Trash2 className="size-4" />
                      </Button>
                    </div>
                  </li>
                )
              })}
            </ul>
            <ListPager
              page={portalPager.page}
              totalPages={portalPager.totalPages}
              start={portalPager.start}
              end={portalPager.end}
              total={filteredPortals.length}
              label="portals"
              onPageChange={setPortalPage}
            />
          </>
        )}
      </SettingsSection>

      <SettingsSection
        label="M3U playlists"
        description="Remote playlist URLs refresh in the app. File uploads stay device-local."
      >
        {(draft.m3uPlaylists ?? []).length > 4 ? (
          <div className="relative mb-3">
            <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-forja-muted" />
            <Input
              aria-label="Search M3U playlists"
              placeholder="Search playlists…"
              value={m3uQuery}
              onChange={(event) => setM3uQuery(event.target.value)}
              className="pl-9"
            />
          </div>
        ) : null}

        {filteredM3u.length === 0 ? (
          <p className="text-sm text-forja-muted">
            {(draft.m3uPlaylists ?? []).length === 0
              ? 'No M3U URLs yet.'
              : 'No playlists match your search.'}
          </p>
        ) : (
          <>
            <ul className="divide-y divide-forja-border">
              {m3uPager.items.map((playlist) => (
                <li
                  key={playlist.id}
                  className="flex items-center justify-between gap-3 px-0.5 py-2.5"
                >
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">
                      {playlist.name}
                    </p>
                    {playlist.sourceUrl ? (
                      <p className="mt-0.5 truncate text-[11px] text-white/40">
                        {playlist.sourceUrl}
                      </p>
                    ) : null}
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="h-8 w-8 shrink-0 p-0 text-red-400 hover:text-red-300"
                    onClick={() => removeM3u(playlist.id)}
                  >
                    <Trash2 className="size-4" />
                  </Button>
                </li>
              ))}
            </ul>
            <ListPager
              page={m3uPager.page}
              totalPages={m3uPager.totalPages}
              start={m3uPager.start}
              end={m3uPager.end}
              total={filteredM3u.length}
              label="playlists"
              onPageChange={setM3uPage}
            />
          </>
        )}

        <div className="grid gap-3 sm:grid-cols-2">
          <div className="space-y-2">
            <Label htmlFor="m3u-name">Name</Label>
            <Input
              id="m3u-name"
              value={m3uForm.name}
              onChange={(e) => setM3uForm((f) => ({ ...f, name: e.target.value }))}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="m3u-url">Playlist URL</Label>
            <Input
              id="m3u-url"
              placeholder="https://…/playlist.m3u"
              value={m3uForm.sourceUrl}
              onChange={(e) =>
                setM3uForm((f) => ({ ...f, sourceUrl: e.target.value }))
              }
            />
          </div>
        </div>
        <Button type="button" variant="secondary" className="mt-3" onClick={addM3u}>
          <Plus className="mr-2 size-4" />
          Add M3U URL
        </Button>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
