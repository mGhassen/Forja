import type { ReactNode } from 'react'
import { Link, Outlet, useRouterState } from '@tanstack/react-router'
import { BrandLogo } from '@/components/brand-logo'
import { Button } from '@/components/ui/button'
import { useAuth } from '@/hooks/use-auth'
import { cn } from '@/lib/utils'

const NAV = [
  { to: '/' as const, label: 'Dashboard', end: true },
  { to: '/accounts' as const, label: 'Accounts', end: false },
  { to: '/pool' as const, label: 'Pool', end: false },
  { to: '/scrape' as const, label: 'Scrape', end: false },
  { to: '/providers' as const, label: 'Providers', end: false },
]

export function AdminShell({ children }: { children?: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname })
  const { signOut } = useAuth()

  return (
    <div className="min-h-screen bg-forja-bg text-forja-text">
      <header className="border-b border-forja-border bg-forja-elevated/40">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-3 px-4 py-3">
          <div className="flex items-center gap-2">
            <BrandLogo to="/" imgClassName="h-7" />
            <span className="font-disp text-sm font-bold uppercase tracking-tight text-forja-green">
              Admin
            </span>
          </div>
          <nav className="flex flex-1 flex-wrap gap-1">
            {NAV.map((item) => {
              const active = item.end
                ? pathname === item.to || pathname === `${item.to}/`
                : pathname === item.to || pathname.startsWith(`${item.to}/`)
              return (
                <Link
                  key={item.to}
                  to={item.to}
                  className={cn(
                    'rounded-md px-3 py-1.5 text-sm transition-colors',
                    active
                      ? 'bg-forja-green/15 text-forja-green'
                      : 'text-forja-muted hover:bg-white/5 hover:text-forja-text',
                  )}
                >
                  {item.label}
                </Link>
              )
            })}
          </nav>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={() => void signOut({ scope: 'local' })}
          >
            Sign out
          </Button>
        </div>
      </header>
      <main className="mx-auto max-w-6xl p-4 sm:p-6">
        {children ?? <Outlet />}
      </main>
    </div>
  )
}
