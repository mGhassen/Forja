import { useEffect, useState } from 'react'
import { Star, Trash2 } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { SettingsSection } from '@/components/settings-section'
import { useUserSetting } from '@/hooks/use-user-setting'
import {
  emptyIptvPayload,
  portalKey,
  SYNC_DOMAINS,
  type IptvPayload,
  type IptvPortalRow,
  type M3uPlaylistRow,
} from '@/lib/sync-domains'

function newM3uId() {
  return `${Date.now().toString(16)}_${Math.random().toString(16).slice(2, 10)}`
}

export function AccountSettingsIptvPage() {
  const { data, profileId, isLoading, save, isSaving, saveError } =
    useUserSetting<IptvPayload>(SYNC_DOMAINS.iptv)
  const [draft, setDraft] = useState<IptvPayload>(emptyIptvPayload())
  const [portalForm, setPortalForm] = useState({
    url: '',
    username: '',
    password: '',
    name: '',
  })
  const [m3uForm, setM3uForm] = useState({ name: '', sourceUrl: '' })
  const [savedFlash, setSavedFlash] = useState(false)

  useEffect(() => {
    setDraft(emptyIptvPayload())
  }, [profileId])

  useEffect(() => {
    if (!data) return
    setDraft({
      portals: data.payload.portals ?? [],
      favoriteKeys: data.payload.favoriteKeys ?? [],
      m3uPlaylists: data.payload.m3uPlaylists ?? [],
    })
  }, [data])

  const favorites = new Set(draft.favoriteKeys ?? [])

  const toggleFavorite = (row: IptvPortalRow) => {
    const key = portalKey(row)
    const next = new Set(favorites)
    if (next.has(key)) next.delete(key)
    else next.add(key)
    setDraft((prev) => ({ ...prev, favoriteKeys: [...next] }))
  }

  const addPortal = () => {
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
    const key = portalKey(row)
    if (draft.portals.some((p) => portalKey(p) === key)) return
    setDraft((prev) => ({ ...prev, portals: [...prev.portals, row] }))
    setPortalForm({ url: '', username: '', password: '', name: '' })
  }

  const removePortal = (key: string) => {
    setDraft((prev) => ({
      ...prev,
      portals: prev.portals.filter((p) => portalKey(p) !== key),
      favoriteKeys: (prev.favoriteKeys ?? []).filter((k) => k !== key),
    }))
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
      description="Xtream-Codes portals and M3U playlist URLs. The app pulls these on sign-in - credentials are stored in your account (HTTPS + row-level access only)."
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
        </div>
      }
    >
      <SettingsSection
        label="Xtream portals"
        description="Panel URL plus username and password - same fields as in the IPTV tab."
      >
          {isLoading ? (
            <p className="text-sm text-forja-muted">Loading…</p>
          ) : draft.portals.length === 0 ? (
            <p className="text-sm text-forja-muted">No portals yet.</p>
          ) : (
            <ul className="divide-y divide-forja-border">
              {draft.portals.map((portal) => {
                const key = portalKey(portal)
                const starred = favorites.has(key)
                return (
                  <li key={key} className="flex min-h-[64px] items-center gap-3 px-0.5 py-3">
                    <button
                      type="button"
                      className="mt-0.5 text-forja-muted hover:text-forja-green"
                      onClick={() => toggleFavorite(portal)}
                      aria-label={starred ? 'Remove favorite' : 'Mark favorite'}
                    >
                      <Star
                        className="size-4"
                        fill={starred ? 'currentColor' : 'none'}
                      />
                    </button>
                    <div className="min-w-0 flex-1">
                      <p className="font-medium">{portal.name || portal.url}</p>
                      <p className="truncate text-sm text-forja-muted">{portal.url}</p>
                      <p className="text-xs text-forja-muted">
                        {portal.username}
                        {portal.expiry ? ` · expires ${portal.expiry}` : ''}
                      </p>
                    </div>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="text-red-300 hover:text-red-200"
                      onClick={() => removePortal(key)}
                    >
                      <Trash2 className="size-4" />
                    </Button>
                  </li>
                )
              })}
            </ul>
          )}

          <div className="mt-5 grid gap-3 border-t border-forja-border pt-5 sm:grid-cols-2">
            <div className="space-y-2 sm:col-span-2">
              <Label htmlFor="portal-url">Panel URL</Label>
              <Input
                id="portal-url"
                placeholder="http://example.com:8080"
                value={portalForm.url}
                onChange={(e) => setPortalForm((f) => ({ ...f, url: e.target.value }))}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="portal-user">Username</Label>
              <Input
                id="portal-user"
                value={portalForm.username}
                onChange={(e) => setPortalForm((f) => ({ ...f, username: e.target.value }))}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="portal-pass">Password</Label>
              <Input
                id="portal-pass"
                type="password"
                value={portalForm.password}
                onChange={(e) => setPortalForm((f) => ({ ...f, password: e.target.value }))}
              />
            </div>
            <div className="space-y-2 sm:col-span-2">
              <Label htmlFor="portal-name">Display name (optional)</Label>
              <Input
                id="portal-name"
                value={portalForm.name}
                onChange={(e) => setPortalForm((f) => ({ ...f, name: e.target.value }))}
              />
            </div>
          </div>
          <Button type="button" variant="secondary" onClick={addPortal}>
            Add portal
          </Button>
      </SettingsSection>

      <SettingsSection
        label="M3U playlists"
        description="Remote playlist URLs refresh in the app. File uploads stay device-local."
      >
          {(draft.m3uPlaylists ?? []).length === 0 ? (
            <p className="text-sm text-forja-muted">No M3U URLs yet.</p>
          ) : (
            <ul className="divide-y divide-forja-border">
              {(draft.m3uPlaylists ?? []).map((playlist) => (
                <li
                  key={playlist.id}
                  className="flex min-h-[64px] items-center justify-between gap-3 px-0.5 py-3"
                >
                  <div className="min-w-0">
                    <p className="font-medium">{playlist.name}</p>
                    <p className="truncate text-sm text-forja-muted">
                      {playlist.sourceUrl}
                    </p>
                    {playlist.channels.length > 0 ? (
                      <p className="text-xs text-forja-muted">
                        {playlist.channels.length} cached channels
                      </p>
                    ) : null}
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="text-red-300 hover:text-red-200"
                    onClick={() => removeM3u(playlist.id)}
                  >
                    <Trash2 className="size-4" />
                  </Button>
                </li>
              ))}
            </ul>
          )}

          <div className="mt-5 grid gap-3 border-t border-forja-border pt-5 sm:grid-cols-2">
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
                onChange={(e) => setM3uForm((f) => ({ ...f, sourceUrl: e.target.value }))}
              />
            </div>
          </div>
          <Button type="button" variant="secondary" onClick={addM3u}>
            Add M3U URL
          </Button>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
