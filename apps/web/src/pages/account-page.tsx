import { Link, Outlet, useNavigate, useRouterState } from '@tanstack/react-router'
import { LogOut, Settings, UserRound } from 'lucide-react'
import { SiteHeader } from '@/components/site-header'
import { useAuth } from '@/hooks/use-auth'
import { useProfiles } from '@/hooks/use-profiles'
import { RequireAuth } from '@/components/require-auth'
import { ProfileAvatar } from '@/components/profile-avatar'

export function AccountPage() {
  const { user, signOut } = useAuth()
  const { profiles, activeProfile } = useProfiles()
  const navigate = useNavigate()
  const pathname = useRouterState({ select: (state) => state.location.pathname })

  if (pathname !== '/account' && pathname !== '/account/') {
    return <Outlet />
  }

  return (
    <RequireAuth>
      <div className="min-h-screen">
        <SiteHeader solid />
        <main className="mx-auto max-w-4xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28">
          <h1 className="font-display text-3xl tracking-tight sm:text-4xl">Account</h1>
          <div className="mt-8 border-t border-forja-border">
            <div className="flex min-h-20 items-center gap-4 border-b border-forja-border px-0.5 py-4">
              <UserRound className="size-6 text-forja-green" />
              <div>
                <p className="font-semibold">Forja account</p>
                <p className="mt-0.5 text-sm text-forja-muted">{user?.email}</p>
              </div>
            </div>

            <Link
              to="/account/profiles"
              className="flex min-h-20 items-center gap-4 border-b border-forja-border px-0.5 py-4 hover:bg-white/2.5"
            >
              {activeProfile ? (
                <ProfileAvatar
                  avatarKey={activeProfile.avatar_key}
                  name={activeProfile.name}
                  className="size-10 shrink-0"
                />
              ) : null}
              <div className="min-w-0 flex-1">
                <p className="font-semibold">Profiles</p>
                <p className="mt-0.5 text-sm text-forja-muted">
                  {activeProfile?.name ?? 'Loading'} · {profiles.length}{' '}
                  {profiles.length === 1 ? 'profile' : 'profiles'}
                </p>
              </div>
              <span className="text-forja-green">→</span>
            </Link>

            <Link
              to="/account/settings"
              className="flex min-h-20 items-center gap-4 border-b border-forja-border px-0.5 py-4 hover:bg-white/2.5"
            >
              <Settings className="size-6 text-forja-muted" />
              <div className="min-w-0 flex-1">
                <p className="font-semibold">Remote settings</p>
                <p className="mt-0.5 text-sm text-forja-muted">
                  IPTV, playback, providers, and Stremio addons
                </p>
              </div>
              <span className="text-forja-green">→</span>
            </Link>

            <button
              type="button"
              className="flex min-h-20 w-full items-center gap-4 border-b border-forja-border px-0.5 py-4 text-left hover:bg-white/2.5"
              onClick={async () => {
                await signOut()
                void navigate({ to: '/' })
              }}
            >
              <LogOut className="size-6 text-forja-muted" />
              <span className="font-semibold">Log out</span>
            </button>
          </div>
        </main>
      </div>
    </RequireAuth>
  )
}
