import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus, Trash2 } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Panel, PanelLabel, selectClassName } from '@/components/admin-ui'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  assignPortal,
  fetchAccountProfiles,
  fetchAssignmentsForPortal,
  searchAccounts,
  searchPortals,
  unassignPortal,
  type AccountHit,
  type PortalHit,
} from '@/lib/iptv-portal-assign'
import { cn } from '@/lib/utils'

type Mode =
  | { kind: 'toAccount'; accountId: string; accountEmail: string | null }
  | { kind: 'toPortal'; portalId: string; portalLabel: string }

export function IptvAssignDialog({
  mode,
  onClose,
  onDone,
}: {
  mode: Mode
  onClose: () => void
  onDone: () => void
}) {
  const [profileId, setProfileId] = useState('')
  const [accountId, setAccountId] = useState(
    mode.kind === 'toAccount' ? mode.accountId : '',
  )
  const [accountQ, setAccountQ] = useState('')
  const [portalId, setPortalId] = useState(
    mode.kind === 'toPortal' ? mode.portalId : '',
  )
  const [portalQ, setPortalQ] = useState('')
  const [burnCredit, setBurnCredit] = useState(false)
  const [bumpDealt, setBumpDealt] = useState(true)
  const [pickedAccount, setPickedAccount] = useState<AccountHit | null>(null)
  const [pickedPortal, setPickedPortal] = useState<PortalHit | null>(null)
  const [error, setError] = useState<string | null>(null)

  const profiles = useQuery({
    queryKey: ['admin', 'assign', 'profiles', accountId],
    queryFn: () => fetchAccountProfiles(accountId),
    enabled: !!accountId,
  })

  useEffect(() => {
    const list = profiles.data ?? []
    if (list.length === 0) {
      setProfileId('')
      return
    }
    if (!list.some((p) => p.id === profileId)) {
      setProfileId(list[0].id)
    }
  }, [profiles.data, profileId])

  const accounts = useQuery({
    queryKey: ['admin', 'assign', 'accounts', accountQ],
    queryFn: () => searchAccounts(accountQ),
    enabled: mode.kind === 'toPortal',
  })

  const portals = useQuery({
    queryKey: ['admin', 'assign', 'portals', portalQ],
    queryFn: () => searchPortals(portalQ),
    enabled: mode.kind === 'toAccount',
  })

  const save = useMutation({
    mutationFn: () =>
      assignPortal({
        profileId,
        portalId,
        burnCredit,
        bumpDealt,
      }),
    onSuccess: () => {
      setError(null)
      onDone()
      onClose()
    },
    onError: (e: Error) => setError(e.message),
  })

  const canSave = !!profileId && !!portalId && !save.isPending

  return (
    <div className="fixed inset-0 z-60 flex items-center justify-center bg-black/60 p-4">
      <Panel className="w-full max-w-lg space-y-4" tone="elevated">
        <div className="flex items-start justify-between gap-3">
          <div>
            <PanelLabel>Assign portal</PanelLabel>
            <p className="mt-1 text-sm text-forja-muted">
              {mode.kind === 'toAccount'
                ? `To ${mode.accountEmail ?? 'account'}`
                : `Portal ${mode.portalLabel}`}
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={onClose}>
            Close
          </Button>
        </div>

        {mode.kind === 'toPortal' ? (
          <div className="space-y-2">
            <Label>Account</Label>
            <Input
              placeholder="Search email…"
              value={accountQ}
              onChange={(e) => {
                setAccountQ(e.target.value)
                setPickedAccount(null)
                setAccountId('')
              }}
            />
            <div className="max-h-40 overflow-y-auto rounded-lg border border-forja-border">
              {(accounts.data ?? []).map((a) => {
                const active = accountId === a.id
                return (
                  <button
                    key={a.id}
                    type="button"
                    onClick={() => {
                      setAccountId(a.id)
                      setPickedAccount(a)
                    }}
                    className={cn(
                      'flex w-full items-center justify-between px-3 py-2 text-left text-sm hover:bg-white/5',
                      active && 'bg-forja-green/10 text-forja-green',
                    )}
                  >
                    <span className="truncate">{a.email ?? a.id.slice(0, 8)}</span>
                    <span className="text-xs text-forja-muted">
                      {a.iptv_credits} cr
                    </span>
                  </button>
                )
              })}
              {accounts.isFetched && (accounts.data?.length ?? 0) === 0 ? (
                <p className="px-3 py-2 text-sm text-forja-muted">No accounts</p>
              ) : null}
            </div>
            {pickedAccount ? (
              <p className="text-xs text-forja-muted">
                Selected {pickedAccount.email ?? pickedAccount.id.slice(0, 8)}
              </p>
            ) : null}
          </div>
        ) : null}

        {mode.kind === 'toAccount' ? (
          <div className="space-y-2">
            <Label>Portal</Label>
            <Input
              placeholder="Search url or username…"
              value={portalQ}
              onChange={(e) => {
                setPortalQ(e.target.value)
                setPickedPortal(null)
                setPortalId('')
              }}
            />
            <div className="max-h-40 overflow-y-auto rounded-lg border border-forja-border">
              {(portals.data ?? []).map((p) => {
                const active = portalId === p.id
                return (
                  <button
                    key={p.id}
                    type="button"
                    onClick={() => {
                      setPortalId(p.id)
                      setPickedPortal(p)
                    }}
                    className={cn(
                      'flex w-full flex-col gap-0.5 px-3 py-2 text-left hover:bg-white/5',
                      active && 'bg-forja-green/10',
                    )}
                  >
                    <span className="truncate text-sm font-medium text-forja-text">
                      {p.username}
                      {p.catalog_pool ? (
                        <span className="ml-2 text-[10px] font-semibold uppercase tracking-wide text-forja-green">
                          pool
                        </span>
                      ) : null}
                    </span>
                    <span className="truncate text-xs text-forja-muted">
                      {p.url}
                    </span>
                  </button>
                )
              })}
              {portals.isFetched && (portals.data?.length ?? 0) === 0 ? (
                <p className="px-3 py-2 text-sm text-forja-muted">No portals</p>
              ) : null}
            </div>
            {pickedPortal ? (
              <p className="text-xs text-forja-muted">
                Selected {pickedPortal.username}
              </p>
            ) : null}
          </div>
        ) : null}

        <div className="space-y-1.5">
          <Label htmlFor="assign-profile">Profile</Label>
          <select
            id="assign-profile"
            className={selectClassName}
            disabled={!accountId || profiles.isLoading}
            value={profileId}
            onChange={(e) => setProfileId(e.target.value)}
          >
            {(profiles.data ?? []).length === 0 ? (
              <option value="">
                {accountId ? 'No profiles' : 'Pick an account first'}
              </option>
            ) : (
              (profiles.data ?? []).map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))
            )}
          </select>
        </div>

        <div className="flex flex-wrap gap-4 text-sm">
          <label className="inline-flex items-center gap-2 text-forja-text">
            <input
              type="checkbox"
              checked={bumpDealt}
              onChange={(e) => setBumpDealt(e.target.checked)}
              className="accent-forja-green"
            />
            Bump dealt_count
          </label>
          <label className="inline-flex items-center gap-2 text-forja-text">
            <input
              type="checkbox"
              checked={burnCredit}
              onChange={(e) => setBurnCredit(e.target.checked)}
              className="accent-forja-green"
            />
            Burn 1 credit
          </label>
        </div>

        {error ? <p className="text-sm text-red-400">{error}</p> : null}

        <div className="flex justify-end gap-2">
          <Button type="button" variant="secondary" size="sm" onClick={onClose}>
            Cancel
          </Button>
          <Button
            type="button"
            size="sm"
            disabled={!canSave}
            onClick={() => save.mutate()}
          >
            {save.isPending ? 'Assigning…' : 'Assign'}
          </Button>
        </div>
      </Panel>
    </div>
  )
}

