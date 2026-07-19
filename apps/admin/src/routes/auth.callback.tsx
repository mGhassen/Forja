import { createFileRoute } from '@tanstack/react-router'
import { BrandLogo } from '@/components/brand-logo'
import { AuthCallbackPage } from '@/pages/auth-callback-page'

function AuthCallbackRoute() {
  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-forja-text">
      <div className="relative z-10 mx-auto flex min-h-screen max-w-md flex-col justify-center px-4 py-12">
        <BrandLogo to={null} imgClassName="h-8" className="mb-8" />
        <AuthCallbackPage />
      </div>
    </div>
  )
}

export const Route = createFileRoute('/auth/callback')({
  component: AuthCallbackRoute,
})
