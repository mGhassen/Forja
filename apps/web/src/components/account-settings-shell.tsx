import type { ReactNode } from 'react'
import { Link } from '@tanstack/react-router'
import { SiteHeader } from '@/components/site-header'
import { Button } from '@/components/ui/button'
import { RequireAuth } from '@/components/require-auth'

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
  return (
    <RequireAuth>
      <div className="min-h-screen">
        <SiteHeader solid />
        <main className="mx-auto max-w-2xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28">
          <Button asChild variant="ghost" size="sm" className="-ml-2 mb-6">
            <Link to={backTo}>{backLabel}</Link>
          </Button>
          <p className="font-display text-sm uppercase tracking-[0.3em] text-forja-green">
            Cloud settings
          </p>
          <h1 className="mt-3 font-display text-3xl tracking-tight sm:text-4xl">{title}</h1>
          <p className="mt-4 text-forja-muted">{description}</p>
          <div className="mt-10 space-y-6">{children}</div>
          {footer ? <div className="mt-8">{footer}</div> : null}
        </main>
      </div>
    </RequireAuth>
  )
}
