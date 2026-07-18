import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { supabase } from '@/lib/supabase'

type AccountRow = {
  id: string
  email: string | null
  is_admin: boolean
  iptv_credits: number
  features: { iptvScrape?: boolean } | null
}

export function AccountsPage() {
  const qc = useQueryClient()
  const [q, setQ] = useState('')

  const list = useQuery({
    queryKey: ['admin', 'accounts', q],
    queryFn: async () => {
      let req = supabase
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
    mutationFn: async ({
      id,
      enabled,
    }: {
      id: string
      enabled: boolean
    }) => {
      const { error } = await supabase.rpc('admin_set_iptv_scrape', {
        p_account_id: id,
        p_enabled: enabled,
      })
      if (error) throw error
    },
    onSuccess: () => void qc.invalidateQueries({ queryKey: ['admin', 'accounts'] }),
  })

  const adjustCredits = useMutation({
    mutationFn: async ({
      id,
      delta,
    }: {
      id: string
      delta: number
    }) => {
      const { error } = await supabase.rpc('admin_adjust_iptv_credits', {
        p_account_id: id,
        p_delta: delta,
        p_reason: delta > 0 ? 'admin grant' : 'admin revoke',
      })
      if (error) throw error
    },
    onSuccess: () => void qc.invalidateQueries({ queryKey: ['admin', 'accounts'] }),
  })

  return (
    <div className="space-y-4">
      <h1 className="text-lg font-semibold">Accounts</h1>
      <input
        className="w-full max-w-md rounded border border-zinc-700 bg-zinc-900 px-3 py-2 text-sm"
        placeholder="Filter email…"
        value={q}
        onChange={(e) => setQ(e.target.value)}
      />
      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
      ) : null}
      <div className="overflow-x-auto rounded border border-zinc-800">
        <table className="w-full text-left text-sm">
          <thead className="bg-zinc-900 text-zinc-500">
            <tr>
              <th className="px-3 py-2 font-medium">Email</th>
              <th className="px-3 py-2 font-medium">Credits</th>
              <th className="px-3 py-2 font-medium">iptvScrape</th>
              <th className="px-3 py-2 font-medium">Actions</th>
            </tr>
          </thead>
          <tbody>
            {(list.data ?? []).map((a) => {
              const scrape = a.features?.iptvScrape === true
              return (
                <tr key={a.id} className="border-t border-zinc-800">
                  <td className="px-3 py-2">
                    {a.email ?? a.id.slice(0, 8)}
                    {a.is_admin ? (
                      <span className="ml-2 text-xs text-amber-400">admin</span>
                    ) : null}
                  </td>
                  <td className="px-3 py-2 tabular-nums">{a.iptv_credits ?? 0}</td>
                  <td className="px-3 py-2">{scrape ? 'on' : 'off'}</td>
                  <td className="space-x-2 px-3 py-2">
                    <button
                      type="button"
                      className="text-xs text-emerald-400 hover:underline"
                      onClick={() =>
                        setScrape.mutate({ id: a.id, enabled: !scrape })
                      }
                    >
                      {scrape ? 'Disable scrape' : 'Enable scrape'}
                    </button>
                    <button
                      type="button"
                      className="text-xs text-sky-400 hover:underline"
                      onClick={() =>
                        adjustCredits.mutate({ id: a.id, delta: 5 })
                      }
                    >
                      +5 credits
                    </button>
                    <button
                      type="button"
                      className="text-xs text-zinc-400 hover:underline"
                      onClick={() =>
                        adjustCredits.mutate({ id: a.id, delta: -1 })
                      }
                    >
                      −1
                    </button>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}
