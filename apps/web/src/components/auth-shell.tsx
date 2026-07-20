import { Outlet, useRouterState } from '@tanstack/react-router'
import { AuthStoryPanel } from '@/components/auth-story-panel'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'
import {
  isSafeDesktopCallback,
  resolveDesktopAuthParams,
} from '@/lib/desktop-auth-callback'

function emphasisForPath(pathname: string): string | undefined {
  if (pathname.startsWith('/signup')) {
    return 'Create an account to sync settings across your screens.'
  }
  if (pathname.startsWith('/forgot-password')) {
    return 'Reset your password to get back to synced settings.'
  }
  if (pathname.startsWith('/reset-password')) {
    return 'Almost there — set a new password and you’re back in.'
  }
  if (pathname.startsWith('/login')) {
    return isSafeDesktopCallback(resolveDesktopAuthParams().callback)
      ? 'Sign in here to unlock sync on your desktop Forja app.'
      : undefined
  }
  return undefined
}

/** Shared chrome for auth routes — left story panel stays mounted across navigations. */
export function AuthShell() {
  const pathname = useRouterState({ select: (s) => s.location.pathname })
  const emphasis = emphasisForPath(pathname)

  return (
    <div className="film-grain relative flex min-h-screen flex-col bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="auth" />
      <div className="relative z-10 flex min-h-screen flex-col">
        <SiteHeader />
        {/*
          minmax(0,…) keeps the marquee/w-max story panel from blowing the
          left column wider than its track. flex-1 fills viewport under header
          instead of stacking another full min-h-screen.
        */}
        <main className="relative grid min-h-0 flex-1 lg:grid-cols-[minmax(0,1.05fr)_minmax(0,0.95fr)]">
          <div className="min-h-0 min-w-0 overflow-hidden">
            <AuthStoryPanel emphasis={emphasis} />
          </div>
          <div className="min-h-0 min-w-0">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  )
}
