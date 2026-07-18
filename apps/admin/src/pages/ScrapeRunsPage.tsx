import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

type Run = {
  id: string
  started_at: string
  finished_at: string | null
  status: string
  posts_seen: number
  l1_extract_count: number
  l2_extract_count: number
  candidates_upserted: number
  alive_count: number
  error: string | null
}

export function ScrapeRunsPage() {
  const list = useQuery({
    queryKey: ['admin', 'scrape_runs'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('iptv_scrape_runs')
        .select(
          'id, started_at, finished_at, status, posts_seen, l1_extract_count, l2_extract_count, candidates_upserted, alive_count, error',
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
      <h1 className="text-lg font-semibold">Scrape runs</h1>
      <p className="text-sm text-zinc-400">
        Triggered by <code>iptv-worker</code> (service role). Example:
      </p>
      <pre className="overflow-x-auto rounded border border-zinc-800 bg-zinc-900 p-3 text-xs text-zinc-300">
        {`export SUPABASE_URL=…
export SUPABASE_SERVICE_ROLE_KEY=…
cd crates && cargo run -p iptv-worker -- scrape --max-pages 10 --verify`}
      </pre>
      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
      ) : null}
      <div className="overflow-x-auto rounded border border-zinc-800">
        <table className="w-full text-left text-sm">
          <thead className="bg-zinc-900 text-zinc-500">
            <tr>
              <th className="px-3 py-2">Started</th>
              <th className="px-3 py-2">Status</th>
              <th className="px-3 py-2">Pages</th>
              <th className="px-3 py-2">L1</th>
              <th className="px-3 py-2">Upserted</th>
              <th className="px-3 py-2">Alive</th>
            </tr>
          </thead>
          <tbody>
            {(list.data ?? []).map((r) => (
              <tr key={r.id} className="border-t border-zinc-800">
                <td className="px-3 py-2 text-xs">
                  {new Date(r.started_at).toLocaleString()}
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
