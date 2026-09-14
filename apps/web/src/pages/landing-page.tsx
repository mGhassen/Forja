import { useRef, type MouseEvent } from 'react'
import { Link } from '@tanstack/react-router'
import { LandingHero } from '@/components/landing-hero'
import { LibraryHubs } from '@/components/library-hubs'
import { NowPlayingPanel } from '@/components/now-playing-panel'
import { Reveal } from '@/components/reveal'
import { SiteFooter } from '@/components/legal-shell'
import { SiteHeader } from '@/components/site-header'
import { PageAtmosphere } from '@/components/page-atmosphere'

const CAPABILITIES = [
  {
    k: 'Movies',
    v: 'Pick a title and watch full screen with player controls built for long sessions.',
  },
  {
    k: 'Series',
    v: 'Jump into a show and keep episodes moving without leaving the player.',
  },
  {
    k: 'Live sport',
    v: 'Open a match and follow it as it happens, with sources you install.',
  },
  {
    k: 'Live TV',
    v: 'Add your IPTV list, search channels, and tune in from the same app.',
  },
]

const MARQUEE = [
  'Movies',
  'Series',
  'Anime',
  'Live sport',
  'IPTV',
  'Community packs',
  'Profile sync',
  'Desk to TV',
]

const PILLARS = [
  {
    title: 'Easy to use',
    copy: 'One player, familiar controls, and a home screen that gets you to play fast.',
  },
  {
    title: 'Packs you choose',
    copy: 'Install only the hubs and sources you want. Leave the rest out.',
  },
  {
    title: 'Built for community',
    copy: 'Ship a pack with the SDK, host your manifest URL, and let anyone add it.',
    to: '/build' as const,
  },
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

        <section
          id="why"
          className="border-y border-[rgba(237,230,218,0.14)]"
        >
          <div className="mx-auto max-w-[1400px] px-[5vw] pt-14 pb-4 lg:pt-16">
            <Reveal>
              <h2 className="max-w-[18ch] font-disp text-[clamp(36px,6vw,64px)] uppercase leading-[0.92] tracking-[-0.03em]">
                Everything you stream,
                <br />
                <span className="text-flame">in one player</span>
              </h2>
              <p className="mt-6 max-w-xl text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-lg">
                Use one free app for films, series, live matches, and live TV
                channels you connect.
              </p>
            </Reveal>
          </div>
          <div className="mx-auto grid max-w-[1400px] lg:grid-cols-2 xl:grid-cols-4">
            {CAPABILITIES.map((d, i) => (
              <Reveal
                key={d.k}
                delayMs={i * 80}
                variant={i % 2 === 0 ? 'left' : 'right'}
              >
                <div
                  className={`hover-lift h-full border-[rgba(237,230,218,0.14)] px-[5vw] py-10 lg:border-r lg:px-8 lg:py-12 ${i === CAPABILITIES.length - 1 ? 'lg:border-r-0' : ''} ${i >= 2 ? 'xl:border-t-0' : ''}`}
                >
                  <h3 className="font-disp text-[clamp(22px,2.8vw,32px)] uppercase leading-tight tracking-tight">
                    {d.k}
                  </h3>
                  <p className="mt-3 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                    {d.v}
                  </p>
                </div>
              </Reveal>
            ))}
          </div>
        </section>

        <div className="overflow-hidden whitespace-nowrap border-b border-[rgba(237,230,218,0.14)] py-5">
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

        <section className="border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh]">
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
                A clear home for
                <br />
                <span className="text-flame">what you want next</span>
              </h2>
              <p className="mt-6 text-base leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-lg">
                Forja opens on a cinematic home with a featured hero and shelves
                you can browse fast — so you spend time watching, not digging
                through menus.
              </p>
              <ul className="mt-8 space-y-3 text-base leading-relaxed text-[rgba(237,230,218,0.72)] sm:text-lg">
                <li>Featured titles up front</li>
                <li>Shelves for the hubs you installed</li>
                <li>Same layout from phone-size windows to the big screen</li>
              </ul>
            </Reveal>
          </div>
        </section>

        <section className="border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh]">
          <div className="mx-auto grid max-w-[1200px] items-center gap-10 lg:grid-cols-2 lg:gap-14">
            <Reveal delayMs={60} variant="left" className="lg:order-1">
              <h2 className="font-disp text-[clamp(32px,5vw,56px)] uppercase leading-[0.92] tracking-[-0.04em]">
                Live TV and sport
                <br />
                <span className="text-brand">when you need them live</span>
              </h2>
              <p className="mt-6 text-base leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-lg">
                Guides, channel search, and what&apos;s on now sit inside the
                player. Movies and series stay one tap away — you don&apos;t
                switch apps for a match or a channel.
              </p>
              <Link
                to="/iptv"
                className="link-draw font-mono-ui mt-10 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
              >
                See the live player
              </Link>
            </Reveal>
            <Reveal variant="right" className="lg:order-2">
              <div className="hover-zoom rounded-lg">
                <img
                  src="/brand/forja-iptv-live.jpg"
                  alt="Forja IPTV - live channels and categories"
                  width={1024}
                  height={637}
                  className="h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]"
                  decoding="async"
                />
              </div>
            </Reveal>
          </div>
        </section>

        <section className="border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh]">
          <div className="mx-auto max-w-[1100px]">
            <Reveal>
              <h2 className="font-disp text-[clamp(32px,5.5vw,64px)] uppercase leading-[0.92] tracking-[-0.03em]">
                Extend Forja with
                <br />
                <span className="text-flame">community packs</span>
              </h2>
              <p className="mt-6 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-lg">
                Packs add hubs, stream sources, live feeds, and more. Browse the
                catalog, add packs to your profile, open Forja on a device, and
                they install ready to use. Prefer to build? Publish your own pack
                and share the URL.
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
                  to="/build"
                  data-hover=""
                  className="inline-flex items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.7)] transition hover:border-forja-green/40 hover:text-forja-green sm:text-xs"
                >
                  Build a pack
                </Link>
              </div>
            </Reveal>
          </div>
        </section>

        <LibraryHubs />

        <section className="border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[12vh]">
          <div className="mx-auto flex max-w-[1100px] flex-col gap-12">
            <Reveal>
              <h2 className="font-disp text-[clamp(36px,6vw,72px)] uppercase leading-[0.92] tracking-[-0.03em]">
                Why people
                <br />
                <span className="font-serif-i normal-case text-flame">
                  choose Forja
                </span>
              </h2>
            </Reveal>
            <Reveal delayMs={80}>
              <ul className="space-y-10">
                {PILLARS.map((pillar) => (
                  <li key={pillar.title}>
                    <p className="font-disp text-[clamp(26px,3.5vw,40px)] uppercase leading-none text-[#EDE6DA]">
                      {pillar.title}
                    </p>
                    <p className="mt-3 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-lg">
                      {pillar.copy}
                    </p>
                    {'to' in pillar && pillar.to ? (
                      <Link
                        to={pillar.to}
                        className="link-draw font-mono-ui mt-4 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
                      >
                        Build a pack
                      </Link>
                    ) : null}
                  </li>
                ))}
              </ul>
            </Reveal>
          </div>
        </section>

        <section className="relative overflow-hidden border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[12vh] text-center">
          <Reveal>
            <h2 className="font-disp text-[clamp(36px,7vw,84px)] uppercase leading-[0.92] tracking-[-0.04em]">
              The same player
              <br />
              <span className="text-flame">on every screen</span>
            </h2>
            <p className="mx-auto mt-8 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-lg">
              Use Forja on your desk, on the couch, or on Android TV. Sign in to
              sync settings and packs across devices.
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
              Get the free player, add the community packs you need, and press
              play. Forja does not host media files — you bring the sources.
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
