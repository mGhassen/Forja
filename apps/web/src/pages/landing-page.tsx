import { useRef, type MouseEvent } from 'react'
import { Link } from '@tanstack/react-router'
import { LandingHero } from '@/components/landing-hero'
import { LibraryHubs } from '@/components/library-hubs'
import { NowPlayingPanel } from '@/components/now-playing-panel'
import { Reveal } from '@/components/reveal'
import { SiteFooter } from '@/components/legal-shell'
import { SiteHeader } from '@/components/site-header'
import { PageAtmosphere } from '@/components/page-atmosphere'

const MARQUEE = [
  'Movies',
  'Series',
  'Anime',
  'Live sport',
  'IPTV',
  'Community packs',
  'Open source',
  'Desk to TV',
]

export function LandingPage() {
  const magnetRef = useRef<HTMLAnchorElement>(null)

  function onMagnetMove(e: MouseEvent<HTMLAnchorElement>) {
    const mag = magnetRef.current
    if (!mag) return
    const fine = window.matchMedia('(hover: hover) and (pointer: fine)').matches
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (!fine || reduced) return
    const r = mag.getBoundingClientRect()
    const x = e.clientX - (r.left + r.width / 2)
    const y = e.clientY - (r.top + r.height / 2)
    mag.style.transform = `translate(${x * 0.3}px, ${y * 0.4}px)`
  }

  function onMagnetLeave() {
    if (magnetRef.current) magnetRef.current.style.transform = ''
  }

  const marqueeItems = [...MARQUEE, ...MARQUEE]

  return (
    <div className="film-grain relative bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="landing" />
      <div className="relative z-10">
        <SiteHeader />

        <LandingHero />

        <div className="overflow-hidden whitespace-nowrap border-y border-[rgba(237,230,218,0.14)] py-5">
          <div className="animate-marquee inline-flex w-max">
            {marqueeItems.map((w, i) => (
              <span key={`${w}-${i}`} className="inline-flex items-center">
                <b className="font-serif-i px-[22px] text-[clamp(22px,3.8vw,44px)] text-[#EDE6DA]">
                  {w}
                </b>
                <span className="font-disp self-center px-1.5 text-[clamp(18px,2.5vw,32px)] text-flame">
                  ✦
                </span>
              </span>
            ))}
          </div>
        </div>

        <section className="border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh]">
          <div className="mx-auto grid max-w-[1200px] items-center gap-10 lg:grid-cols-2 lg:gap-14">
            <Reveal variant="left">
              <div className="hover-zoom rounded-lg">
                <img
                  src="/brand/forja-home-hero.jpg"
                  alt="Forja home - cinematic hero and featured shelves"
                  width={1024}
                  height={643}
                  className="h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]"
                  decoding="async"
                />
              </div>
            </Reveal>
            <Reveal delayMs={80} variant="right">
              <h2 className="font-disp text-[clamp(32px,5vw,56px)] uppercase leading-[0.92] tracking-[-0.04em]">
                A player that
                <br />
                <span className="text-flame">feels like yours</span>
              </h2>
              <p className="mt-6 text-base leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-lg">
                Cinematic home, clear shelves, and controls built for long
                sessions. Forja is not a locked catalog. You shape what lands in
                the app.
              </p>
              <Link
                to="/platform"
                className="link-draw font-mono-ui mt-10 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
              >
                See what makes Forja unique
              </Link>
            </Reveal>
          </div>
        </section>

        <LibraryHubs />

        <section className="border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[12vh]">
          <div className="mx-auto max-w-[1100px]">
            <Reveal>
              <h2 className="font-disp text-[clamp(36px,6vw,72px)] uppercase leading-[0.92] tracking-[-0.03em]">
                Built with the
                <br />
                <span className="font-serif-i normal-case text-flame">
                  community
                </span>
              </h2>
              <p className="mt-6 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-lg">
                Community packs extend hubs and sources. The host stays open so
                authors can ship what the catalog is missing, and you only
                install what you want.
              </p>
              <div className="mt-8 flex flex-wrap gap-3">
                <Link
                  to="/plugins"
                  data-hover=""
                  className="btn-magnet inline-flex items-center justify-center rounded-full px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_28px_rgba(28,231,131,0.3)] sm:text-xs"
                >
                  Browse packs
                </Link>
                <Link
                  to="/platform"
                  data-hover=""
                  className="inline-flex items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.7)] transition hover:border-forja-green/40 hover:text-forja-green sm:text-xs"
                >
                  Explore the platform
                </Link>
              </div>
            </Reveal>
          </div>
        </section>

        <section className="relative overflow-hidden border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[12vh] text-center">
          <Reveal>
            <h2 className="font-disp text-[clamp(36px,7vw,84px)] uppercase leading-[0.92] tracking-[-0.04em]">
              Desk. Couch.
              <br />
              <span className="text-flame">TV.</span>
            </h2>
            <p className="mx-auto mt-8 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-lg">
              Same Forja on every screen. Sign in to sync settings and packs
              across devices.
            </p>
          </Reveal>
        </section>

        <section
          id="drop"
          className="grid grid-cols-1 items-center gap-10 border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh] md:grid-cols-[0.95fr_1.15fr] md:gap-14 lg:gap-16"
        >
          <Reveal>
            <h2 className="font-disp text-[clamp(36px,8vw,84px)] uppercase leading-[0.9] tracking-[-0.04em]">
              Download Forja
              <br />
              <span className="text-brand">and start streaming</span>
            </h2>
            <p className="mt-6 max-w-lg text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:mt-8 sm:text-lg">
              Get the player, add the packs you need, and press play. Forja does
              not host media files. You bring the sources.
            </p>
            <Link
              ref={magnetRef}
              to="/download"
              data-hover=""
              onMouseMove={onMagnetMove}
              onMouseLeave={onMagnetLeave}
              className="btn-magnet mt-7 inline-flex w-full items-center justify-center rounded-full px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] will-change-transform sm:mt-8 sm:w-auto sm:px-[34px] sm:py-5 sm:text-[15px]"
            >
              Download Forja
            </Link>
          </Reveal>

          <Reveal delayMs={100} className="w-full min-w-0">
            <NowPlayingPanel className="w-full max-w-none" />
          </Reveal>
        </section>

        <SiteFooter />
      </div>
    </div>
  )
}
