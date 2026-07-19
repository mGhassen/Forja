import { useQuery } from '@tanstack/react-query'
import { adminDb } from '@/lib/admin-db'

type Run = {
  id: string
  started_at: string
  status: string
  posts_seen: number
  l1_extract_count: number
  candidates_upserted: number
  alive_count: number
  source?: string | null
}

export function AdminScrapePage() {
  const list = useQuery({
    queryKey: ['admin', 'scrape_runs'],
    queryFn: async () => {
      const { data, error } = await adminDb
        .from('iptv_scrape_runs')
        .select(
          'id, started_at, status, posts_seen, l1_extract_count, candidates_upserted, alive_count, source',
        )
        .order('started_at', { ascending: false })
        .limit(50)
      if (error) throw error
      return (data ?? []) as Run[]
    },
    refetchInterval: 15_000,
  })

  return (
    <div className="space-y-4">
      <h1 className="font-disp text-xl font-bold tracking-tight">Scrape runs</h1>
      <p className="text-sm text-forja-muted">
        Inngest on this admin app (daily cron + event{' '}
        <code className="font-mono-ui text-xs">iptv/catalog.scrape</code>).
        Each portal gets a{' '}
        <code className="font-mono-ui text-xs">verify-portal-status-*</code>{' '}
        step that hits Xtream{' '}
        <code className="font-mono-ui text-xs">player_api</code>.
      </p>
      <pre className="overflow-x-auto rounded-xl border border-forja-border bg-forja-elevated p-3 font-mono-ui text-xs text-forja-muted">
        {`# Local
cd apps/admin && pnpm dev          # :4000
npx inngest-cli@latest dev -u http://127.0.0.1:4000/api/inngest
# Invoke iptv-catalog-scrape (or event iptv/catalog.scrape)

# Deploy: SUPABASE_SERVICE_ROLE_KEY + INNGEST_* on the admin project`}
      </pre>
      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
      ) : null}
      <div className="overflow-x-auto rounded-xl border border-forja-border">
        <table className="w-full text-left text-sm">
          <thead className="bg-forja-elevated text-forja-muted">
            <tr>
              <th className="px-3 py-2">Started</th>
              <th className="px-3 py-2">Source</th>
              <th className="px-3 py-2">Status</th>
              <th className="px-3 py-2">Posts</th>
              <th className="px-3 py-2">L1</th>
              <th className="px-3 py-2">Upserted</th>
              <th className="px-3 py-2">Alive</th>
            </tr>
          </thead>
          <tbody>
            {(list.data ?? []).map((r) => (
              <tr key={r.id} className="border-t border-forja-border">
                <td className="px-3 py-2 text-xs">
                  {new Date(r.started_at).toLocaleString()}
                </td>
                <td className="px-3 py-2 font-mono-ui text-xs">
                  {r.source ?? '—'}
                </td>
                <td className="px-3 py-2">{r.status}</td>
                <td className="px-3 py-2 tabular-nums">{r.posts_seen}</td>
                <td className="px-3 py-2 tabular-nums">{r.l1_extract_count}</td>
                <td className="px-3 py-2 tabular-nums">
                  {r.candidates_upserted}
                </td>
                <td className="px-3 py-2 tabular-nums">{r.alive_count}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
