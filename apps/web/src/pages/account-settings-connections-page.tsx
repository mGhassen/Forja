import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { MonitorSmartphone, RefreshCw } from 'lucide-react'
import { AccountSettingsShell } from '@/components/account-settings-shell'
import { SettingsSection } from '@/components/settings-section'
import { Button } from '@/components/ui/button'
import { useAuth } from '@/hooks/use-auth'
import {
  currentSessionIdFromAccessToken,
  describeSessionPlace,
  formatSessionWhen,
  listMyAuthSessions,
  revokeMyAuthSession,
  type AuthSessionRow,
} from '@/lib/auth-sessions'

export function AccountSettingsConnectionsPage() {
  const navigate = useNavigate()
  const { session, signOut } = useAuth()
  const [rows, setRows] = useState<AuthSessionRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [revokingId, setRevokingId] = useState<string | null>(null)
  const [signingOutAll, setSigningOutAll] = useState(false)

  const currentId = currentSessionIdFromAccessToken(session?.access_token)

  const refresh = useCallback(async () => {
    setLoading(true)
    setError(null)
    const { sessions, error: listError } = await listMyAuthSessions()
    setLoading(false)
    if (listError) {
      setError(listError)
      setRows([])
      return
    }
    setRows(sessions)
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
      description="Every active sign-in for this account — browsers, desktop Web login, and the Forja app. Revoke anything you do not recognize."
    >
      <SettingsSection
        label="Active sessions"
        description="Where each session started, when it was created, and when it last refreshed."
      >
        <div className="space-y-4">
          <div className="flex flex-wrap gap-2">
            <Button
              type="button"
              variant="outline"
              className="gap-2 border-[rgba(237,230,218,0.22)]"
              disabled={loading}
              onClick={() => void refresh()}
            >
              <RefreshCw className={`size-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </Button>
            <Button
              type="button"
              variant="outline"
              className="border-[rgba(237,230,218,0.22)]"
              disabled={signingOutAll}
              onClick={() => void onSignOutEverywhere()}
            >
              {signingOutAll ? 'Signing out…' : 'Sign out all devices'}
            </Button>
          </div>

          {loading ? (
            <p className="text-sm text-[rgba(237,230,218,0.55)]">
              Loading connections…
            </p>
          ) : rows.length === 0 ? (
            <p className="text-sm text-[rgba(237,230,218,0.55)]">
              No active sessions found.
            </p>
          ) : (
            <ul className="space-y-2">
              {rows.map((row) => {
                const place = describeSessionPlace(row.user_agent)
                const isCurrent = row.id === currentId
                const since = formatSessionWhen(row.created_at)
                const lastActive = formatSessionWhen(
                  row.refreshed_at ?? row.updated_at ?? row.created_at,
                )
                return (
                  <li
                    key={row.id}
                    className="flex flex-wrap items-start justify-between gap-3 rounded-lg border border-[rgba(237,230,218,0.12)] bg-forja-bg/40 px-3 py-3"
                  >
                    <div className="flex min-w-0 items-start gap-3">
                      <MonitorSmartphone
                        className="mt-0.5 size-5 shrink-0 text-forja-green"
                        aria-hidden
                      />
                      <div className="min-w-0">
                        <p className="text-sm font-medium text-[#EDE6DA]">
                          {place.label}
                          {isCurrent ? (
                            <span className="ml-2 font-mono-ui text-[10px] uppercase tracking-[0.14em] text-forja-green">
                              This browser
                            </span>
                          ) : null}
                        </p>
                        {place.detail ? (
                          <p className="mt-0.5 text-xs text-[rgba(237,230,218,0.45)]">
                            {place.detail}
                          </p>
                        ) : null}
                        <p className="mt-1 text-xs text-[rgba(237,230,218,0.45)]">
                          Since {since}
                          {' · '}
                          Last active {lastActive}
                          {row.ip ? ` · ${row.ip}` : null}
                        </p>
                      </div>
                    </div>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="text-red-300 hover:text-red-200"
                      disabled={revokingId === row.id}
                      onClick={() => void onRevoke(row.id)}
                    >
                      {revokingId === row.id
                        ? 'Revoking…'
                        : isCurrent
                          ? 'Sign out'
                          : 'Revoke'}
                    </Button>
                  </li>
                )
              })}
            </ul>
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
