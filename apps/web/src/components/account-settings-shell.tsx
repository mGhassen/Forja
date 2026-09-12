import type { ReactNode } from 'react'
import { Link, useNavigate, useRouterState } from '@tanstack/react-router'
import {
  ArrowLeft,
  Blocks,
  LayoutList,
  LogOut,
  MonitorSmartphone,
  Package,
  UserRound,
} from 'lucide-react'
import { SiteHeader } from '@/components/site-header'
import { RequireAuth } from '@/components/require-auth'
import { useAuth } from '@/hooks/use-auth'
import { useProfiles } from '@/hooks/use-profiles'
import { cn } from '@/lib/utils'

/** Nested under Addons hub — keep sidebar highlight on Addons. */
const ADDONS_NESTED_PREFIXES = [
  '/account/settings/playback',
  '/account/settings/iptv',
  '/account/settings/stremio',
  '/account/settings/nuvio',
  '/account/settings/torrent',
] as const

const profileCategories = [
  {
    href: '/account/settings/addons',
    title: 'Addons',
    subtitle: 'Playback, IPTV, torrent, Stremio, Nuvio',
    icon: Blocks,
  },
  {
    href: '/account/settings/forja',
    title: 'Forja Packs',
    subtitle: 'Install and manage Forja plugin packs',
    icon: Package,
  },
  {
    href: '/account/settings/navigation',
    title: 'Features',
    subtitle: 'Tabs, order, default menu',
    icon: LayoutList,
  },
] as const

const accountCategories = [
  {
    href: '/account/settings/account',
    title: 'Account',
    subtitle: 'Email, passkeys, and delete',
    icon: UserRound,
  },
  {
    href: '/account/settings/connections',
    title: 'Connections',
    subtitle: 'Devices, where, and since',
    icon: MonitorSmartphone,
  },
] as const

type AccountSettingsShellProps = {
  title?: string
  description?: string
  /** Which settings family this page belongs to (sidebar grouping). */
  section?: 'profile' | 'account'
  /** Wider content column for list-heavy pages (e.g. IPTV portals). */
  wide?: boolean
  children: ReactNode
  footer?: ReactNode
}

function NavGroup({
  label,
  hint,
  children,
}: {
  label: string
  hint: string
  children: ReactNode
}) {
  return (
    <div className="mb-5 last:mb-0">
      <div className="px-3 pb-2">
        <p className="font-mono-ui text-[10px] font-bold uppercase tracking-[0.16em] text-forja-green">
          {label}
        </p>
        <p className="mt-1 text-[11px] leading-snug text-forja-muted">{hint}</p>
      </div>
      <nav className="grid gap-0 sm:grid-cols-2 lg:grid-cols-1">{children}</nav>
    </div>
  )
}

function isProfileNavSelected(href: string, pathname: string): boolean {
  if (href === '/account/settings/addons') {
    if (pathname === href || pathname.startsWith(`${href}/`)) return true
    return ADDONS_NESTED_PREFIXES.some(
      (p) => pathname === p || pathname.startsWith(`${p}/`),
    )
  }
  return pathname === href
}

function NavLink({
  href,
  title,
  subtitle,
  icon: Icon,
  selected,
}: {
  href: string
  title: string
  subtitle: string
  icon: typeof Blocks
  selected: boolean
}) {
  return (
    <Link
      to={href}
      className={`relative flex min-h-16 items-center gap-4 border-l-[3px] px-3 py-3 ${
        selected
          ? 'border-forja-green bg-white/[0.035] text-forja-text'
          : 'border-transparent text-forja-muted hover:bg-white/2 hover:text-forja-text'
      }`}
    >
      <Icon
        className={`size-5.5 shrink-0 ${
          selected ? 'text-forja-green' : 'text-forja-muted'
        }`}
      />
      <span className="min-w-0">
        <span className={`block text-sm ${selected ? 'font-bold' : 'font-medium'}`}>
          {title}
        </span>
        <span className="mt-0.5 block truncate text-xs text-forja-muted">
          {subtitle}
        </span>
      </span>
    </Link>
  )
}

