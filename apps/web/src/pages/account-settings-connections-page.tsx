import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { ChevronLeft, ChevronRight, MonitorSmartphone, RefreshCw } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsSection } from '@/components/settings-section'
import { Button } from '@/components/ui/button'
import { useAuth } from '@/hooks/use-auth'
import {
  countryCodeToFlagEmoji,
  currentSessionIdFromAccessToken,
  describeSessionPlace,
  formatSessionIp,
  formatSessionWhen,
  listMyAuthSessions,
  lookupSessionGeo,
  revokeMyAuthSession,
  type AuthSessionRow,
  type SessionGeo,
} from '@/lib/auth-sessions'

const PAGE_SIZE = 10

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

function SessionMetaRow({
  label,
  children,
}: {
  label: string
  children: ReactNode
}) {
  return (
    <div className="flex gap-3 text-sm">
      <dt className="w-24 shrink-0 font-mono-ui text-[10px] uppercase tracking-[0.14em] text-forja-muted">
        {label}
      </dt>
      <dd className="min-w-0 text-forja-text">{children}</dd>
    </div>
  )
}

function ConnectionCard({
  row,
  isCurrent,
  revoking,
  onRevoke,
}: {
  row: AuthSessionRow
  isCurrent: boolean
  revoking: boolean
  onRevoke: () => void
}) {
  const place = describeSessionPlace(row.user_agent)
  const ip = formatSessionIp(row.ip)
  const since = formatSessionWhen(row.created_at)
  const lastActive = formatSessionWhen(
    row.refreshed_at ?? row.updated_at ?? row.created_at,
  )
  const [geo, setGeo] = useState<SessionGeo | null>(null)
  const [geoReady, setGeoReady] = useState(!formatSessionIp(row.ip))

  useEffect(() => {
    let cancelled = false
    const hasIp = !!formatSessionIp(row.ip)
    setGeo(null)
    setGeoReady(!hasIp)
    if (!hasIp) return
    void lookupSessionGeo(row.ip).then((result) => {
      if (cancelled) return
      setGeo(result)
      setGeoReady(true)
    })
    return () => {
      cancelled = true
    }
  }, [row.ip])

  const flag = countryCodeToFlagEmoji(geo?.countryCode)
  const placeLine = geo
    ? [geo.city, geo.country].filter(Boolean).join(', ')
    : null

  return (
    <li className="rounded-xl border border-forja-border bg-forja-bg/40 p-4 sm:p-5">
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-start gap-3">
          <div
            className="flex size-10 shrink-0 items-center justify-center rounded-lg border border-forja-border bg-forja-green/10"
            aria-hidden
          >
            <MonitorSmartphone className="size-5 text-forja-green" />
          </div>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
              <p className="text-base font-semibold text-forja-text">
                {place.label}
              </p>
              {isCurrent ? (
                <span className="rounded-full border border-forja-green/35 bg-forja-green/10 px-2 py-0.5 font-mono-ui text-[10px] uppercase tracking-[0.14em] text-forja-green">
                  This browser
                </span>
              ) : null}
            </div>
            {place.detail ? (
              <p className="mt-1 text-sm text-forja-muted">{place.detail}</p>
            ) : null}
          </div>
        </div>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="shrink-0 text-red-300 hover:text-red-200"
          disabled={revoking}
          onClick={onRevoke}
        >
          {revoking ? 'Revoking…' : isCurrent ? 'Sign out' : 'Revoke'}
        </Button>
      </div>

      <dl className="mt-4 space-y-2.5 border-t border-forja-border pt-4">
        <SessionMetaRow label="Location">
          {placeLine ? (
            <span className="inline-flex items-center gap-2">
              {flag ? (
                <span className="text-lg leading-none" aria-hidden>
                  {flag}
                </span>
              ) : null}
              <span>{placeLine}</span>
            </span>
          ) : !geoReady ? (
            <span className="text-forja-muted">Looking up…</span>
          ) : (
            <span className="text-forja-muted">Unknown</span>
          )}
        </SessionMetaRow>
        <SessionMetaRow label="IP">
          {ip ? (
            <span className="font-mono-ui text-[13px] tracking-wide">{ip}</span>
          ) : (
            <span className="text-forja-muted">—</span>
          )}
        </SessionMetaRow>
        <SessionMetaRow label="Signed in">{since}</SessionMetaRow>
        <SessionMetaRow label="Last active">{lastActive}</SessionMetaRow>
      </dl>
    </li>
  )
}

