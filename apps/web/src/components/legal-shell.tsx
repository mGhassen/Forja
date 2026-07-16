import { Link } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { SiteHeader } from '@/components/site-header'
import { BrandLogo } from '@/components/brand-logo'

export function LegalPage({
  eyebrow,
  title,
  children,
}: {
  eyebrow: string
  title: ReactNode
  children: ReactNode
}) {
  return (
    <div className="min-h-screen bg-[#0B0A0A] text-[#EDE6DA]">
      <SiteHeader solid />
      <main className="mx-auto max-w-3xl px-5 pb-20 pt-24 sm:px-6 sm:pt-28">
        <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
          {eyebrow}
        </p>
        <h1 className="mt-4 font-disp text-[clamp(36px,7vw,56px)] uppercase leading-[0.92] tracking-[-0.03em]">
          {title}
        </h1>
        <div className="mt-10 space-y-8 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
          {children}
        </div>
      </main>
      <SiteFooter />
    </div>
  )
}

export function LegalSection({
  title,
  children,
}: {
  title: string
  children: ReactNode
}) {
  return (
    <section className="space-y-3 border-t border-[rgba(237,230,218,0.12)] pt-8">
      <h2 className="font-disp text-xl uppercase tracking-tight text-[#EDE6DA] sm:text-2xl">
        {title}
      </h2>
      <div className="space-y-3">{children}</div>
    </section>
  )
}

export function SiteFooter() {
  const year = new Date().getFullYear()

  return (
    <footer className="relative overflow-hidden border-t border-[rgba(237,230,218,0.12)]">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(ellipse 50% 60% at 0% 100%, rgba(28,231,131,0.1), transparent 55%), radial-gradient(ellipse 40% 50% at 100% 0%, rgba(255,77,28,0.08), transparent 50%)',
        }}
      />

      <div className="relative mx-auto max-w-[1400px] px-[5vw] pt-16 pb-10 sm:pt-20 sm:pb-12">
        <div className="flex flex-col gap-12 lg:flex-row lg:items-end lg:justify-between lg:gap-16">
          <div className="max-w-xl">
            <BrandLogo to="/" imgClassName="h-8 w-auto sm:h-10" />
            <p className="mt-6 font-disp text-[clamp(28px,5vw,48px)] uppercase leading-[0.92] tracking-[-0.03em]">
              A player built
              <br />
              <span className="font-serif-i normal-case text-flame">to stream.</span>
            </p>
            <p className="mt-4 max-w-md text-base leading-relaxed text-[rgba(237,230,218,0.5)]">
              Free media player for streaming playback — on your desk, couch, or big
              screen. Forja does not host media files.
            </p>
            <Link
              to="/download"
              data-hover=""
              className="btn-magnet mt-8 inline-flex items-center justify-center rounded-full px-7 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_28px_rgba(28,231,131,0.28)]"
            >
              Get the app
            </Link>
          </div>

          <div className="grid grid-cols-2 gap-10 sm:gap-16">
            <div>
              <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-brand">
                Explore
              </p>
              <ul className="mt-4 space-y-3 font-mono-ui text-[12px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.55)]">
                <li>
                  <Link to="/" className="transition-colors hover:text-[#EDE6DA]">
                    Streaming Player
                  </Link>
                </li>
                <li>
                  <Link to="/iptv" className="transition-colors hover:text-[#EDE6DA]">
                    Live Player
                  </Link>
                </li>
                <li>
                  <Link
                    to="/download"
                    className="transition-colors hover:text-[#EDE6DA]"
                  >
                    Download
                  </Link>
                </li>
              </ul>
            </div>
            <div>
              <p className="font-mono-ui text-[10px] uppercase tracking-[0.2em] text-flame">
                Legal
              </p>
              <ul className="mt-4 space-y-3 font-mono-ui text-[12px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.55)]">
                <li>
                  <Link to="/terms" className="transition-colors hover:text-[#EDE6DA]">
                    Terms
                  </Link>
                </li>
                <li>
                  <Link to="/dmca" className="transition-colors hover:text-[#EDE6DA]">
                    DMCA
                  </Link>
                </li>
                <li>
                  <Link to="/login" className="transition-colors hover:text-[#EDE6DA]">
                    Log in
                  </Link>
                </li>
              </ul>
            </div>
          </div>
        </div>

        <div className="mt-14 space-y-5 border-t border-[rgba(237,230,218,0.1)] pt-6">
          <p className="max-w-3xl text-sm leading-relaxed text-[rgba(237,230,218,0.48)] sm:text-[15px]">
            Forja does not host, upload, or store media files. It is a player app that
            helps you open streams and playlists you connect — we are not the owners of
            third-party content.{' '}
            <Link
              to="/dmca"
              className="text-[rgba(237,230,218,0.72)] underline decoration-[rgba(237,230,218,0.25)] underline-offset-4 transition-colors hover:text-brand hover:decoration-brand"
            >
              DMCA / copyright notice
            </Link>
            .
          </p>
          <p className="max-w-3xl text-[11px] leading-relaxed text-[rgba(237,230,218,0.32)] sm:text-xs">
            Marketing stills from Blender Foundation open movies (Big Buck Bunny, Sintel,
            Tears of Steel, Sprite Fright, Cosmos Laundromat) — used under Creative Commons
            Attribution.
          </p>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <p className="font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.35)]">
              © {year} Forja · Streaming player
            </p>
            <p className="font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.28)]">
              Desk · Couch · TV
            </p>
          </div>
        </div>
      </div>
    </footer>
  )
}
