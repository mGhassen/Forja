import { Link } from '@tanstack/react-router'
import { BrandLogo } from '@/components/brand-logo'
import { useAuth } from '@/hooks/use-auth'
import { cn } from '@/lib/utils'

const idleLink =
  'text-[15px] font-medium tracking-wide text-[#EDE6DA]/85 transition-colors hover:text-brand sm:text-base'
const activeLink =
  'text-[15px] font-bold tracking-wide text-brand transition-colors sm:text-base'

function NavLink({
  to,
  children,
  exact = false,
}: {
  to: '/' | '/iptv' | '/download' | '/account' | '/login'
  children: string
  exact?: boolean
}) {
  return (
    <Link
      to={to}
      activeOptions={{ exact }}
      className={(state) => cn(state.isActive ? activeLink : idleLink)}
    >
      {children}
    </Link>
  )
}

export function SiteHeader({ solid = false }: { solid?: boolean }) {
  const { user, loading } = useAuth()

  return (
    <header
      className={cn(
        'fixed inset-x-0 top-0 z-40 border-b border-[rgba(237,230,218,0.1)]',
        solid
          ? 'bg-[#0B0A0A]/95 backdrop-blur-md'
          : 'bg-[#0B0A0A]/88 backdrop-blur-md',
      )}
    >
      <div className="mx-auto flex h-20 max-w-[1400px] items-center justify-between gap-6 px-[5vw] sm:h-[5.5rem]">
        <BrandLogo imgClassName="h-10 w-auto sm:h-12" />
        <nav className="flex flex-wrap items-center justify-end gap-x-5 gap-y-2 sm:gap-x-8">
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
                    ? 'bg-brand font-bold text-[#0B0A0A]'
                    : 'bg-brand/15 font-semibold text-brand hover:bg-brand/25',
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
                    ? 'border-brand bg-brand/15 font-bold text-brand'
                    : 'border-[rgba(237,230,218,0.25)] font-semibold text-[#EDE6DA] hover:border-brand/50 hover:text-brand',
                )
              }
            >
              Log in
            </Link>
          )}
        </nav>
      </div>
    </header>
  )
}
