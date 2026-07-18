import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

type Cand = {
  id: string
  url: string
  username: string
  alive: boolean | null
  region_primary: string
  region_confidence: number | null
  expiry: string | null
  dealt_count: number
  last_checked_at: string | null
}

export function PoolPage() {
  const list = useQuery({
    queryKey: ['admin', 'pool'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('iptv_catalog_candidates')
        .select(
          'id, url, username, alive, region_primary, region_confidence, expiry, dealt_count, last_checked_at',
        )
        .order('updated_at', { ascending: false })
        .limit(200)
      if (error) throw error
      return (data ?? []) as Cand[]
    },
  })

  return (
    <div className="space-y-4">
      <h1 className="text-lg font-semibold">Catalog pool</h1>
      <p className="text-sm text-zinc-400">
        Passwords hidden. Alive candidates are eligible for{' '}
        <code>deal_iptv_portals</code>.
      </p>
      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
      ) : null}
      <div className="overflow-x-auto rounded border border-zinc-800">
        <table className="w-full text-left text-sm">
          <thead className="bg-zinc-900 text-zinc-500">
            <tr>
              <th className="px-3 py-2">Host</th>
              <th className="px-3 py-2">User</th>
              <th className="px-3 py-2">Alive</th>
              <th className="px-3 py-2">Region</th>
              <th className="px-3 py-2">Conf</th>
              <th className="px-3 py-2">Dealt</th>
            </tr>
          </thead>
          <tbody>
            {(list.data ?? []).map((c) => (
              <tr key={c.id} className="border-t border-zinc-800">
                <td className="max-w-[240px] truncate px-3 py-2 font-mono text-xs">
                  {c.url}
                </td>
                <td className="px-3 py-2 font-mono text-xs">{c.username}</td>
                <td className="px-3 py-2">
                  {c.alive === true ? (
                    <span className="text-emerald-400">yes</span>
                  ) : c.alive === false ? (
                    <span className="text-red-400">no</span>
                  ) : (
                    <span className="text-zinc-500">?</span>
                  )}
                </td>
                <td className="px-3 py-2">{c.region_primary}</td>
                <td className="px-3 py-2 tabular-nums text-xs text-zinc-400">
                  {c.region_confidence != null
                    ? c.region_confidence.toFixed(2)
                    : '—'}
                </td>
                <td className="px-3 py-2 tabular-nums">{c.dealt_count}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
