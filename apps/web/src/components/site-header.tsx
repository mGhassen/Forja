import { useEffect, useState } from 'react'
import { Link, useRouterState } from '@tanstack/react-router'
import { BrandLogo } from '@/components/brand-logo'
import { useAuth } from '@/hooks/use-auth'
import { cn } from '@/lib/utils'

const LINKS = [
  { to: '/' as const, label: 'Home', exact: true },
  { to: '/iptv' as const, label: 'IPTV' },
]

function NavLink({
  to,
  children,
  exact = false,
  onNavigate,
  className,
  variant = 'desktop',
}: {
  to: '/' | '/iptv' | '/download' | '/account' | '/login'
  children: string
  exact?: boolean
  onNavigate?: () => void
  className?: string
  variant?: 'desktop' | 'mobile'
}) {
  const pathname = useRouterState({ select: (s) => s.location.pathname })
  const isActive = exact ? pathname === to : pathname === to || pathname.startsWith(`${to}/`)
  const mobile = variant === 'mobile'

  return (
    <Link
      to={to}
      activeOptions={{ exact }}
      onClick={onNavigate}
      data-hover=""
      className={cn(
        'group relative inline-flex items-center font-disp font-bold uppercase transition-all duration-200 ease-out will-change-transform',
        mobile
          ? cn(
              'min-w-0 justify-start rounded-none border-0 bg-transparent px-0 py-3 text-[clamp(2.4rem,12vw,3.75rem)] leading-[0.95] tracking-[-0.04em] shadow-none',
              'hover:translate-y-0 hover:border-0 hover:bg-transparent hover:shadow-none',
              isActive
                ? 'text-[#1ce783]'
                : 'text-[rgba(237,230,218,0.4)] hover:text-[#1ce783]',
            )
          : cn(
              'min-w-[6.5rem] justify-center rounded-xl border border-transparent px-5 py-2.5 text-base tracking-tight',
              'hover:-translate-y-0.5 hover:border-[rgba(28,231,131,0.4)] hover:bg-[rgba(28,231,131,0.16)] hover:text-[#1ce783] hover:shadow-[0_10px_28px_-12px_rgba(28,231,131,0.55)]',
              'active:translate-y-0 active:scale-[0.98]',
              isActive
                ? 'border-[#1ce783] bg-[#1ce783] text-[#0B0A0A] shadow-[0_0_22px_rgba(28,231,131,0.4)] hover:border-[#15b86a] hover:bg-[#15b86a] hover:text-[#0B0A0A]'
                : 'text-[rgba(237,230,218,0.72)]',
            ),
        className,
      )}
    >
      <span className="relative z-[1]">{children}</span>
      {!mobile && !isActive ? (
        <span
          aria-hidden
          className="pointer-events-none absolute bottom-1.5 left-1/2 h-0.5 w-0 -translate-x-1/2 rounded-full bg-[#1ce783] transition-all duration-200 ease-out group-hover:w-6"
        />
      ) : null}
    </Link>
  )
}

