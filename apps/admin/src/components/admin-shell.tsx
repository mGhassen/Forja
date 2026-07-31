import type { ReactNode } from 'react'
import { Link, Outlet, useRouterState } from '@tanstack/react-router'
import {
  Boxes,
  FileCode2,
  LayoutDashboard,
  LogOut,
  Radar,
  Server,
  Users,
} from 'lucide-react'
import { BrandLogo } from '@/components/brand-logo'
import { OpsOverviewStrip } from '@/components/ops-overview-strip'
import { Button } from '@/components/ui/button'
import { useAuth } from '@/hooks/use-auth'
import { cn } from '@/lib/utils'

const NAV = [
  { to: '/' as const, label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/accounts' as const, label: 'Accounts', icon: Users, end: false },
  { to: '/pool' as const, label: 'Pool', icon: Boxes, end: false },
  { to: '/scrape' as const, label: 'Scrape', icon: Radar, end: false },
  { to: '/deep-refs' as const, label: 'Deep refs', icon: FileCode2, end: false },
  { to: '/providers' as const, label: 'Providers', icon: Server, end: false },
]

export function AdminShell({ children }: { children?: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname })
  const { user, signOut } = useAuth()

  return (
    <div className="relative min-h-screen bg-forja-bg text-forja-text">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-0 top-0 h-56 bg-[radial-gradient(ellipse_at_top,rgba(28,231,131,0.08),transparent_55%)]"
      />
      <header className="sticky top-0 z-40 border-b border-forja-border/80 bg-forja-bg/85 backdrop-blur-xl">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center gap-3 px-4 py-3 sm:px-6">
          <div className="flex items-center gap-2.5">
            <BrandLogo to="/" imgClassName="h-7" />
            <div className="leading-none">
              <span className="font-disp text-sm font-bold uppercase tracking-tight text-forja-green">
                Admin
              </span>
              <p className="mt-0.5 hidden text-[10px] text-forja-muted sm:block">
                IPTV catalog ops
              </p>
            </div>
          </div>

          <nav className="flex flex-1 flex-wrap items-center gap-1">
            {NAV.map((item) => {
              const active = item.end
                ? pathname === item.to || pathname === `${item.to}/`
                : pathname === item.to || pathname.startsWith(`${item.to}/`)
              const Icon = item.icon
              return (
                <Link
                  key={item.to}
                  to={item.to}
                  className={cn(
                    'inline-flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-sm transition-colors',
                    active
                      ? 'bg-forja-green/15 text-forja-green shadow-[inset_0_0_0_1px_rgba(28,231,131,0.22)]'
                      : 'text-forja-muted hover:bg-white/[0.04] hover:text-forja-text',
                  )}
                >
                  <Icon className="size-3.5 opacity-80" aria-hidden />
                  {item.label}
                </Link>
              )
            })}
          </nav>

          <div className="flex items-center gap-2">
            {user?.email ? (
              <span
                className="hidden max-w-[180px] truncate text-xs text-forja-muted md:inline"
                title={user.email}
              >
                {user.email}
              </span>
            ) : null}
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="gap-1.5"
              onClick={() => void signOut({ scope: 'local' })}
            >
              <LogOut className="size-3.5" aria-hidden />
              Sign out
            </Button>
          </div>
        </div>
      </header>

      <OpsOverviewStrip />

      <main className="relative mx-auto max-w-7xl px-4 py-6 sm:px-6 sm:py-8">
        {children ?? <Outlet />}
      </main>
    </div>
  )
}
