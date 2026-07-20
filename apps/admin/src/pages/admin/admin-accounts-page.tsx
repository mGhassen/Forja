import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Search } from 'lucide-react'
import { useState } from 'react'
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
import { cn } from '@/lib/utils'

type AccountRow = {
  id: string
  email: string | null
  is_admin: boolean
  iptv_credits: number
  features: { iptvScrape?: boolean } | null
}

export function AdminAccountsPage() {
  const qc = useQueryClient()
  const [q, setQ] = useState('')

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

  const setScrape = useMutation({
    mutationFn: async ({ id, enabled }: { id: string; enabled: boolean }) => {
      const { error } = await adminDb.rpc('admin_set_iptv_scrape', {
        p_account_id: id,
        p_enabled: enabled,
      })
      if (error) throw error
    },
    onSuccess: () =>
      void qc.invalidateQueries({ queryKey: ['admin', 'accounts'] }),
  })

  const adjustCredits = useMutation({
    mutationFn: async ({ id, delta }: { id: string; delta: number }) => {
      const { error } = await adminDb.rpc('admin_adjust_iptv_credits', {
        p_account_id: id,
        p_delta: delta,
        p_reason: delta > 0 ? 'admin grant' : 'admin revoke',
      })
      if (error) throw error
    },
    onSuccess: () =>
      void qc.invalidateQueries({ queryKey: ['admin', 'accounts'] }),
  })

  const busy = setScrape.isPending || adjustCredits.isPending

  return (
    <div className="space-y-6">
      <PageHeader
        title="Accounts"
        description="Grant IPTV credits and toggle client Find Portals (iptvScrape)."
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
                  <th className={thClassName}>Email</th>
                  <th className={thClassName}>Credits</th>
                  <th className={thClassName}>Scrape</th>
                  <th className={thClassName}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {(list.data ?? []).map((a) => {
                  const scrape = a.features?.iptvScrape === true
                  return (
                    <tr
                      key={a.id}
                      className="border-t border-forja-border/80 hover:bg-white/[0.02]"
                    >
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
                          'font-disp text-base tabular-nums',
                        )}
                      >
                        {a.iptv_credits ?? 0}
                      </td>
                      <td className={tdClassName}>
                        <span
                          className={cn(
                            'inline-flex rounded-full px-2 py-0.5 text-xs font-semibold',
                            scrape
                              ? 'bg-forja-green/15 text-forja-green'
                              : 'bg-white/5 text-forja-muted',
                          )}
                        >
                          {scrape ? 'On' : 'Off'}
                        </span>
                      </td>
                      <td className={cn(tdClassName, 'space-x-1')}>
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          disabled={busy}
                          onClick={() =>
                            setScrape.mutate({ id: a.id, enabled: !scrape })
                          }
                        >
                          {scrape ? 'Disable scrape' : 'Enable scrape'}
                        </Button>
                        <Button
                          type="button"
                          variant="secondary"
                          size="sm"
                          disabled={busy}
                          onClick={() =>
                            adjustCredits.mutate({ id: a.id, delta: 5 })
                          }
                        >
                          +5
                        </Button>
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          disabled={busy}
                          onClick={() =>
                            adjustCredits.mutate({ id: a.id, delta: -1 })
                          }
                        >
                          −1
                        </Button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
