import { useEffect, useMemo, useState } from 'react'
import {
  Check,
  Copy,
  Pencil,
  Plus,
  Search,
  Share2,
  Star,
  Trash2,
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
  createPortalShare,
  formatShareCode,
  isValidShareCode,
  normalizeShareCode,
  resolvePortalShare,
} from '@/lib/iptv-portal-share'
import {
  emptyIptvPayload,
  portalKey,
  SYNC_DOMAINS,
  type IptvPayload,
  type IptvPortalRow,
  type M3uPlaylistRow,
} from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

function newM3uId() {
  return `${Date.now().toString(16)}_${Math.random().toString(16).slice(2, 10)}`
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
    name: '',
  })
  const [editingKey, setEditingKey] = useState<string | null>(null)
  const [shareFlash, setShareFlash] = useState<Record<string, string>>({})
  const [sharingKey, setSharingKey] = useState<string | null>(null)
  const [m3uForm, setM3uForm] = useState({ name: '', sourceUrl: '' })
  const [savedFlash, setSavedFlash] = useState(false)

  useEffect(() => {
    setDraft(emptyIptvPayload())
    setPortalQuery('')
    setM3uQuery('')
    setAddOpen(false)
    setEditingKey(null)
  }, [profileId])

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
      const aName = (a.name || a.url).toLowerCase()
      const bName = (b.name || b.url).toLowerCase()
      return aName.localeCompare(bName)
    })
    return list
  }, [draft.portals, favorites])

  const filteredPortals = useMemo(() => {
    const q = portalQuery.trim().toLowerCase()
    if (!q) return sortedPortals
    return sortedPortals.filter((portal) => {
      const hay = [portal.name, portal.url, portal.username, portal.source]
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
    const row: IptvPortalRow = {
      url,
      username,
      password,
      name: portalForm.name.trim() || url,
      source: 'web',
      expiry: '',
      max: '1',
      active: '0',
    }
    upsertPortal(row, editingKey)
    setPortalForm({ url: '', username: '', password: '', name: '' })
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
      name: portal.name ?? '',
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
      setPortalForm({ url: '', username: '', password: '', name: '' })
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
      description="Manage many Xtream portals and M3U URLs. Share codes work like the app — peer transfer, not account invite."
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
        description="Favorites stay on top. Search filters name, URL, and username."
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
            onClick={() => {
              setAddOpen((open) => !open)
              setAddMode('share')
              setEditingKey(null)
              setShareError(null)
              setPortalForm({ url: '', username: '', password: '', name: '' })
            }}
          >
            {addOpen ? <X className="mr-2 size-4" /> : <Plus className="mr-2 size-4" />}
            {addOpen ? 'Close' : 'Add'}
          </Button>
        </div>

        <p className="mb-2 text-xs text-forja-muted">
          {filteredPortals.length}
          {portalQuery.trim() ? ` of ${draft.portals.length}` : ''} portals
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
                    your account sync — only encrypted ciphertext.
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
                    <Label htmlFor="portal-name">Display name (optional)</Label>
                    <Input
                      id="portal-name"
                      value={portalForm.name}
                      onChange={(e) =>
                        setPortalForm((f) => ({ ...f, name: e.target.value }))
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
              ? 'No portals yet — add a share code or enter credentials.'
              : 'No portals match your search.'}
          </p>
        ) : (
          <ul className="max-h-[420px] divide-y divide-forja-border overflow-y-auto pr-1">
            {filteredPortals.map((portal) => {
              const key = portalKey(portal)
              const starred = favorites.has(key)
              const shownCode = shareFlash[key]
              return (
                <li
                  key={key}
                  className="flex min-h-14 items-center gap-2 px-0.5 py-2.5"
                >
                  <button
                    type="button"
                    className={cn(
                      'shrink-0 text-forja-muted hover:text-forja-green',
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

                  <div className="min-w-0 flex-1">
                    {shownCode ? (
                      <p className="font-mono text-base tracking-[0.18em] text-forja-green">
                        {shownCode}
                      </p>
                    ) : (
                      <>
                        <p className="truncate font-medium">
                          {portal.name || portal.username || portal.url}
                        </p>
                        <p className="truncate text-xs text-forja-muted">
                          {portal.url}
                          {portal.username ? ` · ${portal.username}` : ''}
                          {portal.expiry ? ` · expires ${portal.expiry}` : ''}
                          {portal.max
                            ? ` · ${portal.active || '0'}/${portal.max}`
                            : ''}
                        </p>
                      </>
                    )}
                  </div>

                  <div className="flex shrink-0 items-center gap-0.5">
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
                      className="h-8 w-8 p-0 text-red-300 hover:text-red-200"
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
          <ul className="mb-4 max-h-64 divide-y divide-forja-border overflow-y-auto">
            {filteredM3u.map((playlist) => (
              <li
                key={playlist.id}
                className="flex min-h-14 items-center justify-between gap-3 px-0.5 py-2.5"
              >
                <div className="min-w-0">
                  <p className="truncate font-medium">{playlist.name}</p>
                  <p className="truncate text-xs text-forja-muted">
                    {playlist.sourceUrl}
                  </p>
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="h-8 w-8 p-0 text-red-300 hover:text-red-200"
                  onClick={() => removeM3u(playlist.id)}
                >
                  <Trash2 className="size-4" />
                </Button>
              </li>
            ))}
          </ul>
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
