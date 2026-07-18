import type { ReactNode } from 'react'
import { Link, useNavigate, useRouterState } from '@tanstack/react-router'
import {
  ArrowLeft,
  Check,
  ChevronDown,
  LayoutList,
  LogOut,
  PlayCircle,
  Puzzle,
  Radio,
  UserRound,
} from 'lucide-react'
import { SiteHeader } from '@/components/site-header'
import { RequireAuth } from '@/components/require-auth'
import { useAuth } from '@/hooks/use-auth'
import { useProfiles } from '@/hooks/use-profiles'
import { ProfileAvatar } from '@/components/profile-avatar'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { cn } from '@/lib/utils'

const profileCategories = [
  {
    href: '/account/settings/iptv',
    title: 'IPTV',
    subtitle: 'Xtream portals',
    icon: Radio,
  },
  {
    href: '/account/settings/playback',
    title: 'Playback',
    subtitle: 'Sources, quality, auto-play',
    icon: PlayCircle,
  },
  {
    href: '/account/settings/navigation',
    title: 'Features',
    subtitle: 'Tabs and default menu',
    icon: LayoutList,
  },
  {
    href: '/account/settings/stremio',
    title: 'Stremio addons',
    subtitle: 'Synced manifest URLs',
    icon: Puzzle,
  },
] as const

const accountCategories = [
  {
    href: '/account/settings/account',
    title: 'Account',
    subtitle: 'Email, passkeys, and delete',
    icon: UserRound,
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
  icon: typeof Radio
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
        className={`size-[22px] shrink-0 ${
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
  const { user, signOut } = useAuth()
  const { profiles, activeProfile, selectProfile, loading: profilesLoading } =
    useProfiles()

  async function onSignOut() {
    await signOut()
    void navigate({ to: '/' })
  }

  return (
    <RequireAuth>
      <div className="min-h-screen">
        <SiteHeader solid />
        <main className="mx-auto max-w-6xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28">
          <div className="mb-7 flex flex-wrap items-center justify-between gap-4">
            <div className="flex items-center gap-3">
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
            <div className="flex flex-wrap items-center gap-3">
              <DropdownMenu>
                <DropdownMenuTrigger
                  aria-label="Active profile"
                  disabled={profilesLoading || profiles.length === 0}
                  className="group inline-flex min-w-[15.5rem] items-center gap-3 rounded-2xl border border-[rgba(237,230,218,0.16)] bg-[#121110] py-2 pl-2 pr-3 text-left outline-none transition duration-200 hover:border-forja-green/45 hover:bg-[#161412] focus-visible:ring-2 focus-visible:ring-forja-green/60 disabled:opacity-50 data-[state=open]:border-forja-green/50 data-[state=open]:bg-[#161412]"
                >
                  {activeProfile ? (
                    <ProfileAvatar
                      avatarKey={activeProfile.avatar_key}
                      name={activeProfile.name}
                      className="size-14 shrink-0 rounded-[14px] shadow-[0_10px_28px_-16px_rgba(0,0,0,0.9)] ring-1 ring-white/10 transition duration-200 group-hover:scale-[1.03]"
                    />
                  ) : (
                    <span className="size-14 shrink-0 rounded-[14px] bg-forja-elevated" />
                  )}
                  <span className="min-w-0 flex-1">
                    <span className="font-mono-ui block text-[10px] font-bold uppercase tracking-[0.16em] text-forja-muted">
                      Watching as
                    </span>
                    <span className="mt-0.5 block truncate font-disp text-lg uppercase tracking-tight text-[#EDE6DA]">
                      {activeProfile?.name ?? 'Profile'}
                    </span>
                  </span>
                  <ChevronDown className="size-5 shrink-0 text-forja-muted transition group-data-[state=open]:rotate-180" />
                </DropdownMenuTrigger>
                <DropdownMenuContent
                  align="end"
                  sideOffset={10}
                  className="w-[19rem] rounded-2xl border-[rgba(237,230,218,0.14)] bg-[#121110] p-2 shadow-[0_28px_80px_-28px_rgba(0,0,0,0.9)]"
                >
                  <DropdownMenuLabel className="px-3 pb-1 pt-2 font-mono-ui text-[10px] font-bold uppercase tracking-[0.16em] text-forja-muted">
                    Switch profile
                  </DropdownMenuLabel>
                  {user?.email ? (
                    <p className="truncate px-3 pb-2 text-xs text-forja-muted">
                      {user.email}
                    </p>
                  ) : null}
                  <DropdownMenuSeparator className="mx-1 bg-[rgba(237,230,218,0.1)]" />
                  <div className="max-h-[22rem] space-y-1 overflow-y-auto py-1">
                    {profiles.map((profile) => {
                      const selected = profile.id === activeProfile?.id
                      return (
                        <DropdownMenuItem
                          key={profile.id}
                          onSelect={() => selectProfile(profile.id)}
                          className={cn(
                            'cursor-pointer gap-3 rounded-xl px-2.5 py-2.5',
                            selected
                              ? 'bg-forja-green/10 text-[#EDE6DA] focus:bg-forja-green/14'
                              : 'focus:bg-white/[0.06]',
                          )}
                        >
                          <ProfileAvatar
                            avatarKey={profile.avatar_key}
                            name={profile.name}
                            className="size-12 shrink-0 rounded-[12px] ring-1 ring-white/10"
                          />
                          <span className="min-w-0 flex-1">
                            <span className="block truncate font-disp text-base uppercase tracking-tight">
                              {profile.name}
                            </span>
                            <span className="mt-0.5 block text-[11px] text-forja-muted">
                              {selected ? 'Active now' : 'Tap to switch'}
                            </span>
                          </span>
                          {selected ? (
                            <Check className="size-5 shrink-0 text-forja-green" />
                          ) : null}
                        </DropdownMenuItem>
                      )
                    })}
                  </div>
                  <DropdownMenuSeparator className="mx-1 bg-[rgba(237,230,218,0.1)]" />
                  <DropdownMenuItem asChild>
                    <Link
                      to="/account/profiles"
                      className="cursor-pointer rounded-xl px-3 py-2.5 text-sm font-medium"
                    >
                      Manage profiles
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuItem asChild>
                    <Link
                      to="/account/settings/account"
                      className="cursor-pointer rounded-xl px-3 py-2.5 text-sm font-medium"
                    >
                      Account settings
                    </Link>
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          </div>

          <div className="grid min-h-[620px] lg:grid-cols-[310px_1fr]">
            <aside className="border-b border-forja-border py-3 lg:border-b-0 lg:border-r lg:pr-5">
              <NavGroup
                label="Profile"
                hint="Settings that sync with the active profile only"
              >
                {profileCategories.map((category) => (
                  <NavLink
                    key={category.href}
                    {...category}
                    selected={pathname === category.href}
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
                  <LogOut className="size-[22px] shrink-0" />
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
                {children}
              </div>
              {footer ? (
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
