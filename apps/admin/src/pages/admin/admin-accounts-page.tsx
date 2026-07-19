import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { adminDb } from '@/lib/admin-db'

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
    onSuccess: () => void qc.invalidateQueries({ queryKey: ['admin', 'accounts'] }),
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
    onSuccess: () => void qc.invalidateQueries({ queryKey: ['admin', 'accounts'] }),
  })

  return (
    <div className="space-y-4">
      <h1 className="font-disp text-xl font-bold tracking-tight">Accounts</h1>
      <Input
        className="max-w-md"
        placeholder="Filter email…"
        value={q}
        onChange={(e) => setQ(e.target.value)}
      />
      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
      ) : null}
      <div className="overflow-x-auto rounded-xl border border-forja-border">
        <table className="w-full text-left text-sm">
          <thead className="bg-forja-elevated text-forja-muted">
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
                <tr key={a.id} className="border-t border-forja-border">
                  <td className="px-3 py-2">
                    {a.email ?? a.id.slice(0, 8)}
                    {a.is_admin ? (
                      <span className="ml-2 text-xs text-amber-400">admin</span>
                    ) : null}
                  </td>
                  <td className="px-3 py-2 tabular-nums">{a.iptv_credits ?? 0}</td>
                  <td className="px-3 py-2">{scrape ? 'on' : 'off'}</td>
                  <td className="space-x-2 px-3 py-2">
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="h-auto px-0 text-forja-green"
                      onClick={() =>
                        setScrape.mutate({ id: a.id, enabled: !scrape })
                      }
                    >
                      {scrape ? 'Disable scrape' : 'Enable scrape'}
                    </Button>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="h-auto px-0 text-sky-400"
                      onClick={() =>
                        adjustCredits.mutate({ id: a.id, delta: 5 })
                      }
                    >
                      +5 credits
                    </Button>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="h-auto px-0 text-forja-muted"
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
  )
}
