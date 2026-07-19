import { useQuery } from '@tanstack/react-query'
import { adminDb } from '@/lib/admin-db'

export function AdminDashboardPage() {
  const stats = useQuery({
    queryKey: ['admin', 'dashboard'],
    queryFn: async () => {
      const [pool, alive, runs, accounts] = await Promise.all([
        adminDb
          .from('iptv_catalog_candidates')
          .select('id', { count: 'exact', head: true }),
        adminDb
          .from('iptv_catalog_candidates')
          .select('id', { count: 'exact', head: true })
          .eq('alive', true),
        adminDb
          .from('iptv_scrape_runs')
          .select('id', { count: 'exact', head: true }),
        adminDb.from('accounts').select('id', { count: 'exact', head: true }),
      ])
      return {
        pool: pool.count ?? 0,
        alive: alive.count ?? 0,
        runs: runs.count ?? 0,
        accounts: accounts.count ?? 0,
        err:
          pool.error?.message ||
          alive.error?.message ||
          runs.error?.message ||
          accounts.error?.message,
      }
    },
  })

  const d = stats.data
  return (
    <div className="space-y-4">
      <h1 className="font-disp text-xl font-bold tracking-tight">
        IPTV catalog ops
      </h1>
      <p className="text-sm text-forja-muted">
        Central scrape pool + credits. Fill via Inngest on this admin app (
        <code className="rounded border border-forja-border bg-forja-elevated px-1.5 py-0.5 font-mono-ui text-xs">
          iptv-catalog-scrape
        </code>
        ) — each portal status-checked via{' '}
        <code className="font-mono-ui text-xs">player_api</code>.
      </p>
      {d?.err ? (
        <p className="text-sm text-amber-300">
          {d.err} — apply migration{' '}
          <code className="font-mono-ui text-xs">
            20260718224617_iptv_catalog_ops.sql
          </code>{' '}
          first.
        </p>
      ) : null}
      <div className="grid gap-3 sm:grid-cols-4">
        {[
          ['Accounts', d?.accounts],
          ['Pool', d?.pool],
          ['Alive', d?.alive],
          ['Scrape runs', d?.runs],
        ].map(([label, n]) => (
          <div
            key={String(label)}
            className="rounded-xl border border-forja-border bg-forja-elevated/50 p-4"
          >
            <div className="font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] text-forja-muted">
              {label}
            </div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">
              {stats.isLoading ? '…' : (n ?? '—')}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
