import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ChevronDown, ChevronRight, Minus, Plus, Search, Trash2 } from 'lucide-react'
import { Fragment, useMemo, useState } from 'react'
import { IptvAssignDialog } from '@/components/iptv-assign-dialog'
import {
  EmptyState,
  PageHeader,
  tableClassName,
  tableWrapClassName,
  tdClassName,
  thClassName,
} from '@/components/admin-ui'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { adminDb } from '@/lib/admin-db'
import {
  countAssignmentsForAccounts,
  fetchAssignmentsForAccount,
  unassignPortal,
} from '@/lib/iptv-portal-assign'
import { cn } from '@/lib/utils'

type AccountRow = {
  id: string
  email: string | null
  is_admin: boolean
  iptv_credits: number
  features: { iptvScrape?: boolean } | null
}

function AccountPortals({
  accountId,
  onAssign,
}: {
  accountId: string
  onAssign: () => void
}) {
  const qc = useQueryClient()
  const list = useQuery({
    queryKey: ['admin', 'account_portals', accountId],
    queryFn: () => fetchAssignmentsForAccount(accountId),
  })

  const remove = useMutation({
    mutationFn: (assignmentId: string) => unassignPortal(assignmentId),
    onSuccess: async () => {
      await qc.invalidateQueries({
        queryKey: ['admin', 'account_portals', accountId],
      })
      await qc.invalidateQueries({ queryKey: ['admin', 'account_portal_counts'] })
      await qc.invalidateQueries({ queryKey: ['admin', 'portal_assignees'] })
    },
  })

  return (
    <div className="space-y-3 border-t border-forja-border/80 bg-black/20 px-3 py-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted">
          Portals ({list.data?.length ?? 0})
        </p>
        <Button type="button" variant="secondary" size="sm" onClick={onAssign}>
          <Plus className="size-3.5" />
          Assign portal
        </Button>
      </div>
      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
      ) : null}
      {remove.error ? (
        <p className="text-sm text-red-400">{remove.error.message}</p>
      ) : null}
      {list.isLoading ? (
        <p className="text-sm text-forja-muted">Loading…</p>
      ) : (list.data?.length ?? 0) === 0 ? (
        <p className="text-sm text-forja-muted">No portals on this account.</p>
      ) : (
        <ul className="space-y-1.5">
          {(list.data ?? []).map((a) => (
            <li
              key={a.id}
              className="flex items-center gap-3 rounded-lg border border-forja-border/70 bg-forja-elevated/40 px-3 py-2"
            >
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium text-forja-text">
                  {a.username || '—'}
                  <span className="ml-2 text-xs font-normal text-forja-muted">
                    {a.profile_name}
                    {a.catalog_pool ? ' · pool' : ''}
                    {a.alive === true
                      ? ' · alive'
                      : a.alive === false
                        ? ' · dead'
                        : ''}
                  </span>
                </p>
                <p className="truncate text-xs text-forja-muted">{a.url}</p>
              </div>
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className="size-8 shrink-0 text-forja-muted hover:text-red-300"
                disabled={remove.isPending}
                aria-label="Unassign portal"
                onClick={() => remove.mutate(a.id)}
              >
                <Trash2 className="size-3.5" />
              </Button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

export function AdminAccountsPage() {
  const qc = useQueryClient()
  const [q, setQ] = useState('')
  const [busyId, setBusyId] = useState<string | null>(null)
  const [openId, setOpenId] = useState<string | null>(null)
  const [assignFor, setAssignFor] = useState<{
    id: string
    email: string | null
  } | null>(null)

  const list = useQuery({
    queryKey: ['admin', 'accounts', q],
    queryFn: async () => {
      let req = adminDb
        .from('accounts')
        .select('id, email, is_admin, iptv_credits, features')
        .order('created_at', { ascending: false })
        .limit(100)
      if (q.trim()) {
        req = req.ilike('email', `%${q.trim()}%`)
      }
      const { data, error } = await req
      if (error) throw error
      return (data ?? []) as AccountRow[]
    },
  })

  const accountIds = useMemo(
    () => (list.data ?? []).map((a) => a.id),
    [list.data],
  )

  const counts = useQuery({
    queryKey: ['admin', 'account_portal_counts', accountIds],
    queryFn: () => countAssignmentsForAccounts(accountIds),
    enabled: accountIds.length > 0,
  })

  const setScrape = useMutation({
    mutationFn: async ({ id, enabled }: { id: string; enabled: boolean }) => {
      setBusyId(id)
      const { error } = await adminDb.rpc('admin_set_iptv_scrape', {
        p_account_id: id,
        p_enabled: enabled,
      })
      if (error) throw error
    },
    onSettled: () => setBusyId(null),
    onSuccess: () =>
      void qc.invalidateQueries({ queryKey: ['admin', 'accounts'] }),
  })

  const adjustCredits = useMutation({
    mutationFn: async ({ id, delta }: { id: string; delta: number }) => {
      setBusyId(id)
      const { error } = await adminDb.rpc('admin_adjust_iptv_credits', {
        p_account_id: id,
        p_delta: delta,
        p_reason: delta > 0 ? 'admin grant' : 'admin revoke',
      })
      if (error) throw error
    },
    onSettled: () => setBusyId(null),
    onSuccess: () =>
      void qc.invalidateQueries({ queryKey: ['admin', 'accounts'] }),
  })

  return (
    <div className="space-y-6">
      <PageHeader
        title="Accounts"
        description="Credits, Find Portals, and per-account portal assignments."
      />

      <div className="relative max-w-md">
        <Search
          className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-forja-muted"
          aria-hidden
        />
        <Input
          className="pl-9"
          placeholder="Filter by email…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
      </div>

      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
      ) : null}
      {setScrape.error || adjustCredits.error ? (
        <p className="text-sm text-red-400">
          {(setScrape.error ?? adjustCredits.error)?.message}
        </p>
      ) : null}

      {!list.isLoading && (list.data?.length ?? 0) === 0 ? (
        <EmptyState
          title="No accounts"
          description={q.trim() ? 'Try another email filter.' : undefined}
        />
      ) : (
        <div className={tableWrapClassName}>
          <div className="overflow-x-auto">
            <table className={tableClassName}>
              <thead>
                <tr>
                  <th className={cn(thClassName, 'w-8')} />
                  <th className={thClassName}>Email</th>
                  <th className={cn(thClassName, 'w-20')}>Portals</th>
                  <th className={cn(thClassName, 'w-44')}>Credits</th>
                  <th className={cn(thClassName, 'w-36')}>Find portals</th>
                </tr>
              </thead>
              <tbody>
                {(list.data ?? []).map((a) => {
                  const scrape = a.features?.iptvScrape === true
                  const credits = a.iptv_credits ?? 0
                  const rowBusy = busyId === a.id
                  const expanded = openId === a.id
                  const portalCount = counts.data?.[a.id] ?? 0
                  return (
                    <Fragment key={a.id}>
                      <tr className="border-t border-forja-border/80 hover:bg-white/2">
                        <td className={tdClassName}>
                          <button
                            type="button"
                            aria-expanded={expanded}
                            aria-label={
                              expanded ? 'Collapse portals' : 'Expand portals'
                            }
                            className="inline-flex size-7 items-center justify-center rounded-md text-forja-muted hover:bg-white/5 hover:text-forja-text"
                            onClick={() =>
                              setOpenId((cur) => (cur === a.id ? null : a.id))
                            }
                          >
                            {expanded ? (
                              <ChevronDown className="size-4" />
                            ) : (
                              <ChevronRight className="size-4" />
                            )}
                          </button>
                        </td>
                        <td className={tdClassName}>
                          <span className="font-medium">
                            {a.email ?? a.id.slice(0, 8)}
                          </span>
                          {a.is_admin ? (
                            <span className="ml-2 inline-flex rounded-full bg-amber-400/15 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-300">
                              admin
                            </span>
                          ) : null}
                        </td>
                        <td
                          className={cn(
                            tdClassName,
                            'tabular-nums text-forja-muted',
                          )}
                        >
                          {counts.isLoading ? '…' : portalCount}
                        </td>
                        <td className={tdClassName}>
                          <div className="inline-flex items-center gap-1.5">
                            <button
                              type="button"
                              disabled={rowBusy || credits <= 0}
                              aria-label="Revoke 1 credit"
                              title="−1"
                              onClick={() =>
                                adjustCredits.mutate({ id: a.id, delta: -1 })
                              }
                              className="inline-flex size-7 items-center justify-center rounded-md border border-forja-border text-forja-muted transition-colors hover:bg-white/5 hover:text-forja-text disabled:pointer-events-none disabled:opacity-40"
                            >
                              <Minus className="size-3.5" />
                            </button>
                            <span className="min-w-8 text-center font-disp text-base tabular-nums">
                              {credits}
                            </span>
                            <button
                              type="button"
                              disabled={rowBusy}
                              aria-label="Grant 5 credits"
                              title="+5"
                              onClick={() =>
                                adjustCredits.mutate({ id: a.id, delta: 5 })
                              }
                              className="inline-flex size-7 items-center justify-center rounded-md border border-forja-border text-forja-muted transition-colors hover:border-forja-green/40 hover:bg-forja-green/10 hover:text-forja-green disabled:pointer-events-none disabled:opacity-40"
                            >
                              <Plus className="size-3.5" />
                            </button>
                          </div>
                        </td>
                        <td className={tdClassName}>
                          <button
                            type="button"
                            role="switch"
                            aria-checked={scrape}
                            aria-label={
                              scrape
                                ? 'Disable Find Portals'
                                : 'Enable Find Portals'
                            }
                            disabled={rowBusy}
                            onClick={() =>
                              setScrape.mutate({ id: a.id, enabled: !scrape })
                            }
                            className={cn(
                              'relative h-7 w-12 shrink-0 rounded-full transition-colors',
                              scrape ? 'bg-forja-green' : 'bg-white/15',
                              rowBusy && 'opacity-60',
                            )}
                          >
                            <span
                              className={cn(
                                'absolute top-0.5 size-6 rounded-full bg-[#0B0A0A] shadow transition-transform',
                                scrape ? 'left-5' : 'left-0.5',
                              )}
                            />
                          </button>
                        </td>
                      </tr>
                      {expanded ? (
                        <tr>
                          <td colSpan={5} className="p-0">
                            <AccountPortals
                              accountId={a.id}
                              onAssign={() =>
                                setAssignFor({ id: a.id, email: a.email })
                              }
                            />
                          </td>
                        </tr>
                      ) : null}
                    </Fragment>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {assignFor ? (
        <IptvAssignDialog
          mode={{
            kind: 'toAccount',
            accountId: assignFor.id,
            accountEmail: assignFor.email,
          }}
          onClose={() => setAssignFor(null)}
          onDone={() => {
            void qc.invalidateQueries({
              queryKey: ['admin', 'account_portals', assignFor.id],
            })
            void qc.invalidateQueries({
              queryKey: ['admin', 'account_portal_counts'],
            })
            void qc.invalidateQueries({ queryKey: ['admin', 'accounts'] })
          }}
        />
      ) : null}
    </div>
  )
}
