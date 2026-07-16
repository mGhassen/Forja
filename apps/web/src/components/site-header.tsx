import { useEffect, useState } from 'react'
import { Link, useRouterState } from '@tanstack/react-router'
import { BrandLogo } from '@/components/brand-logo'
import { useAuth } from '@/hooks/use-auth'
import { cn } from '@/lib/utils'

const idleLink =
  'text-[15px] font-medium tracking-wide text-[#EDE6DA]/85 transition-[color,font-weight] hover:font-bold hover:text-forja-green sm:text-base'
const activeLink =
  'text-[15px] font-bold tracking-wide text-forja-green transition-colors sm:text-base'

function NavLink({
  to,
  children,
  exact = false,
  onNavigate,
  className,
}: {
  to: '/' | '/iptv' | '/download' | '/account' | '/login'
  children: string
  exact?: boolean
  onNavigate?: () => void
  className?: string
}) {
  return (
    <Link
      to={to}
      activeOptions={{ exact }}
      onClick={onNavigate}
      className={(state) =>
        cn(state.isActive ? activeLink : idleLink, className)
      }
    >
      {children}
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
    <header
      className={cn(
        'fixed inset-x-0 top-0 z-40 border-b border-[rgba(237,230,218,0.1)]',
        solid
          ? 'bg-[#0B0A0A]/95 backdrop-blur-md'
          : 'bg-[#0B0A0A]/88 backdrop-blur-md',
      )}
    >
      <div className="mx-auto flex h-16 max-w-[1400px] items-center justify-between gap-4 px-[5vw] sm:h-[5.5rem]">
        <BrandLogo imgClassName="h-8 w-auto sm:h-12" />

        {/* Desktop */}
        <nav className="hidden items-center gap-x-8 md:flex">
          <NavLink to="/" exact>
            Home
          </NavLink>
          <NavLink to="/iptv">IPTV Player</NavLink>
          <NavLink to="/download">Downloads</NavLink>
          {!loading && user ? (
            <Link
              to="/account"
              activeOptions={{ exact: false }}
              className={(state) =>
                cn(
                  'rounded-full px-4 py-2 text-[15px] transition-colors sm:text-base',
                  state.isActive
                    ? 'bg-forja-green font-bold text-[#0B0A0A]'
                    : 'bg-forja-green/15 font-semibold text-forja-green hover:bg-forja-green/25',
                )
              }
            >
              Account
            </Link>
          ) : (
            <Link
              to="/login"
              className={(state) =>
                cn(
                  'rounded-full border px-4 py-2 text-[15px] transition-colors sm:text-base',
                  state.isActive
                    ? 'border-forja-green bg-forja-green/15 font-bold text-forja-green'
                    : 'border-[rgba(237,230,218,0.25)] font-semibold text-[#EDE6DA] hover:border-forja-green hover:font-bold hover:text-forja-green',
                )
              }
            >
              Log in
            </Link>
          )}
        </nav>

        {/* Mobile toggle */}
        <button
          type="button"
          className="relative z-50 flex h-11 w-11 items-center justify-center rounded-full border border-[rgba(237,230,218,0.2)] text-[#EDE6DA] md:hidden"
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

      {/* Mobile panel */}
      <div
        id="mobile-nav"
        className={cn(
          'fixed inset-x-0 top-16 z-40 border-b border-[rgba(237,230,218,0.12)] bg-[#0B0A0A]/98 backdrop-blur-lg transition-[opacity,visibility] duration-200 md:hidden',
          open
            ? 'visible opacity-100'
            : 'invisible pointer-events-none opacity-0',
        )}
      >
        <nav className="flex max-h-[calc(100dvh-4rem)] flex-col gap-1 overflow-y-auto px-[5vw] py-4">
          <NavLink
            to="/"
            exact
            onNavigate={close}
            className="rounded-lg px-3 py-3.5 text-lg"
          >
            Home
          </NavLink>
          <NavLink
            to="/iptv"
            onNavigate={close}
            className="rounded-lg px-3 py-3.5 text-lg"
          >
            IPTV Player
          </NavLink>
          <NavLink
            to="/download"
            onNavigate={close}
            className="rounded-lg px-3 py-3.5 text-lg"
          >
            Downloads
          </NavLink>
          {!loading && user ? (
            <Link
              to="/account"
              onClick={close}
              className="mt-2 rounded-full bg-forja-green px-4 py-3.5 text-center text-base font-bold text-[#0B0A0A]"
            >
              Account
            </Link>
          ) : (
            <Link
              to="/login"
              onClick={close}
              className="mt-2 rounded-full border border-forja-green/50 px-4 py-3.5 text-center text-base font-semibold text-forja-green"
            >
              Log in
            </Link>
          )}
        </nav>
      </div>

      {open ? (
        <button
          type="button"
          aria-label="Dismiss menu"
          className="fixed inset-0 top-16 z-30 bg-black/55 md:hidden"
          onClick={close}
        />
      ) : null}
    </header>
  )
}
