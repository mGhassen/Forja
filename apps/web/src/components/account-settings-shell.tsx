import type { ReactNode } from 'react'
import { Link, useRouterState } from '@tanstack/react-router'
import {
  ArrowLeft,
  Check,
  ChevronDown,
  ListOrdered,
  PlayCircle,
  Puzzle,
  Radio,
} from 'lucide-react'
import { SiteHeader } from '@/components/site-header'
import { RequireAuth } from '@/components/require-auth'
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

const categories = [
  {
    href: '/account/settings/iptv',
    title: 'IPTV portals',
    subtitle: 'Xtream and M3U lists',
    icon: Radio,
  },
  {
    href: '/account/settings/playback',
    title: 'Playback',
    subtitle: 'Sources, quality, auto-play',
    icon: PlayCircle,
  },
  {
    href: '/account/settings/providers',
    title: 'Provider order',
    subtitle: 'Film, anime, and Asian drama',
    icon: ListOrdered,
  },
  {
    href: '/account/settings/stremio',
    title: 'Stremio addons',
    subtitle: 'Synced manifest URLs',
    icon: Puzzle,
  },
] as const

type AccountSettingsShellProps = {
  title: string
  description: string
  backTo?: string
  backLabel?: string
  children: ReactNode
  footer?: ReactNode
}

export function AccountSettingsShell({
  title,
  description,
  backTo = '/account/settings',
  backLabel = '← All settings',
  children,
  footer,
}: AccountSettingsShellProps) {
  const pathname = useRouterState({ select: (state) => state.location.pathname })
  const { profiles, activeProfile, selectProfile, loading: profilesLoading } =
    useProfiles()

  return (
    <RequireAuth>
      <div className="min-h-screen">
        <SiteHeader solid />
        <main className="mx-auto max-w-6xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28">
          <div className="mb-7 flex flex-wrap items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <Link
                to={backTo}
                className="flex size-9 items-center justify-center text-forja-muted hover:text-forja-text"
                aria-label={backLabel.replace('← ', '')}
              >
                <ArrowLeft className="size-5" />
              </Link>
              <h1 className="font-display text-2xl tracking-tight">Settings</h1>
            </div>
            <div className="flex items-center gap-2">
              <DropdownMenu>
                <DropdownMenuTrigger
                  aria-label="Active profile"
                  disabled={profilesLoading || profiles.length === 0}
                  className="inline-flex items-center gap-2 rounded-md border border-forja-border bg-forja-elevated px-2.5 py-1.5 text-sm font-semibold outline-none transition hover:border-forja-green/40 focus-visible:ring-2 focus-visible:ring-forja-green/60 disabled:opacity-50"
                >
                  {activeProfile ? (
                    <ProfileAvatar
                      avatarKey={activeProfile.avatar_key}
                      name={activeProfile.name}
                      className="size-7"
                    />
                  ) : null}
                  <span className="max-w-36 truncate">
                    {activeProfile?.name ?? 'Profile'}
                  </span>
                  <ChevronDown className="size-4 text-forja-muted" />
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="w-56">
                  <DropdownMenuLabel>Switch profile</DropdownMenuLabel>
                  <DropdownMenuSeparator />
                  {profiles.map((profile) => {
                    const selected = profile.id === activeProfile?.id
                    return (
                      <DropdownMenuItem
                        key={profile.id}
                        onSelect={() => selectProfile(profile.id)}
                        className="gap-3 py-2"
                      >
                        <ProfileAvatar
                          avatarKey={profile.avatar_key}
                          name={profile.name}
                          className="size-8 shrink-0"
                        />
                        <span className="min-w-0 flex-1 truncate font-medium">
                          {profile.name}
                        </span>
                        {selected ? (
                          <Check className="size-4 shrink-0 text-forja-green" />
                        ) : null}
                      </DropdownMenuItem>
                    )
                  })}
                  <DropdownMenuSeparator />
                  <DropdownMenuItem asChild>
                    <Link to="/account/profiles" className="cursor-pointer">
                      Manage profiles
                    </Link>
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          </div>

          <div className="grid min-h-[620px] lg:grid-cols-[310px_1fr]">
            <aside className="border-b border-forja-border py-3 lg:border-b-0 lg:border-r lg:pr-5">
              <nav className="grid gap-0 sm:grid-cols-2 lg:grid-cols-1">
                {categories.map((category) => {
                  const selected = pathname === category.href
                  const Icon = category.icon
                  return (
                    <Link
                      key={category.href}
                      to={category.href}
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
                          {category.title}
                        </span>
                        <span className="mt-0.5 block truncate text-xs text-forja-muted">
                          {category.subtitle}
                        </span>
                      </span>
                    </Link>
                  )
                })}
              </nav>
            </aside>

            <section className="pt-7 lg:px-10 lg:pt-3">
              <h2 className="font-display text-3xl tracking-tight">{title}</h2>
              <p className="mt-2 max-w-2xl text-sm leading-6 text-forja-muted">{description}</p>
              <div className="mt-9 max-w-2xl">{children}</div>
              {footer ? (
                <div className="sticky bottom-0 mt-8 max-w-2xl bg-forja-bg/95 py-4 backdrop-blur">
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
