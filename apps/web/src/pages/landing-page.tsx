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
  'Profile sync',
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
                  alt="Forja home screen with featured hero and shelves"
                  width={1024}
                  height={643}
                  className="h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]"
                  decoding="async"
                />
              </div>
            </Reveal>
            <Reveal delayMs={80} variant="right">
              <h2 className="font-disp text-[clamp(28px,4.5vw,48px)] uppercase leading-[0.95] tracking-[-0.03em]">
                A clear home for what you want to watch next
              </h2>
              <p className="mt-6 text-base leading-relaxed text-[rgba(237,230,218,0.6)] sm:text-lg">
                Forja opens on a cinematic home with a featured title and shelves
                you can browse quickly. The layout stays readable from a laptop
                window to a living-room TV, so you spend time watching instead of
                digging through menus.
              </p>
              <ul className="mt-6 space-y-2 text-base leading-relaxed text-[rgba(237,230,218,0.7)] sm:text-lg">
                <li>Featured titles and shelves from the hubs you installed</li>
                <li>Player controls built for long movies and series sessions</li>
                <li>No locked catalog: packs decide what appears in the app</li>
              </ul>
              <Link
                to="/platform"
                className="link-draw font-mono-ui mt-10 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
              >
                Read how the platform works
              </Link>
            </Reveal>
          </div>
        </section>

        <LibraryHubs />

        <section className="border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[12vh]">
          <div className="mx-auto max-w-[1100px]">
            <Reveal>
              <h2 className="font-disp text-[clamp(28px,4.5vw,48px)] uppercase leading-[0.95] tracking-[-0.03em]">
                Community packs that extend what Forja can play
              </h2>
              <p className="mt-6 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.6)] sm:text-lg">
                Packs add hubs, stream sources, live feeds, and more. Browse the
                catalog, add packs to your profile, open Forja on a device, and
                they install ready to use. Prefer to contribute? Publish your own
                pack and share the URL with the community.
              </p>
              <div className="mt-8 flex flex-wrap gap-3">
                <Link
                  to="/plugins"
                  data-hover=""
                  className="btn-magnet inline-flex items-center justify-center rounded-full px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_28px_rgba(28,231,131,0.3)] sm:text-xs"
                >
                  Browse community packs
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

        <section className="relative overflow-hidden border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[12vh]">
          <Reveal>
            <div className="mx-auto max-w-[1100px] text-center">
              <h2 className="font-disp text-[clamp(28px,4.5vw,48px)] uppercase leading-[0.95] tracking-[-0.03em]">
                The same player on every screen you use
              </h2>
              <p className="mx-auto mt-6 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.6)] sm:text-lg">
                Use Forja on your desk, on the couch, or on Android TV. Sign in
                to sync settings and installed packs across devices so your setup
                follows you.
              </p>
            </div>
          </Reveal>
        </section>

        <section
          id="drop"
          className="grid grid-cols-1 items-center gap-10 border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh] md:grid-cols-[0.95fr_1.15fr] md:gap-14 lg:gap-16"
        >
          <Reveal>
            <h2 className="font-disp text-[clamp(28px,5vw,52px)] uppercase leading-[0.95] tracking-[-0.03em]">
              Download Forja and start streaming
            </h2>
            <p className="mt-6 max-w-lg text-base leading-relaxed text-[rgba(237,230,218,0.6)] sm:mt-8 sm:text-lg">
              Install the player, add the community packs you need, and press
              play. Forja does not host media files. You connect sources and
              packs yourself.
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