export function SiteHeader({ solid = false }: { solid?: boolean }) {
  const { user, loading } = useAuth()
  const [open, setOpen] = useState(false)
  const pathname = useRouterState({ select: (s) => s.location.pathname })

  useEffect(() => {
    setOpen(false)
  }, [pathname])

  useEffect(() => {
    if (!open) return
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }
    window.addEventListener('keydown', onKey)
    return () => {
      document.body.style.overflow = prev
      window.removeEventListener('keydown', onKey)
    }
  }, [open])

  const close = () => setOpen(false)

  return (
    <header className="fixed inset-x-0 top-0 z-40">
      {/* Soft fade under floating bar — not a full sticky slab */}
      <div
        aria-hidden
        className={cn(
          'pointer-events-none absolute inset-x-0 top-0 h-28 bg-gradient-to-b to-transparent',
          solid ? 'from-[#0B0A0A]/90' : 'from-[#0B0A0A]/70',
        )}
      />

      <div className="relative mx-auto max-w-[1400px] px-[4vw] pt-3 sm:pt-4">
        <div
          className={cn(
            'site-nav-shell flex items-center gap-3 rounded-2xl border px-3 py-2.5 sm:gap-4 sm:px-4 sm:py-3',
            solid
              ? 'border-[rgba(237,230,218,0.16)] bg-[#0B0A0A]/95'
              : 'border-[rgba(237,230,218,0.14)] bg-[#121110]/88',
          )}
        >
          <BrandLogo imgClassName="h-7 w-auto sm:h-8" />

          <span
            aria-hidden
            className="hidden h-6 w-px shrink-0 bg-[rgba(237,230,218,0.14)] md:block"
          />

          <nav
            aria-label="Primary"
            className="hidden flex-1 items-center justify-center gap-3 md:flex lg:gap-4"
          >
            {LINKS.map((link) => (
              <NavLink key={link.to} to={link.to} exact={link.exact}>
                {link.label}
              </NavLink>
            ))}
          </nav>

          <div className="ml-auto hidden items-center gap-2 md:flex">
            {!loading && user ? (
              <Link
                to="/account"
                activeOptions={{ exact: false }}
                className={(state) =>
                  cn('site-nav-ghost', state.isActive && 'is-active')
                }
              >
                Account
              </Link>
            ) : (
              <Link to="/login" className="site-nav-ghost">
                Log in
              </Link>
            )}
            <Link to="/download" className="site-nav-cta">
              Get Forja
            </Link>
          </div>

          <button
            type="button"
            className={cn(
              'ml-auto flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border text-[#EDE6DA] transition-colors md:hidden',
              open
                ? 'border-brand/40 bg-brand/10 text-brand'
                : 'border-[rgba(237,230,218,0.16)] bg-[rgba(237,230,218,0.04)]',
            )}
            aria-expanded={open}
            aria-controls="mobile-nav"
            aria-label={open ? 'Close menu' : 'Open menu'}
            onClick={() => setOpen((v) => !v)}
          >
            <span className="sr-only">{open ? 'Close' : 'Menu'}</span>
            <span className="relative block h-3.5 w-5" aria-hidden>
              <span
                className={cn(
                  'absolute left-0 block h-0.5 w-full bg-current transition-transform duration-200',
                  open ? 'top-1.5 rotate-45' : 'top-0',
                )}
              />
              <span
                className={cn(
                  'absolute left-0 top-1.5 block h-0.5 w-full bg-current transition-opacity duration-200',
                  open && 'opacity-0',
                )}
              />
              <span
                className={cn(
                  'absolute left-0 block h-0.5 w-full bg-current transition-transform duration-200',
                  open ? 'top-1.5 -rotate-45' : 'top-3',
                )}
              />
            </span>
          </button>
        </div>
      </div>

      {/* Mobile: full-screen takeover */}
      <div
        id="mobile-nav"
        className={cn(
          'fixed inset-0 z-50 flex flex-col bg-[#0B0A0A] transition-[opacity,visibility] duration-200 md:hidden',
          open ? 'visible opacity-100' : 'invisible pointer-events-none opacity-0',
        )}
      >
        <div className="flex items-center justify-between px-[4vw] pt-3 pb-2">
          <BrandLogo imgClassName="h-7 w-auto" />
          <button
            type="button"
            className="flex h-10 w-10 items-center justify-center rounded-xl border border-[rgba(237,230,218,0.16)] text-[#EDE6DA]"
            aria-label="Close menu"
            onClick={close}
          >
            <span aria-hidden className="text-xl leading-none">
              ×
            </span>
          </button>
        </div>

        <nav
          aria-label="Primary"
          className="flex flex-1 flex-col justify-center gap-2 px-[6vw] pb-10"
        >
          <NavLink to="/" exact onNavigate={close} variant="mobile">
            Home
          </NavLink>
          <NavLink to="/iptv" onNavigate={close} variant="mobile">
            IPTV
          </NavLink>
          <NavLink
            to="/download"
            onNavigate={close}
            variant="mobile"
            className="!text-[#ff4d1c] hover:!text-[#ff8a3d]"
          >
            Get Forja
          </NavLink>
          {!loading && user ? (
            <NavLink to="/account" onNavigate={close} variant="mobile">
              Account
            </NavLink>
          ) : (
            <NavLink to="/login" onNavigate={close} variant="mobile">
              Log in
            </NavLink>
          )}
        </nav>

        <p className="px-[6vw] pb-8 font-mono-ui text-[10px] uppercase tracking-[0.18em] text-[rgba(237,230,218,0.35)]">
          Free · No ads · Desk to TV
        </p>
      </div>
    </header>
  )
}
