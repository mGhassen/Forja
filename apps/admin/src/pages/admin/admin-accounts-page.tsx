import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Minus, Plus, Search } from 'lucide-react'
import { useMemo, useState } from 'react'
import { AccountDetailPanel } from '@/components/account-detail-panel'
import { AccountFeaturesDialog } from '@/components/account-features-dialog'
import { IptvAssignDialog } from '@/components/iptv-assign-dialog'
import {
  EmptyState,
  PageHeader,
  TablePagination,
  tableClassName,
  tableWrapClassName,
  tdClassName,
  thClassName,
} from '@/components/admin-ui'
import { Input } from '@/components/ui/input'
import {
  enabledFeatureDefs,
  parseAccountFeatures,
  parseMaxIptvPortals,
} from '@/lib/account-features'
import { adminDb } from '@/lib/admin-db'
import { fetchAllRows } from '@/lib/fetch-all-rows'
import { countAssignmentsForAccounts } from '@/lib/iptv-portal-assign'
import {
  formatClientLabel,
  formatRelativeSeen,
  fetchPosthogPersons,
} from '@/lib/posthog-persons'
import { useTablePagination } from '@/lib/use-table-pagination'
import { cn } from '@/lib/utils'

type AccountRow = {
  id: string
  member_number: number
  email: string | null
  is_admin: boolean
  iptv_credits: number
  features: Record<string, unknown> | null
}