export function AccountSettingsConnectionsPage() {
  const navigate = useNavigate()
  const { session, signOut } = useAuth()
  const [rows, setRows] = useState<AuthSessionRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [revokingId, setRevokingId] = useState<string | null>(null)
  const [signingOutAll, setSigningOutAll] = useState(false)
  const [page, setPage] = useState(1)

  const currentId = currentSessionIdFromAccessToken(session?.access_token)
  const slice = useMemo(() => pageSlice(rows, page), [rows, page])

  useEffect(() => {
    if (page !== slice.page) setPage(slice.page)
  }, [page, slice.page])

  const refresh = useCallback(async () => {
    setLoading(true)
    setError(null)
    const { sessions, error: listError } = await listMyAuthSessions()
    setLoading(false)
    if (listError) {
      setError(listError)
      setRows([])
      setPage(1)
      return
    }
    setRows(sessions)
    setPage(1)
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh])

  async function onRevoke(sessionId: string) {
    setRevokingId(sessionId)
    setError(null)
    const { ok, error: revokeError } = await revokeMyAuthSession(sessionId)
    setRevokingId(null)
    if (revokeError || !ok) {
      setError(revokeError ?? 'Could not revoke that session.')
      return
    }
    if (sessionId === currentId) {
      await signOut({ scope: 'local' })
      void navigate({ to: '/' })
      return
    }
    await refresh()
  }

  async function onSignOutEverywhere() {
    setSigningOutAll(true)
    await signOut({ scope: 'global' })
    setSigningOutAll(false)
    void navigate({ to: '/' })
  }

  return (
    <AccountSettingsShell
      section="account"
      title="Connections"
      description="Active sign-ins for this account — browsers, desktop Web login, and Android TV device link. Revoke anything you do not recognize."
    >
      <SettingsSection
        label="Active sessions"
        description="Device, location, IP, and activity for each sign-in."
      >
        <div className="space-y-4">
          <div className="flex flex-wrap gap-2">
            <Button
              type="button"
              variant="outline"
              className="gap-2"
              disabled={loading}
              onClick={() => void refresh()}
            >
              <RefreshCw className={`size-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </Button>
            <Button
              type="button"
              variant="outline"
              disabled={signingOutAll}
              onClick={() => void onSignOutEverywhere()}
            >
              {signingOutAll ? 'Signing out…' : 'Sign out all devices'}
            </Button>
          </div>

          {loading ? (
            <p className="text-sm text-forja-muted">Loading connections…</p>
          ) : rows.length === 0 ? (
            <p className="text-sm text-forja-muted">No active sessions found.</p>
          ) : (
            <>
              <ul className="space-y-3">
                {slice.items.map((row) => (
                  <ConnectionCard
                    key={row.id}
                    row={row}
                    isCurrent={row.id === currentId}
                    revoking={revokingId === row.id}
                    onRevoke={() => void onRevoke(row.id)}
                  />
                ))}
              </ul>
              {rows.length > PAGE_SIZE ? (
                <div className="flex items-center justify-between gap-3 text-xs text-forja-muted">
                  <span>
                    {slice.start}–{slice.end} of {rows.length} sessions
                  </span>
                  <div className="flex items-center gap-1">
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="h-7 w-7 p-0"
                      disabled={slice.page <= 1}
                      aria-label="Previous page"
                      onClick={() => setPage(slice.page - 1)}
                    >
                      <ChevronLeft className="size-4" />
                    </Button>
                    <span className="min-w-12 text-center">
                      {slice.page}/{slice.totalPages}
                    </span>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="h-7 w-7 p-0"
                      disabled={slice.page >= slice.totalPages}
                      aria-label="Next page"
                      onClick={() => setPage(slice.page + 1)}
                    >
                      <ChevronRight className="size-4" />
                    </Button>
                  </div>
                </div>
              ) : null}
            </>
          )}

          {error ? (
            <p role="alert" className="text-sm text-red-300">
              {error}
            </p>
          ) : null}
        </div>
      </SettingsSection>
    </AccountSettingsShell>
  )
}