export function AccountSettingsShell({
  title,
  description,
  section = 'profile',
  wide = false,
  children,
  footer,
}: AccountSettingsShellProps) {
  const pathname = useRouterState({ select: (state) => state.location.pathname })
  const navigate = useNavigate()
  const { signOut } = useAuth()
  const { activeProfile } = useProfiles()

  async function onSignOut() {
    // Local only — keep the desktop app session alive.
    await signOut({ scope: 'local' })
    void navigate({ to: '/' })
  }

  return (
    <RequireAuth>
      <div className="min-h-screen">
        <SiteHeader solid />
        <main className="mx-auto max-w-6xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28">
          <div className="mb-7 flex flex-wrap items-center gap-3">
            <Link
              to="/account/profiles"
              className="flex size-9 items-center justify-center text-forja-muted hover:text-forja-text"
              aria-label="Back to Who's watching"
            >
              <ArrowLeft className="size-5" />
            </Link>
            <div>
              <h1 className="font-display text-2xl tracking-tight">
                {section === 'account' ? 'Account' : 'Profile settings'}
              </h1>
              <p className="mt-0.5 text-xs text-forja-muted">
                {section === 'account'
                  ? 'Signed-in Forja account'
                  : `Synced for ${activeProfile?.name ?? 'this profile'}`}
              </p>
            </div>
          </div>

          <div className="grid min-h-155 lg:grid-cols-[310px_1fr]">
            <aside className="border-b border-forja-border py-3 lg:border-b-0 lg:border-r lg:pr-5">
              <NavGroup
                label="Profile"
                hint="Addons, packs on the profile, Features — the app downloads packs"
              >
                {profileCategories.map((category) => (
                  <NavLink
                    key={category.href}
                    {...category}
                    selected={isProfileNavSelected(category.href, pathname)}
                  />
                ))}
              </NavGroup>
              <NavGroup
                label="Account"
                hint="Signed-in email and delete"
              >
                {accountCategories.map((category) => (
                  <NavLink
                    key={category.href}
                    {...category}
                    selected={pathname === category.href}
                  />
                ))}
                <button
                  type="button"
                  onClick={() => void onSignOut()}
                  className="relative flex min-h-16 w-full items-center gap-4 border-l-[3px] border-transparent px-3 py-3 text-left text-red-400 hover:bg-red-500/10 hover:text-red-300"
                >
                  <LogOut className="size-5.5 shrink-0" />
                  <span className="min-w-0">
                    <span className="block text-sm font-medium">Log out</span>
                    <span className="mt-0.5 block truncate text-xs text-red-400/70">
                      Sign out of this browser
                    </span>
                  </span>
                </button>
              </NavGroup>
            </aside>

            <section className="pt-7 lg:px-10 lg:pt-3">
              {title ? (
                <h2 className="font-display text-3xl tracking-tight">{title}</h2>
              ) : null}
              {description ? (
                <p
                  className={cn(
                    'text-sm leading-6 text-forja-muted',
                    title ? 'mt-2' : null,
                    wide ? 'max-w-3xl' : 'max-w-2xl',
                  )}
                >
                  {description}
                </p>
              ) : null}
              <div
                className={cn(
                  title || description ? 'mt-9' : null,
                  wide ? 'max-w-4xl' : 'max-w-2xl',
                )}
              >
                {profilesLoading || !activeProfile ? (
                  <p className="text-sm text-forja-muted">Loading profile…</p>
                ) : (
                  children
                )}
              </div>
              {footer && activeProfile && !profilesLoading ? (
                <div
                  className={cn(
                    'sticky bottom-0 mt-8 bg-forja-bg/95 py-4 backdrop-blur',
                    wide ? 'max-w-4xl' : 'max-w-2xl',
                  )}
                >
                  {footer}
                </div>
              ) : null}
            </section>
          </div>
        </main>
      </div>
    </RequireAuth>
  )
}