export function AdminAccountsPage() {
  const qc = useQueryClient()
  const [q, setQ] = useState('')
  const [busyId, setBusyId] = useState<string | null>(null)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [assignFor, setAssignFor] = useState<{
    id: string
    email: string | null
  } | null>(null)
  const [featuresFor, setFeaturesFor] = useState<AccountRow | null>(null)

  const list = useQuery({
    queryKey: ['admin', 'accounts', q],
    queryFn: async () => {
      const needle = q.trim()
      return fetchAllRows(async (from, to) => {
        let req = adminDb
          .from('accounts')
          .select('id, member_number, email, is_admin, iptv_credits, features')
          .order('created_at', { ascending: false })
          .range(from, to)
        if (needle) {
          const asNum = Number(needle)
          if (Number.isInteger(asNum) && asNum > 0) {
            req = req.eq('member_number', asNum)
          } else {
            req = req.ilike('email', `%${needle}%`)
          }
        }
        const { data, error } = await req
        if (error) throw error
        return (data ?? []) as AccountRow[]
      })
    },
  })

  const accountIds = useMemo(
    () => (list.data ?? []).map((a) => a.id),
    [list.data],
  )

  const paging = useTablePagination(list.data ?? [], {
    initialPageSize: 50,
    resetKey: q,
  })

  const pageIds = useMemo(
    () => paging.pageRows.map((a) => a.id),
    [paging.pageRows],
  )

  const counts = useQuery({
    queryKey: ['admin', 'account_portal_counts', accountIds],
    queryFn: () => countAssignmentsForAccounts(accountIds),
    enabled: accountIds.length > 0,
  })

  const posthog = useQuery({
    queryKey: ['admin', 'posthog_persons', pageIds],
    queryFn: () => fetchPosthogPersons(pageIds),
    enabled: pageIds.length > 0,
    staleTime: 60_000,
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

  const selected =
    selectedId == null
      ? null
      : (list.data?.find((a) => a.id === selectedId) ?? null)

  return (
    <div
      className={cn(
        'flex',
        selected
          ? '-ml-4 mr-[calc(50%-50vw)] sm:-ml-6'
          : '-mx-4 sm:-mx-6',
      )}
    >
      <div className="min-w-0 flex-1 space-y-6 px-4 sm:px-6">
        <PageHeader
          title="Accounts"
          description="Credits, feature flags, client runtime from PostHog, portal assignments, and cloud packs."
        />

        <div className="relative max-w-md">
          <Search
            className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-forja-muted"
            aria-hidden
          />
          <Input
            className="pl-9"
            placeholder="Filter by member # or email…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </div>

        {list.error ? (
          <p className="text-sm text-red-400">
            {(list.error as Error).message}
          </p>
        ) : null}
        {adjustCredits.error ? (
          <p className="text-sm text-red-400">{adjustCredits.error.message}</p>
        ) : null}
        {posthog.data && !posthog.data.configured ? (
          <p className="text-sm text-forja-muted">
            Client runtime hidden — set server{' '}
            <code className="font-mono-ui text-xs">
              POSTHOG_PERSONAL_API_KEY
            </code>{' '}
            +{' '}
            <code className="font-mono-ui text-xs">POSTHOG_PROJECT_ID</code>.
          </p>
        ) : null}
        {posthog.error ? (
          <p className="text-sm text-amber-300/90">
            PostHog: {(posthog.error as Error).message}
          </p>
        ) : null}
        {posthog.data?.error ? (
          <p className="text-sm text-amber-300/90">
            PostHog: {posthog.data.error}
          </p>
        ) : null}

        {!list.isLoading && (list.data?.length ?? 0) === 0 ? (
          <EmptyState
            title="No accounts"
            description={
              q.trim() ? 'Try another member # or email filter.' : undefined
            }
          />
        ) : (
          <div className={tableWrapClassName}>
            <div className="overflow-x-auto">
              <table className={tableClassName}>
                <thead>
                  <tr>
                    <th className={cn(thClassName, 'w-24')}>Member #</th>
                    <th className={thClassName}>Account</th>
                    <th className={cn(thClassName, 'w-28')}>App</th>
                    <th className={cn(thClassName, 'w-36')}>Client</th>
                    <th className={cn(thClassName, 'w-28')}>Last seen</th>
                    <th className={cn(thClassName, 'w-20')}>Portals</th>
                    <th className={cn(thClassName, 'w-44')}>Credits</th>
                    <th className={cn(thClassName, 'min-w-40')}>Features</th>
                  </tr>
                </thead>
                <tbody>
                  {paging.pageRows.map((a) => {
                    const feats = parseAccountFeatures(a.features)
                    const enabled = enabledFeatureDefs(feats)
                    const credits = a.iptv_credits ?? 0
                    const maxPortals = parseMaxIptvPortals(a.features)
                    const rowBusy = busyId === a.id
                    const selectedRow = selectedId === a.id
                    const portalCount = counts.data?.[a.id] ?? 0
                    const runtime = posthog.data?.persons[a.id]
                    const clientLabel = formatClientLabel(runtime)
                    const seenLabel = formatRelativeSeen(runtime?.lastSeenAt)
                    return (
                      <tr
                        key={a.id}
                        className={cn(
                          'cursor-pointer border-t border-forja-border/80 hover:bg-white/2',
                          selectedRow && 'bg-forja-green/8 hover:bg-forja-green/10',
                        )}
                        onClick={() =>
                          setSelectedId((cur) => (cur === a.id ? null : a.id))
                        }
                      >
                        <td
                          className={cn(
                            tdClassName,
                            'font-mono tabular-nums text-forja-muted',
                          )}
                        >
                          {a.member_number}
                        </td>
                        <td className={tdClassName}>
                          <div className="min-w-0">
                            <div className="flex flex-wrap items-center gap-2">
                              <span className="font-medium">
                                {a.email ?? a.id.slice(0, 8)}
                              </span>
                              {a.is_admin ? (
                                <span className="inline-flex rounded-full bg-amber-400/15 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-300">
                                  admin
                                </span>
                              ) : null}
                            </div>
                            {runtime?.osVersion ? (
                              <p className="mt-0.5 truncate text-[11px] text-forja-muted">
                                {runtime.osVersion}
                              </p>
                            ) : null}
                          </div>
                        </td>
                        <td
                          className={cn(
                            tdClassName,
                            'font-mono text-xs tabular-nums',
                          )}
                        >
                          {posthog.isLoading && !runtime
                            ? '…'
                            : (runtime?.appVersion ?? '—')}
                        </td>
                        <td className={cn(tdClassName, 'text-sm')}>
                          {posthog.isLoading && !runtime ? '…' : clientLabel}
                        </td>
                        <td
                          className={cn(
                            tdClassName,
                            'text-sm tabular-nums text-forja-muted',
                          )}
                          title={runtime?.lastSeenAt ?? undefined}
                        >
                          {posthog.isLoading && !runtime ? '…' : seenLabel}
                        </td>
                        <td
                          className={cn(
                            tdClassName,
                            'tabular-nums text-forja-muted',
                          )}
                        >
                          {counts.isLoading ? '…' : portalCount}
                        </td>
                        <td
                          className={tdClassName}
                          onClick={(e) => e.stopPropagation()}
                        >
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
                        <td
                          className={tdClassName}
                          onClick={(e) => e.stopPropagation()}
                        >
                          <button
                            type="button"
                            onClick={() => setFeaturesFor(a)}
                            className="inline-flex max-w-full flex-wrap items-center gap-1 rounded-md border border-forja-border px-2 py-1 text-left transition-colors hover:border-forja-green/40 hover:bg-forja-green/5"
                            title="Edit feature flags"
                          >
                            <span className="rounded bg-white/8 px-1.5 py-0.5 text-[10px] font-semibold text-forja-muted">
                              {a.is_admin ? '∞ portals' : `Max ${maxPortals}`}
                            </span>
                            {enabled.length === 0 ? (
                              <span className="text-xs text-forja-muted">
                                Edit
                              </span>
                            ) : (
                              enabled.map((d) => (
                                <span
                                  key={d.key}
                                  className="rounded bg-forja-green/15 px-1.5 py-0.5 text-[10px] font-semibold text-forja-green"
                                >
                                  {d.shortLabel}
                                </span>
                              ))
                            )}
                          </button>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
            <TablePagination
              page={paging.page}
              pageSize={paging.pageSize}
              total={paging.total}
              onPageChange={paging.setPage}
              onPageSizeChange={paging.setPageSize}
            />
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

        {featuresFor ? (
          <AccountFeaturesDialog
            accountId={featuresFor.id}
            accountEmail={featuresFor.email}
            features={
              (list.data?.find((a) => a.id === featuresFor.id) ?? featuresFor)
                .features
            }
            isAdmin={
              (list.data?.find((a) => a.id === featuresFor.id) ?? featuresFor)
                .is_admin === true
            }
            onClose={() => setFeaturesFor(null)}
          />
        ) : null}
      </div>

      {selected ? (
        <AccountDetailPanel
          account={selected}
          runtime={posthog.data?.persons[selected.id]}
          runtimeLoading={posthog.isLoading}
          creditsBusy={busyId === selected.id}
          onClose={() => setSelectedId(null)}
          onAdjustCredits={(delta) =>
            adjustCredits.mutate({ id: selected.id, delta })
          }
          onEditFeatures={() => setFeaturesFor(selected)}
          onAssignPortal={() =>
            setAssignFor({ id: selected.id, email: selected.email })
          }
        />
      ) : null}
    </div>
  )
}
