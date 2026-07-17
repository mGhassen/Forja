import { Outlet, useRouterState } from '@tanstack/react-router'
import { AuthStoryPanel } from '@/components/auth-story-panel'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'
import {
  isSafeDesktopCallback,
  readDesktopAuthSearchParams,
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
    return isSafeDesktopCallback(readDesktopAuthSearchParams().callback)
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
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="auth" />
      <div className="relative z-10">
        <SiteHeader />
        <main className="relative grid min-h-screen lg:grid-cols-[1.05fr_0.95fr]">
          <AuthStoryPanel emphasis={emphasis} />
          <Outlet />
        </main>
      </div>
    </div>
  )
}
