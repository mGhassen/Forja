import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { Link, useNavigate, useRouterState } from '@tanstack/react-router'
import { Check, ChevronDown } from 'lucide-react'
import { BrandLogo } from '@/components/brand-logo'
import { LiquidGlass } from '@/components/liquid-glass'
import { ProfileAvatar } from '@/components/profile-avatar'
import { useAuth } from '@/hooks/use-auth'
import { useProfiles } from '@/hooks/use-profiles'
import { cn } from '@/lib/utils'

const LINKS = [
  { to: '/' as const, label: 'Streaming Player', exact: true },
  { to: '/iptv' as const, label: 'Live Player' },
  { to: '/plugins' as const, label: 'Community Packs' },
]

function NavLink({
  to,
  children,
  exact = false,
  onNavigate,
  className,
  variant = 'desktop',
}: {
  to: '/' | '/iptv' | '/plugins' | '/download' | '/account' | '/login' | '/changelog'
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
                ? 'text-forja-green'
                : 'text-[rgba(237,230,218,0.4)] hover:text-forja-green',
            )
          : cn(
              'min-w-[7.5rem] justify-center rounded-xl border border-transparent px-4 py-2.5 text-[13px] tracking-tight sm:min-w-[9.5rem] sm:px-5 sm:text-base',
              'hover:-translate-y-0.5 hover:border-forja-green/40 hover:bg-forja-green/15 hover:text-forja-green hover:shadow-[0_10px_28px_-12px_rgba(28,231,131,0.55)]',
              'active:translate-y-0 active:scale-[0.98]',
              isActive
                ? 'border-forja-green bg-forja-green text-[#0B0A0A] shadow-[0_0_22px_rgba(28,231,131,0.4)] hover:border-forja-green-dim hover:bg-forja-green-dim hover:text-[#0B0A0A]'
                : 'text-[rgba(237,230,218,0.72)]',
            ),
        className,
      )}
    >
      <span className="relative z-1">{children}</span>
      {!mobile && !isActive ? (
        <span
          aria-hidden
          className="pointer-events-none absolute bottom-1.5 left-1/2 h-0.5 w-0 -translate-x-1/2 rounded-full bg-forja-green transition-all duration-200 ease-out group-hover:w-6"
        />
      ) : null}
    </Link>
  )
}

