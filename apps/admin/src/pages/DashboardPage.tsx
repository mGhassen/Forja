import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export function DashboardPage() {
  const stats = useQuery({
    queryKey: ['admin', 'dashboard'],
    queryFn: async () => {
      const [pool, alive, runs, accounts] = await Promise.all([
        supabase
          .from('iptv_catalog_candidates')
          .select('id', { count: 'exact', head: true }),
        supabase
          .from('iptv_catalog_candidates')
          .select('id', { count: 'exact', head: true })
          .eq('alive', true),
        supabase
          .from('iptv_scrape_runs')
          .select('id', { count: 'exact', head: true }),
        supabase.from('accounts').select('id', { count: 'exact', head: true }),
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
      <h1 className="text-lg font-semibold">IPTV catalog ops</h1>
      <p className="text-sm text-zinc-400">
        Central scrape pool + credits. Run the Rust worker to fill the pool:
        <code className="ml-1 rounded bg-zinc-900 px-1">
          cargo run -p iptv-worker -- scrape --verify
        </code>
      </p>
      {d?.err ? (
        <p className="text-sm text-amber-300">
          {d.err} — apply migration{' '}
          <code>20260718224617_iptv_catalog_ops.sql</code> first.
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
            className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-4"
          >
            <div className="text-xs uppercase tracking-wide text-zinc-500">
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
