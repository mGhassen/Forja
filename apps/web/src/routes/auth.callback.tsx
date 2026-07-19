import { createFileRoute } from '@tanstack/react-router'
import { AuthCallbackPage } from '@/pages/auth-callback-page'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'

function AuthCallbackRoute() {
  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="auth" />
      <div className="relative z-10">
        <SiteHeader />
        <AuthCallbackPage />
      </div>
    </div>
  )
}

export const Route = createFileRoute('/auth/callback')({
  component: AuthCallbackRoute,
})
