import { Link, NavLink } from 'react-router-dom'
import { supabase } from '@/lib/supabase'

const linkClass = ({ isActive }: { isActive: boolean }) =>
  `rounded px-3 py-1.5 text-sm ${
    isActive ? 'bg-zinc-800 text-white' : 'text-zinc-400 hover:text-zinc-200'
  }`

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen">
      <header className="flex items-center gap-4 border-b border-zinc-800 px-4 py-3">
        <Link to="/" className="font-semibold tracking-tight">
          Forja Admin
        </Link>
        <nav className="flex flex-1 gap-1">
          <NavLink to="/" end className={linkClass}>
            Dashboard
          </NavLink>
          <NavLink to="/accounts" className={linkClass}>
            Accounts
          </NavLink>
          <NavLink to="/pool" className={linkClass}>
            Pool
          </NavLink>
          <NavLink to="/scrape" className={linkClass}>
            Scrape
          </NavLink>
        </nav>
        <button
          type="button"
          className="text-sm text-zinc-400 hover:text-zinc-200"
          onClick={() => void supabase.auth.signOut()}
        >
          Sign out
        </button>
      </header>
      <main className="mx-auto max-w-6xl p-4">{children}</main>
    </div>
  )
}
