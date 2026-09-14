import { useRef, type MouseEvent } from 'react'
import { Link } from '@tanstack/react-router'
import { LandingHero } from '@/components/landing-hero'
import { LibraryHubs } from '@/components/library-hubs'
import { NowPlayingPanel } from '@/components/now-playing-panel'
import { PluginOrbitVisual } from '@/components/plugin-orbit-visual'
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
                A cinematic home for what is on next
              </h2>
              <p className="mt-6 text-base leading-relaxed text-[rgba(237,230,218,0.68)] sm:text-lg">
                Forja opens on a featured title, rich posters, and shelves you can
                skim in seconds.
              </p>
              <ul className="mt-6 space-y-3 text-base leading-relaxed text-[rgba(237,230,218,0.78)] sm:text-lg">
                <li>Featured heroes and poster shelves</li>
                <li>Movies, series, anime, sport, and live TV in one place</li>
              </ul>
              <Link
                to="/platform"
                className="link-draw font-mono-ui mt-10 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
              >
                Platform
              </Link>
            </Reveal>
          </div>
        </section>

        <LibraryHubs />

        <section className="relative overflow-hidden border-t border-[rgba(237,230,218,0.14)]">
          <div className="absolute inset-0 bg-[#0f0e0d]" aria-hidden />
          <div
            aria-hidden
            className="pointer-events-none absolute -right-24 top-1/2 h-[420px] w-[420px] -translate-y-1/2 rounded-full bg-[radial-gradient(circle,rgba(28,231,131,0.12),transparent_65%)]"
          />
          <div className="relative mx-auto grid max-w-[1200px] items-center gap-12 px-[5vw] py-[12vh] lg:grid-cols-[1.05fr_0.95fr] lg:gap-16">
            <Reveal variant="left">
              <p className="font-serif-i text-2xl text-flame sm:text-3xl">
                Packs
              </p>
              <h2 className="mt-3 font-disp text-[clamp(28px,5vw,52px)] uppercase leading-[0.92] tracking-[-0.03em]">
                Add anime, sport, IPTV, and more
              </h2>
              <p className="mt-6 max-w-lg text-base leading-relaxed text-[rgba(237,230,218,0.65)] sm:text-lg">
                Community packs add anime, live sport, IPTV, torrent search, and
                more to Forja. Pick a ready-made set or browse the full catalog.
              </p>
              <Link
                to="/plugins"
                data-hover=""
                className="btn-magnet mt-8 inline-flex items-center justify-center rounded-full px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_28px_rgba(28,231,131,0.3)] sm:text-xs"
              >
                Packs
              </Link>
            </Reveal>
            <Reveal delayMs={80} variant="right" className="flex justify-center lg:justify-end">
              <PluginOrbitVisual />
            </Reveal>
          </div>
        </section>

        <section
          id="drop"
          className="grid grid-cols-1 items-center gap-10 border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh] md:grid-cols-[0.95fr_1.15fr] md:gap-14 lg:gap-16"
        >
          <Reveal>
            <h2 className="font-disp text-[clamp(28px,5vw,52px)] uppercase leading-[0.95] tracking-[-0.03em]">
              Your sources.
              <br />
              <span className="font-serif-i normal-case text-flame">
                Your player.
              </span>
            </h2>
            <p className="mt-6 max-w-lg text-base leading-relaxed text-[rgba(237,230,218,0.68)] sm:mt-8 sm:text-lg">
              Forja is a modular player platform. Your sources and packs decide
              what lands on screen tonight.
            </p>
            <div className="mt-7 flex flex-wrap gap-3 sm:mt-8">
              <Link
                ref={magnetRef}
                to="/download"
                data-hover=""
                onMouseMove={onMagnetMove}
                onMouseLeave={onMagnetLeave}
                className="btn-magnet inline-flex w-full items-center justify-center rounded-full px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] will-change-transform sm:w-auto sm:px-[34px] sm:py-5 sm:text-[15px]"
              >
                Download
              </Link>
              <Link
                to="/plugins"
                data-hover=""
                className="inline-flex w-full items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] text-[rgba(237,230,218,0.75)] transition hover:border-forja-flame/40 hover:text-forja-flame sm:w-auto sm:px-8 sm:text-[15px]"
              >
                Packs
              </Link>
            </div>
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
