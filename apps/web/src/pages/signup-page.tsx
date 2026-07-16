import { Link } from '@tanstack/react-router'
import { SiteFooter } from '@/components/legal-shell'
import { SiteHeader } from '@/components/site-header'

export function SignupPage() {
  return (
    <div className="min-h-screen bg-[#0B0A0A] text-[#EDE6DA]">
      <SiteHeader solid />
      <main className="mx-auto flex max-w-lg flex-col px-5 pb-16 pt-24 sm:px-6 sm:pt-28">
        <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
          In progress
        </p>
        <h1 className="mt-4 font-disp text-[clamp(36px,8vw,56px)] uppercase leading-[0.92] tracking-[-0.03em]">
          Account
          <br />
          <span className="font-serif-i normal-case text-flame">coming soon.</span>
        </h1>
        <p className="mt-6 text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-lg">
          Sign-up on the web is not ready yet. Download Forja and use the player without
          an account — web login will land soon.
        </p>
        <div className="mt-10 flex flex-wrap gap-4">
          <Link
            to="/download"
            data-hover=""
            className="btn-magnet inline-flex items-center rounded-full px-8 py-3.5 font-mono-ui text-xs font-bold uppercase tracking-[0.1em]"
          >
            Download Forja
          </Link>
          <Link
            to="/"
            className="font-mono-ui inline-flex items-center px-2 py-3.5 text-[11px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.45)] transition-colors hover:text-[#EDE6DA]"
          >
            Home
          </Link>
        </div>
      </main>
      <SiteFooter />
    </div>
  )
}