/** Pool side: who has this portal + assign / unassign. */
export function IptvPortalPeopleDialog({
  portalId,
  portalLabel,
  onClose,
}: {
  portalId: string
  portalLabel: string
  onClose: () => void
}) {
  const qc = useQueryClient()
  const [assignOpen, setAssignOpen] = useState(false)

  const list = useQuery({
    queryKey: ['admin', 'portal_assignees', portalId],
    queryFn: () => fetchAssignmentsForPortal(portalId),
  })

  const remove = useMutation({
    mutationFn: (assignmentId: string) => unassignPortal(assignmentId),
    onSuccess: async () => {
      await qc.invalidateQueries({
        queryKey: ['admin', 'portal_assignees', portalId],
      })
      await qc.invalidateQueries({ queryKey: ['admin', 'account_portals'] })
      await qc.invalidateQueries({
        queryKey: ['admin', 'account_portal_counts'],
      })
    },
  })

  return (
    <>
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
        <Panel className="w-full max-w-lg space-y-4" tone="elevated">
          <div className="flex items-start justify-between gap-3">
            <div>
              <PanelLabel>Assigned accounts</PanelLabel>
              <p className="mt-1 truncate text-sm text-forja-muted">
                {portalLabel}
              </p>
            </div>
            <Button type="button" variant="ghost" size="sm" onClick={onClose}>
              Close
            </Button>
          </div>

          <div className="flex justify-end">
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() => setAssignOpen(true)}
            >
              <Plus className="size-3.5" />
              Assign to account
            </Button>
          </div>

          {list.error ? (
            <p className="text-sm text-red-400">
              {(list.error as Error).message}
            </p>
          ) : null}
          {remove.error ? (
            <p className="text-sm text-red-400">{remove.error.message}</p>
          ) : null}

          {list.isLoading ? (
            <p className="text-sm text-forja-muted">Loading…</p>
          ) : (list.data?.length ?? 0) === 0 ? (
            <p className="text-sm text-forja-muted">
              Nobody has this portal yet.
            </p>
          ) : (
            <ul className="max-h-72 space-y-1.5 overflow-y-auto">
              {(list.data ?? []).map((a) => (
                <li
                  key={a.id}
                  className="flex items-center gap-3 rounded-lg border border-forja-border/70 bg-black/20 px-3 py-2"
                >
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium text-forja-text">
                      {a.account_email ?? a.profile_id.slice(0, 8)}
                    </p>
                    <p className="truncate text-xs text-forja-muted">
                      {a.profile_name}
                    </p>
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    className="size-8 shrink-0 text-forja-muted hover:text-red-300"
                    disabled={remove.isPending}
                    aria-label="Unassign"
                    onClick={() => remove.mutate(a.id)}
                  >
                    <Trash2 className="size-3.5" />
                  </Button>
                </li>
              ))}
            </ul>
          )}
        </Panel>
      </div>

      {assignOpen ? (
        <IptvAssignDialog
          mode={{ kind: 'toPortal', portalId, portalLabel }}
          onClose={() => setAssignOpen(false)}
          onDone={() => {
            void qc.invalidateQueries({
              queryKey: ['admin', 'portal_assignees', portalId],
            })
            void qc.invalidateQueries({
              queryKey: ['admin', 'account_portal_counts'],
            })
            void qc.invalidateQueries({ queryKey: ['admin', 'pool'] })
          }}
        />
      ) : null}
    </>
  )
}
