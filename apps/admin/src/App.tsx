import { Navigate, Route, Routes } from 'react-router-dom'
import { useAuth } from '@/hooks/use-auth'
import { useIsAdmin } from '@/hooks/use-is-admin'
import { Layout } from '@/components/Layout'
import { LoginPage } from '@/pages/LoginPage'
import { DashboardPage } from '@/pages/DashboardPage'
import { AccountsPage } from '@/pages/AccountsPage'
import { PoolPage } from '@/pages/PoolPage'
import { ScrapeRunsPage } from '@/pages/ScrapeRunsPage'
import { supabaseConfigured } from '@/lib/supabase'

function Gate({ children }: { children: React.ReactNode }) {
  const { session, loading } = useAuth()
  const admin = useIsAdmin()

  if (!supabaseConfigured) {
    return (
      <div className="mx-auto max-w-lg p-8 text-sm text-amber-200">
        Set <code>VITE_SUPABASE_URL</code> and{' '}
        <code>VITE_SUPABASE_PUBLISHABLE_KEY</code> in{' '}
        <code>apps/admin/.env</code> (same project as Forja web).
      </div>
    )
  }
  if (loading || admin.isLoading) {
    return <div className="p-8 text-zinc-400">Loading…</div>
  }
  if (!session) return <Navigate to="/login" replace />
  if (!admin.data) {
    return (
      <div className="mx-auto max-w-lg p-8 text-sm text-red-300">
        Signed in, but this account is not <code>is_admin</code>.
      </div>
    )
  }
  return <>{children}</>
}

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/*"
        element={
          <Gate>
            <Layout>
              <Routes>
                <Route path="/" element={<DashboardPage />} />
                <Route path="/accounts" element={<AccountsPage />} />
                <Route path="/pool" element={<PoolPage />} />
                <Route path="/scrape" element={<ScrapeRunsPage />} />
              </Routes>
            </Layout>
          </Gate>
        }
      />
    </Routes>
  )
}
