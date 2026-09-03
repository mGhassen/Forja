import { useEffect, useMemo, useState } from 'react'
import {
  CalendarDays,
  Check,
  ChevronLeft,
  ChevronRight,
  Copy,
  Download,
  Minus,
  Pencil,
  Plus,
  Search,
  Share2,
  Sparkles,
  Star,
  Trash2,
  Users,
  X,
} from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsAutosaveFooter } from '@/components/settings-autosave-footer'
import { SettingsSection } from '@/components/settings-section'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { PasswordInput } from '@/components/ui/password-input'
import { useAccountFeatures, canAddIptvPortal } from '@/hooks/use-account-features'
import { useUserIptvPortals } from '@/hooks/use-user-iptv-portals'
import {
  downloadTextFile,
  iptvPortalsCsvFilename,
  portalsToCsv,
} from '@/lib/iptv-portal-csv'
import {
  createPortalShare,
  formatShareCode,
} from '@/lib/iptv-portal-share'
import {
  portalDisplayLabel,
  portalKey,
  type IptvPortalRow,
} from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

const PAGE_SIZE = 10


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

function seatsTone(max?: string) {
  const cap = (max ?? '').trim() || '?'
  return {
    label: `Max ${cap}`,
    className: 'text-sky-400',
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

function rowIdentity(row: IptvPortalRow): string {
  return row.portalId || portalKey(row)
}

function ThemeCheckbox({
  checked,
  indeterminate = false,
  label,
  onChange,
}: {
  checked: boolean
  indeterminate?: boolean
  label: string
  onChange: () => void
}) {
  const on = checked || indeterminate
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={indeterminate ? 'mixed' : checked}
      aria-label={label}
      onClick={onChange}
      className={cn(
        'flex size-5 shrink-0 items-center justify-center rounded border transition-colors',
        on
          ? 'border-forja-green bg-forja-green text-[#0B0A0A]'
          : 'border-white/25 bg-transparent hover:border-forja-green/60',
      )}
    >
      {indeterminate ? (
        <Minus className="size-3 stroke-3" />
      ) : checked ? (
        <Check className="size-3 stroke-3" />
      ) : null}
    </button>
  )
}

type DraftState = {
  portals: IptvPortalRow[]
}

export function AccountSettingsIptvPage() {
  const portalsHook = useUserIptvPortals()
  const { data: accountFeatures } = useAccountFeatures()
  const iptvScrapeActive = accountFeatures?.iptvScrape === true
  const dealPortalActive = accountFeatures?.dealPortal === true
  const iptvCredits = accountFeatures?.iptvCredits ?? 0
  const maxIptvPortals = accountFeatures?.maxIptvPortals ?? 5
  const profileId = portalsHook.profileId
  const isLoading = portalsHook.isLoading
  const isSaving = portalsHook.isSaving
  const saveError = portalsHook.saveError
  const [draft, setDraft] = useState<DraftState>({
    portals: [],
  })
  const [portalQuery, setPortalQuery] = useState('')
  const [addOpen, setAddOpen] = useState(false)
  const [shareError, setShareError] = useState<string | null>(null)
  const [portalForm, setPortalForm] = useState({
    url: '',
    username: '',
    password: '',
    portalName: '',
  })
  const [editingKey, setEditingKey] = useState<string | null>(null)
  const [shareFlash, setShareFlash] = useState<Record<string, string>>({})
  const [sharingKey, setSharingKey] = useState<string | null>(null)
  const [savedFlash, setSavedFlash] = useState(false)
  const [portalPage, setPortalPage] = useState(1)
  const [hydrateError, setHydrateError] = useState<string | null>(null)
  const [selectedKeys, setSelectedKeys] = useState<Set<string>>(() => new Set())
  const [confirmBulkDelete, setConfirmBulkDelete] = useState(false)
  const atPortalLimit =
    !editingKey && !canAddIptvPortal(accountFeatures, draft.portals.length)

  useEffect(() => {
    setDraft({ portals: [] })
    setPortalQuery('')
    setAddOpen(false)
    setEditingKey(null)
    setPortalPage(1)
    setHydrateError(null)
    setSelectedKeys(new Set())
    setConfirmBulkDelete(false)
  }, [profileId])

  useEffect(() => {
    setPortalPage(1)
  }, [portalQuery])

  useEffect(() => {
    if (portalsHook.isError) {
      setHydrateError(
        portalsHook.error instanceof Error
          ? portalsHook.error.message
          : 'Failed to load portals',
      )
    } else {
      setHydrateError(null)
    }

    if (!profileId || isLoading || portalsHook.data === undefined) {
      setDraft({ portals: [] })
      return
    }

    const portals: IptvPortalRow[] = portalsHook.data.map((a) => ({
      portalId: a.portal_id,
      url: a.portal.url,
      username: a.portal.username,
      password: a.portal.password,
      source: a.portal.source ?? undefined,
      platform:
        a.portal.platform === 'm3u' || a.portal.platform === 'stalker'
          ? a.portal.platform
          : 'xtream',
      portalName: a.portal_name,
      expiry: a.portal.expiry ?? undefined,
      max: a.portal.max_connections ?? undefined,
      favorite: a.favorite,
    }))

    setDraft({ portals })
  }, [
    profileId,
    isLoading,
    portalsHook.data,
    portalsHook.isError,
    portalsHook.error,
  ])

  const sortedPortals = useMemo(() => {
    const list = [...draft.portals]
    list.sort((a, b) => {
      const aFav = a.favorite ? 0 : 1
      const bFav = b.favorite ? 0 : 1
      if (aFav !== bFav) return aFav - bFav
      return portalDisplayLabel(a)
        .toLowerCase()
        .localeCompare(portalDisplayLabel(b).toLowerCase())
    })
    return list
  }, [draft.portals])

  const filteredPortals = useMemo(() => {
    const q = portalQuery.trim().toLowerCase()
    if (!q) return sortedPortals
    return sortedPortals.filter((portal) => {
      const hay = [
        portal.portalName,
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

  const portalPager = useMemo(
    () => pageSlice(filteredPortals, portalPage),
    [filteredPortals, portalPage],
  )

  const filteredKeys = useMemo(
    () => filteredPortals.map(rowIdentity),
    [filteredPortals],
  )

  const selectedCount = selectedKeys.size
  const allFilteredSelected =
    filteredKeys.length > 0 && filteredKeys.every((k) => selectedKeys.has(k))
  const someFilteredSelected =
    !allFilteredSelected && filteredKeys.some((k) => selectedKeys.has(k))

  useEffect(() => {
    const alive = new Set(draft.portals.map(rowIdentity))
    setSelectedKeys((prev) => {
      let changed = false
      const next = new Set<string>()
      for (const key of prev) {
        if (alive.has(key)) next.add(key)
        else changed = true
      }
      return changed ? next : prev
    })
  }, [draft.portals])

  useEffect(() => {
    if (selectedCount === 0) setConfirmBulkDelete(false)
  }, [selectedCount])

  const persistPortals = async (portals: IptvPortalRow[]) => {
    setDraft({ portals })
    setHydrateError(null)
    try {
      await portalsHook.replaceAll(
        portals.map((portal) => ({
          url: portal.url,
          username: portal.username,
          password: portal.password,
          source: portal.source,
          expiry: portal.expiry,
          maxConnections: portal.max,
          platform: portal.platform ?? 'xtream',
          portalName: portal.portalName?.trim() || portal.username,
          favorite: portal.favorite === true,
        })),
      )
      setSavedFlash(true)
      window.setTimeout(() => setSavedFlash(false), 2000)
    } catch {
      // portalsHook.saveError surfaces in footer
    }
  }

  const toggleFavorite = (row: IptvPortalRow) => {
    const id = rowIdentity(row)
    const next = draft.portals.map((p) =>
      rowIdentity(p) === id ? { ...p, favorite: !p.favorite } : p,
    )
    void persistPortals(next)
  }

  const upsertPortal = (row: IptvPortalRow, replaceKey?: string | null) => {
    const key = rowIdentity(row)
    const without = draft.portals.filter((p) => {
      const pk = rowIdentity(p)
      if (replaceKey && pk === replaceKey) return false
      return pk !== key
    })
    void persistPortals([...without, row])
  }

  const addPortalManual = () => {
    const url = portalForm.url.trim()
    const username = portalForm.username.trim()
    const password = portalForm.password
    if (!url || !username || !password) return
    if (
      !editingKey &&
      !canAddIptvPortal(accountFeatures, draft.portals.length)
    ) {
      setShareError(
        `Maximum of ${maxIptvPortals} IPTV portals per profile`,
      )
      return
    }
    const existing = editingKey
      ? draft.portals.find((p) => rowIdentity(p) === editingKey)
      : undefined
    const row: IptvPortalRow = {
      portalId: existing?.portalId,
      url,
      username,
      password,
      portalName: portalForm.portalName.trim() || username,
      source: existing?.source || 'web',
      expiry: existing?.expiry ?? '',
      max: existing?.max ?? '1',
      favorite: existing?.favorite ?? false,
    }
    upsertPortal(row, editingKey)
    setPortalForm({ url: '', username: '', password: '', portalName: '' })
    setEditingKey(null)
    setAddOpen(false)
    setShareError(null)
  }

  const beginEdit = (portal: IptvPortalRow) => {
    setEditingKey(rowIdentity(portal))
    setPortalForm({
      url: portal.url,
      username: portal.username,
      password: portal.password,
      portalName: portal.portalName?.trim() || '',
    })
    setAddOpen(true)
    setShareError(null)
  }

  const removePortal = (key: string) => {
    const next = draft.portals.filter((p) => rowIdentity(p) !== key)
    void persistPortals(next)
    setSelectedKeys((prev) => {
      if (!prev.has(key)) return prev
      const nextKeys = new Set(prev)
      nextKeys.delete(key)
      return nextKeys
    })
    if (editingKey === key) {
      setEditingKey(null)
      setPortalForm({ url: '', username: '', password: '', portalName: '' })
    }
  }

  const toggleSelect = (key: string) => {
    setSelectedKeys((prev) => {
      const next = new Set(prev)
      if (next.has(key)) next.delete(key)
      else next.add(key)
      return next
    })
  }

  const toggleSelectAllFiltered = () => {
    setSelectedKeys((prev) => {
      if (allFilteredSelected) {
        const next = new Set(prev)
        for (const key of filteredKeys) next.delete(key)
        return next
      }
      const next = new Set(prev)
      for (const key of filteredKeys) next.add(key)
      return next
    })
  }

  const clearSelection = () => {
    setSelectedKeys(new Set())
    setConfirmBulkDelete(false)
  }

  const exportPortalsCsv = (portals: IptvPortalRow[]) => {
    if (portals.length === 0) return
    const favorites = new Set(
      portals.filter((p) => p.favorite).map((p) => portalKey(p)),
    )
    const csv = portalsToCsv(portals, favorites)
    downloadTextFile(iptvPortalsCsvFilename(), csv)
  }

  const exportSelectedOrAll = () => {
    if (selectedCount > 0) {
      const selected = draft.portals.filter((p) =>
        selectedKeys.has(rowIdentity(p)),
      )
      exportPortalsCsv(selected)
      return
    }
    exportPortalsCsv(sortedPortals)
  }

  const deleteSelected = () => {
    if (selectedCount === 0) return
    const next = draft.portals.filter(
      (p) => !selectedKeys.has(rowIdentity(p)),
    )
    if (editingKey && selectedKeys.has(editingKey)) {
      setEditingKey(null)
      setPortalForm({ url: '', username: '', password: '', portalName: '' })
      setAddOpen(false)
    }
    void persistPortals(next)
    clearSelection()
  }

  const copyShare = async (portal: IptvPortalRow) => {
    const key = rowIdentity(portal)
    setSharingKey(key)
    setShareError(null)
    try {
      const code = await createPortalShare(portal)
      const formatted = formatShareCode(code)
      try {
        await navigator.clipboard.writeText(formatted)
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

  return (
    <AccountSettingsShell
      footer={
        <SettingsAutosaveFooter
          isSaving={isSaving}
          savedFlash={savedFlash}
          error={
            saveError instanceof Error
              ? saveError
              : hydrateError
          }
          extra={
            shareError && !addOpen ? (
              <span className="text-red-300">{shareError}</span>
            ) : null
          }
        />
      }
    >
      <div className="mb-8 space-y-3">
        {dealPortalActive ? (
          <div
            className={cn(
              'overflow-hidden rounded-xl border border-white/10',
              'bg-linear-to-r from-white/8 via-white/3 to-transparent',
            )}
          >
            <div className="flex flex-wrap items-start justify-between gap-3 px-4 py-3.5 sm:px-5">
              <div className="min-w-0">
                <h3 className="text-sm font-semibold tracking-tight text-[#EDE6DA]">
                  Catalog credits
                </h3>
                <p className="mt-1 text-xs leading-5 text-forja-muted">
                  Spend credits in the Forja app (IPTV → Deal) to pull alive
                  portals from the shared pool. Granting is admin-only.
                </p>
              </div>
              <span
                className={cn(
                  'shrink-0 rounded-full border px-2.5 py-1 font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em]',
                  iptvCredits > 0
                    ? 'border-forja-green/40 bg-forja-green/10 text-forja-green'
                    : 'border-white/15 bg-white/5 text-forja-muted',
                )}
              >
                {iptvCredits} credit{iptvCredits === 1 ? '' : 's'}
              </span>
            </div>
          </div>
        ) : null}
        {iptvScrapeActive ? (
          <div
            className={cn(
              'overflow-hidden rounded-xl border border-forja-green/35',
              'bg-linear-to-r from-forja-green/15 via-forja-green/5 to-transparent',
            )}
          >
            <div className="flex flex-wrap items-start justify-between gap-3 px-4 py-3.5 sm:px-5">
              <div className="min-w-0 flex items-start gap-3">
                <span className="mt-0.5 flex size-9 shrink-0 items-center justify-center rounded-full border border-forja-green/40 bg-forja-green/15 text-forja-green">
                  <Sparkles className="size-4" aria-hidden />
                </span>
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="rounded-full border border-forja-green/50 bg-forja-green px-2 py-0.5 font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] text-[#0B0A0A]">
                      VIP
                    </span>
                    <h3 className="text-sm font-semibold tracking-tight text-[#EDE6DA]">
                      Find Portals
                    </h3>
                  </div>
                  <p className="mt-1 text-xs leading-5 text-forja-muted">
                    Portal scraping is unlocked in the Forja IPTV.
                  </p>
                </div>
              </div>
              <span className="shrink-0 rounded-full border border-forja-green/40 bg-forja-green/10 px-2.5 py-1 font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] text-forja-green">
                Activated
              </span>
            </div>
          </div>
        ) : null}
      </div>

      <SettingsSection
        label="Portals"
        description="Select portals for batch export or remove from this profile. Favorites stay on top. Search filters name, URL, and username."
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
          <Button
            type="button"
            variant="secondary"
            disabled={selectedCount === 0 && sortedPortals.length === 0}
            onClick={exportSelectedOrAll}
            title={
              selectedCount > 0
                ? `Export ${selectedCount} selected as CSV`
                : 'Export portals as CSV'
            }
          >
            <Download className="mr-2 size-4" />
            {selectedCount > 0 ? `Export (${selectedCount})` : 'Export'}
          </Button>
          <Button
            type="button"
            variant="secondary"
            disabled={atPortalLimit && !addOpen}
            title={
              atPortalLimit
                ? `Maximum of ${maxIptvPortals} portals per profile`
                : undefined
            }
            onClick={() => {
              setAddOpen((open) => !open)
              setEditingKey(null)
              setShareError(null)
              setPortalForm({
                url: '',
                username: '',
                password: '',
                portalName: '',
              })
            }}
          >
            {addOpen ? <X className="mr-2 size-4" /> : <Plus className="mr-2 size-4" />}
            {addOpen ? 'Close' : 'Add'}
          </Button>
        </div>

        <p className="mb-2 text-xs text-forja-muted">
          {filteredPortals.length}
          {portalQuery.trim() ? ` of ${draft.portals.length}` : ''} portals
          {accountFeatures?.isAdmin
            ? ' · unlimited'
            : ` · max ${maxIptvPortals}`}
          {portalPager.totalPages > 1
            ? ` · page ${portalPager.page} of ${portalPager.totalPages}`
            : ''}
          {selectedCount > 0 ? ` · ${selectedCount} selected` : ''}
        </p>

        {addOpen ? (
          <div className="mb-4 border border-forja-border bg-forja-elevated/40 p-4">
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
                <PasswordInput
                  id="portal-pass"
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
                  value={portalForm.portalName}
                  placeholder="Home XT"
                  onChange={(e) =>
                    setPortalForm((f) => ({
                      ...f,
                      portalName: e.target.value,
                    }))
                  }
                />
                <p className="text-xs text-forja-muted">
                  Your label for this profile — not the Xtream provider account
                  name.
                </p>
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
            <div className="overflow-hidden rounded-xl border border-forja-border">
              {selectedCount > 0 ? (
                <div className="flex flex-wrap items-center gap-2 border-b border-forja-border bg-forja-elevated/80 px-3 py-2">
                  <p className="mr-1 text-sm font-medium text-forja-text">
                    {selectedCount} selected
                  </p>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => {
                      const selected = draft.portals.filter((p) =>
                        selectedKeys.has(rowIdentity(p)),
                      )
                      exportPortalsCsv(selected)
                    }}
                  >
                    <Download className="size-4" />
                    Export
                  </Button>
                  {confirmBulkDelete ? (
                    <>
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="text-red-400 hover:text-red-300"
                        onClick={deleteSelected}
                      >
                        Confirm remove ({selectedCount})
                      </Button>
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        onClick={() => setConfirmBulkDelete(false)}
                      >
                        Cancel
                      </Button>
                    </>
                  ) : (
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="text-red-400 hover:text-red-300"
                      onClick={() => setConfirmBulkDelete(true)}
                      title="Remove from this profile (shared portal stays in the catalog)"
                    >
                      <Trash2 className="size-4" />
                      Remove
                    </Button>
                  )}
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="ml-auto"
                    onClick={clearSelection}
                  >
                    <X className="size-4" />
                    Clear
                  </Button>
                </div>
              ) : null}

              <div className="flex items-center gap-2 border-b border-forja-border bg-forja-elevated/40 px-3 py-2">
                <ThemeCheckbox
                  checked={allFilteredSelected}
                  indeterminate={someFilteredSelected}
                  label={
                    allFilteredSelected
                      ? 'Deselect all portals'
                      : 'Select all portals'
                  }
                  onChange={toggleSelectAllFiltered}
                />
                <button
                  type="button"
                  className="text-xs font-medium text-forja-muted hover:text-forja-text"
                  onClick={toggleSelectAllFiltered}
                >
                  {allFilteredSelected ? 'Deselect all' : 'Select all'}
                  {portalQuery.trim()
                    ? ` (${filteredPortals.length} matching)`
                    : ''}
                </button>
              </div>

              <ul className="divide-y divide-forja-border">
                {portalPager.items.map((portal) => {
                  const key = rowIdentity(portal)
                  const starred = portal.favorite ?? false
                  const shownCode = shareFlash[key]
                  const title = portalDisplayLabel(portal)
                  const expiry = portalExpiryTone(portal.expiry)
                  const seats = seatsTone(portal.max)
                  const isSelected = selectedKeys.has(key)

                  return (
                    <li
                      key={key}
                      className={cn(
                        'flex min-h-22 items-center gap-2 px-3 py-2.5',
                        isSelected &&
                          'bg-forja-green/8 ring-1 ring-inset ring-forja-green/35',
                      )}
                      aria-selected={isSelected}
                    >
                      <ThemeCheckbox
                        checked={isSelected}
                        label={`Select ${title}`}
                        onChange={() => toggleSelect(key)}
                      />

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
                          <p className="truncate text-sm text-white/55">
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
                          aria-label="Remove portal from profile"
                          title="Remove from this profile"
                          onClick={() => removePortal(key)}
                        >
                          <Trash2 className="size-4" />
                        </Button>
                      </div>
                    </li>
                  )
                })}
              </ul>
            </div>
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

    </AccountSettingsShell>
  )
}
