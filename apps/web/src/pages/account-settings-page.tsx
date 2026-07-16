import { useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { SiteHeader } from '@/components/site-header'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { RequireAuth } from '@/components/require-auth'
import { useAuth } from '@/hooks/use-auth'
import { supabase, supabaseConfigured } from '@/lib/supabase'
import type { UserSetting } from '@/lib/database.types'

export function AccountSettingsPage() {
  const { user } = useAuth()

  const settingsQuery = useQuery({
    queryKey: ['user_settings', user?.id],
    enabled: Boolean(user?.id && supabaseConfigured),
    queryFn: async (): Promise<UserSetting[]> => {
      const { data, error } = await supabase
        .from('user_settings')
        .select('*')
        .eq('user_id', user!.id)
        .order('domain')
      if (error) throw error
      return data ?? []
    },
  })

  return (
    <RequireAuth>
      <div className="min-h-screen">
        <SiteHeader solid />
        <main className="mx-auto max-w-2xl px-6 py-16">
          <Button asChild variant="ghost" size="sm" className="-ml-2 mb-6">
            <Link to="/account">← Account</Link>
          </Button>
          <p className="font-display text-sm uppercase tracking-[0.3em] text-forja-green">
            Settings sync
          </p>
          <h1 className="mt-3 font-display text-4xl tracking-tight">Cloud domains</h1>
          <p className="mt-4 text-forja-muted">
            Domains synced from the Forja app appear here. Sync choices live in the
            app — this view is status only.
          </p>

          <Card className="mt-10">
            <CardHeader>
              <CardTitle>Synced domains</CardTitle>
              <CardDescription>
                Latest <code>updated_at</code> per domain.
              </CardDescription>
            </CardHeader>
            <CardContent>
              {settingsQuery.isLoading && (
                <p className="text-sm text-forja-muted">Loading…</p>
              )}
              {settingsQuery.isError && (
                <p className="text-sm text-red-300">
                  {settingsQuery.error instanceof Error
                    ? settingsQuery.error.message
                    : 'Failed to load settings'}
                </p>
              )}
              {settingsQuery.data && settingsQuery.data.length === 0 && (
                <p className="text-sm text-forja-muted">
                  No domains synced yet. When domains are enabled in Forja, they show
                  up here.
                </p>
              )}
              {settingsQuery.data && settingsQuery.data.length > 0 && (
                <ul className="divide-y divide-forja-border">
                  {settingsQuery.data.map((row) => (
                    <li
                      key={row.domain}
                      className="flex items-center justify-between gap-4 py-3 first:pt-0 last:pb-0"
                    >
                      <span className="font-medium">{row.domain}</span>
                      <span className="text-sm text-forja-muted">
                        {new Date(row.updated_at).toLocaleString()}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </CardContent>
          </Card>
        </main>
      </div>
    </RequireAuth>
  )
}