function HeaderAccountMenu({
  accountActive,
  onNavigate,
  variant = 'desktop',
}: {
  accountActive: boolean
  onNavigate?: () => void
  variant?: 'desktop' | 'mobile'
}) {
  const navigate = useNavigate()
  const { user, signOut } = useAuth()
  const { profiles, activeProfile, selectProfile, loading: profilesLoading } =
    useProfiles()
  const accountLabel = user?.email?.trim() || null
  const profileLabel = activeProfile?.name?.trim() || 'Profile'
  const triggerRef = useRef<HTMLDivElement>(null)
  const closeTimer = useRef<number | null>(null)
  const [menuOpen, setMenuOpen] = useState(false)
  const [menuPos, setMenuPos] = useState({ top: 0, right: 0 })

  async function onSignOut() {
    onNavigate?.()
    setMenuOpen(false)
    await signOut({ scope: 'local' })
    void navigate({ to: '/' })
  }

  const clearCloseTimer = () => {
    if (closeTimer.current != null) {
      window.clearTimeout(closeTimer.current)
      closeTimer.current = null
    }
  }

  const updateMenuPos = () => {
    const el = triggerRef.current
    if (!el) return
    const rect = el.getBoundingClientRect()
    setMenuPos({
      top: rect.bottom + 10,
      right: Math.max(8, window.innerWidth - rect.right),
    })
  }

  const openMenu = () => {
    clearCloseTimer()
    updateMenuPos()
    setMenuOpen(true)
  }

  const scheduleClose = () => {
    clearCloseTimer()
    closeTimer.current = window.setTimeout(() => setMenuOpen(false), 120)
  }

  useEffect(() => {
    if (!menuOpen) return
    const onReposition = () => updateMenuPos()
    window.addEventListener('resize', onReposition)
    window.addEventListener('scroll', onReposition, true)
    return () => {
      window.removeEventListener('resize', onReposition)
      window.removeEventListener('scroll', onReposition, true)
    }
  }, [menuOpen])

  useEffect(() => () => clearCloseTimer(), [])

  if (variant === 'mobile') {
    return (
      <div className="mt-4 flex flex-col gap-3 border-t border-white/10 pt-6">
        <Link
          to="/account/settings"
          onClick={onNavigate}
          className="flex min-w-0 items-center gap-3"
        >
          {activeProfile ? (
            <ProfileAvatar
              avatarKey={activeProfile.avatar_key}
              name={activeProfile.name}
              className="size-14 shrink-0 rounded-[14px] ring-1 ring-white/10"
            />
          ) : (
            <span className="size-14 shrink-0 rounded-[14px] bg-forja-elevated" />
          )}
          <span className="min-w-0 flex-1">
            <span className="block font-mono text-[10px] font-bold uppercase tracking-[0.16em] text-forja-muted">
              Watching as
            </span>
            <span className="mt-0.5 block truncate font-disp text-2xl font-bold uppercase tracking-tight text-[#EDE6DA]">
              {profileLabel}
            </span>
            {accountLabel ? (
              <span className="mt-1 block truncate font-mono text-[12px] font-medium normal-case tracking-normal text-[rgba(237,230,218,0.72)]">
                {accountLabel}
              </span>
            ) : null}
          </span>
        </Link>
        <div className="flex flex-col gap-1 pt-2">
          {profiles.map((profile) => {
            const selected = profile.id === activeProfile?.id
            return (
              <button
                key={profile.id}
                type="button"
                onClick={() => {
                  selectProfile(profile.id)
                  onNavigate?.()
                }}
                className={cn(
                  'flex items-center gap-3 rounded-xl px-1 py-2 text-left transition-colors',
                  selected ? 'text-[#EDE6DA]' : 'text-[rgba(237,230,218,0.55)]',
                )}
              >
                <ProfileAvatar
                  avatarKey={profile.avatar_key}
                  name={profile.name}
                  className="size-10 shrink-0 rounded-lg ring-1 ring-white/10"
                />
                <span className="min-w-0 flex-1 truncate font-disp text-lg uppercase tracking-tight">
                  {profile.name}
                </span>
                {selected ? (
                  <Check className="size-5 shrink-0 text-forja-green" />
                ) : null}
              </button>
            )
          })}
        </div>
        <Link
          to="/account/profiles"
          onClick={onNavigate}
          className="pt-1 text-sm font-medium text-[rgba(237,230,218,0.78)] transition-colors hover:text-forja-green"
        >
          Manage profiles
        </Link>
          <Link
            to="/account/settings/account"
            onClick={onNavigate}
            className="text-sm font-medium text-[rgba(237,230,218,0.78)] transition-colors hover:text-forja-green"
          >
            Account settings
          </Link>
          <Link
            to="/download"
            onClick={onNavigate}
            className="text-sm font-medium text-forja-green transition-colors hover:text-forja-green-dim"
          >
            Get Forja
          </Link>
          <button
            type="button"
            onClick={() => void onSignOut()}
            className="self-start text-sm font-medium text-red-400 transition-colors hover:text-red-300"
          >
            Log out
          </button>
      </div>
    )
  }

  const menu = menuOpen
    ? createPortal(
        <div
          role="menu"
          onMouseEnter={openMenu}
          onMouseLeave={scheduleClose}
          style={{ top: menuPos.top, right: menuPos.right }}
          className="fixed z-100 w-76 rounded-2xl border border-forja-border bg-[#121110] p-2 shadow-[0_28px_80px_-28px_rgba(0,0,0,0.9)]"
        >
          <p className="px-3 pb-1 pt-2 font-mono text-[10px] font-bold uppercase tracking-[0.16em] text-forja-muted">
            Switch profile
          </p>
          {accountLabel ? (
            <p className="truncate px-3 pb-2 font-mono text-[12px] font-medium normal-case tracking-normal text-[rgba(237,230,218,0.72)]">
              {accountLabel}
            </p>
          ) : null}
          <div className="mx-1 my-1 h-px bg-[rgba(237,230,218,0.1)]" />
          <div className="max-h-88 space-y-1 overflow-y-auto py-1">
            {profiles.length === 0 ? (
              <p className="px-3 py-2 text-sm text-forja-muted">No profiles yet</p>
            ) : (
              profiles.map((profile) => {
                const selected = profile.id === activeProfile?.id
                return (
                  <button
                    key={profile.id}
                    type="button"
                    role="menuitem"
                    onClick={() => {
                      selectProfile(profile.id)
                      setMenuOpen(false)
                    }}
                    className={cn(
                      'flex w-full cursor-pointer items-center gap-3 rounded-xl px-2.5 py-2.5 text-left transition-colors',
                      selected
                        ? 'bg-forja-green/10 text-[#EDE6DA]'
                        : 'text-[rgba(237,230,218,0.78)] hover:bg-white/6',
                    )}
                  >
                    <ProfileAvatar
                      avatarKey={profile.avatar_key}
                      name={profile.name}
                      className="size-12 shrink-0 rounded-xl ring-1 ring-white/10"
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
                  </button>
                )
              })
            )}
          </div>
          <div className="mx-1 my-1 h-px bg-[rgba(237,230,218,0.1)]" />
          <Link
            to="/account/profiles"
            role="menuitem"
            onClick={() => setMenuOpen(false)}
            className="block rounded-xl px-3 py-2.5 text-sm font-medium text-[#EDE6DA] transition-colors hover:bg-white/6"
          >
            Manage profiles
          </Link>
          <Link
            to="/account/settings/account"
            role="menuitem"
            onClick={() => setMenuOpen(false)}
            className="block rounded-xl px-3 py-2.5 text-sm font-medium text-[#EDE6DA] transition-colors hover:bg-white/6"
          >
            Account settings
          </Link>
          <Link
            to="/download"
            role="menuitem"
            onClick={() => setMenuOpen(false)}
            className="block rounded-xl px-3 py-2.5 text-sm font-medium text-forja-green transition-colors hover:bg-forja-green/10"
          >
            Get Forja
          </Link>
          <button
            type="button"
            role="menuitem"
            onClick={() => void onSignOut()}
            className="block w-full rounded-xl px-3 py-2.5 text-left text-sm font-medium text-red-400 transition-colors hover:bg-red-500/10 hover:text-red-300"
          >
            Log out
          </button>
        </div>,
        document.body,
      )
    : null

  return (
    <div
      ref={triggerRef}
      className="relative"
      onMouseEnter={openMenu}
      onMouseLeave={scheduleClose}
    >
      <Link
        to="/account/settings"
        data-hover=""
        onFocus={openMenu}
        aria-label="Active profile"
        aria-expanded={menuOpen}
        className={cn(
          'group inline-flex min-w-52 max-w-64 items-center gap-2.5 rounded-2xl border bg-[#121110] py-1.5 pl-1.5 pr-2.5 text-left outline-none transition duration-200',
          'border-[rgba(237,230,218,0.16)] hover:border-forja-green/45 hover:bg-[#161412]',
          (menuOpen || accountActive) &&
            'border-forja-green/50 bg-[#161412]',
          profilesLoading && 'opacity-50',
        )}
      >
        {activeProfile ? (
          <ProfileAvatar
            avatarKey={activeProfile.avatar_key}
            name={activeProfile.name}
            className="size-10 shrink-0 rounded-[12px] shadow-[0_10px_28px_-16px_rgba(0,0,0,0.9)] ring-1 ring-white/10 transition duration-200 group-hover:scale-[1.03]"
          />
        ) : (
          <span className="size-10 shrink-0 rounded-[12px] bg-forja-elevated" />
        )}
        <span className="min-w-0 flex-1">
          <span className="block font-mono text-[9px] font-bold uppercase tracking-[0.16em] text-forja-muted">
            Watching as
          </span>
          <span className="mt-0.5 block truncate font-disp text-[15px] font-bold uppercase tracking-tight text-[#EDE6DA]">
            {profileLabel}
          </span>
        </span>
        <ChevronDown
          className={cn(
            'size-4 shrink-0 text-forja-muted transition',
            menuOpen && 'rotate-180',
          )}
        />
      </Link>
      {menu}
    </div>
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
  const accountActive = pathname.startsWith('/account')
  return (
    <header className="fixed inset-x-0 top-0 z-40">
      <div
        aria-hidden
        className={cn(
          'pointer-events-none absolute inset-x-0 top-0 h-28 bg-linear-to-b to-transparent',
          solid ? 'from-forja-bg/90' : 'from-forja-bg/70',
        )}
      />

      <div className="relative mx-auto max-w-[1400px] px-[4vw] pt-3 sm:pt-4">
        <LiquidGlass
          solid={solid}
          className="backdrop-blur-md backdrop-saturate-125 shadow-[0_16px_48px_-20px_rgba(0,0,0,0.65)]"
        >
          <div className="flex items-center gap-3 px-3 py-2.5 sm:gap-4 sm:px-4 sm:py-3">
            <BrandLogo imgClassName="h-7 w-auto sm:h-8" />

            <span
              aria-hidden
              className="hidden h-6 w-px shrink-0 bg-white/15 md:block"
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
                <HeaderAccountMenu accountActive={accountActive} />
              ) : (
                <>
                  <Link
                    to="/login"
                    data-hover=""
                    className="inline-flex items-center justify-center rounded-xl px-3.5 py-2.5 font-mono text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.55)] transition-all duration-200 hover:bg-forja-green/12 hover:text-forja-green"
                  >
                    Log in
                  </Link>
                  <Link
                    to="/download"
                    data-hover=""
                    className="inline-flex items-center justify-center rounded-full bg-forja-green px-5 py-2.5 font-mono text-[11px] font-bold uppercase tracking-[0.1em] text-[#0B0A0A] shadow-[0_0_24px_rgba(28,231,131,0.28)] transition-all duration-200 hover:-translate-y-0.5 hover:bg-forja-flame hover:shadow-[0_0_28px_rgba(255,77,28,0.35)]"
                  >
                    Get Forja
                  </Link>
                </>
              )}
            </div>

            <button
              type="button"
              className={cn(
                'ml-auto flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border text-[#EDE6DA] transition-colors md:hidden',
                open
                  ? 'border-forja-green/40 bg-forja-green/10 text-forja-green'
                  : 'border-white/15 bg-white/5',
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
        </LiquidGlass>
      </div>

      <div
        id="mobile-nav"
        className={cn(
          'fixed inset-0 z-50 flex flex-col bg-forja-bg transition-[opacity,visibility] duration-200 md:hidden',
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
          className="flex flex-1 flex-col justify-center gap-2 overflow-y-auto px-[6vw] pb-10"
        >
          {LINKS.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              exact={link.exact}
              onNavigate={close}
              variant="mobile"
            >
              {link.label}
            </NavLink>
          ))}
          {!loading && user ? (
            <HeaderAccountMenu
              accountActive={accountActive}
              onNavigate={close}
              variant="mobile"
            />
          ) : (
            <>
              <NavLink
                to="/download"
                onNavigate={close}
                variant="mobile"
                className="text-forja-flame hover:text-forja-flame-dim"
              >
                Get Forja
              </NavLink>
              <NavLink to="/login" onNavigate={close} variant="mobile">
                Log in
              </NavLink>
            </>
          )}
        </nav>

        <p className="px-[6vw] pb-8 font-mono text-[10px] uppercase tracking-[0.18em] text-[rgba(237,230,218,0.35)]">
          Free download
        </p>
      </div>
    </header>
  )
}
