import { useRef, type MouseEvent } from 'react'
import { Link } from '@tanstack/react-router'
import { BrandLogo } from '@/components/brand-logo'
import { CustomCursor } from '@/components/custom-cursor'
import { LandingHero } from '@/components/landing-hero'
import { LibraryHubs } from '@/components/library-hubs'
import { NowPlayingPanel } from '@/components/now-playing-panel'
import { Reveal } from '@/components/reveal'
import { SiteHeader } from '@/components/site-header'

/** Four different nights — not four ways to say “watch everywhere”. */
const NIGHTS = [
  {
    k: 'The premiere',
    v: 'Lights down. Big screen energy. A film that owns the room.',
  },
  {
    k: 'The binge',
    v: 'One more episode turns into three. You don’t fight it.',
  },
  {
    k: 'The roar',
    v: 'Kickoff. Overtime. The whole house on the edge of the seat.',
  },
  {
    k: 'The after-hours',
    v: 'Channels still humming when the city goes quiet.',
  },
]

const MARQUEE = [
  'Drama',
  'Action',
  'Anime',
  'Romance',
  'Thriller',
  'Comedy',
  'Football',
  'Basketball',
  'News',
  'Documentaries',
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
    <div className="film-grain relative bg-[#0B0A0A] text-[#EDE6DA]">
      <CustomCursor />
      <SiteHeader />

      <LandingHero />

      {/* Beat 2 — moods of a night */}
      <section
        id="why"
        className="border-y border-[rgba(237,230,218,0.14)] bg-[#0f0e0d]"
      >
        <div className="mx-auto max-w-[1400px] px-[5vw] pt-14 pb-4 lg:pt-16">
          <Reveal>
            <h2 className="max-w-[16ch] font-disp text-[clamp(36px,6vw,64px)] uppercase leading-[0.92] tracking-[-0.03em]">
              Four kinds of
              <br />
              <span className="text-flame">night.</span>
            </h2>
            <p className="mt-6 font-disp text-[clamp(20px,2.8vw,32px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]">
              Forja follows the mood —
              <br />
              <span className="text-[#EDE6DA]">not the other way around.</span>
            </p>
          </Reveal>
        </div>
        <div className="mx-auto grid max-w-[1400px] lg:grid-cols-2 xl:grid-cols-4">
          {NIGHTS.map((d, i) => (
            <Reveal key={d.k} delayMs={i * 70}>
              <div
                className={`h-full border-[rgba(237,230,218,0.14)] px-[5vw] py-10 lg:border-r lg:px-8 lg:py-12 ${i === NIGHTS.length - 1 ? 'lg:border-r-0' : ''} ${i >= 2 ? 'xl:border-t-0' : ''}`}
              >
                <h3 className="font-disp text-[clamp(22px,2.8vw,32px)] uppercase leading-tight tracking-tight">
                  {d.k}
                </h3>
                <p className="mt-3 font-disp text-lg uppercase leading-snug tracking-tight text-[rgba(237,230,218,0.5)] sm:text-xl">
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

      {/* Beat 3 — discovery / home */}
      <section className="border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh]">
        <div className="mx-auto grid max-w-[1200px] items-center gap-10 lg:grid-cols-2 lg:gap-14">
          <Reveal>
            <img
              src="/brand/forja-home-hero.jpg"
              alt="Forja home — cinematic hero and featured shelves"
              width={1024}
              height={643}
              className="h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]"
              decoding="async"
            />
          </Reveal>
          <Reveal delayMs={60}>
            <h2 className="font-disp text-[clamp(36px,5.5vw,64px)] uppercase leading-[0.9] tracking-[-0.04em]">
              Sit down.
              <br />
              <span className="text-flame">Something&apos;s waiting.</span>
            </h2>
            <ul className="mt-8 space-y-3 font-disp text-[clamp(18px,2.4vw,28px)] uppercase leading-[1.05] tracking-[-0.02em] text-[rgba(237,230,218,0.72)]">
              <li>
                A hero that <span className="text-brand">pulls you in</span>
              </li>
              <li>
                Shelves that feel <span className="text-flame">personal</span>
              </li>
              <li>
                New titles. <span className="text-[#EDE6DA]">Old favorites.</span>
              </li>
              <li>No hunting. Just the night ahead.</li>
            </ul>
          </Reveal>
        </div>
      </section>

      {/* Beat 4 — live only */}
      <section className="border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh]">
        <div className="mx-auto grid max-w-[1200px] items-center gap-10 lg:grid-cols-2 lg:gap-14">
          <Reveal delayMs={60} className="lg:order-1">
            <h2 className="font-disp text-[clamp(36px,5.5vw,64px)] uppercase leading-[0.9] tracking-[-0.04em]">
              When the world
              <br />
              <span className="text-brand">watches together.</span>
            </h2>
            <ul className="mt-8 space-y-3 font-disp text-[clamp(18px,2.4vw,28px)] uppercase leading-[1.05] tracking-[-0.02em] text-[rgba(237,230,218,0.72)]">
              <li>
                Kickoff. <span className="text-flame">Overtime.</span>
              </li>
              <li>
                Channels that never <span className="text-[#EDE6DA]">sleep</span>
              </li>
              <li>News. Sport. The night still live.</li>
              <li>Feel the moment — not a commercial break.</li>
            </ul>
            <Link
              to="/iptv"
              className="font-mono-ui mt-10 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
            >
              Explore IPTV Player
            </Link>
          </Reveal>
          <Reveal className="lg:order-2">
            <img
              src="/brand/forja-iptv-live.jpg"
              alt="Forja IPTV — live channels and categories"
              width={1024}
              height={637}
              className="h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]"
              decoding="async"
            />
          </Reveal>
        </div>
      </section>

      {/* Beat 5 — worlds / catalog */}
      <LibraryHubs />

      {/* Beat 6 — feeling, not platforms */}
      <section className="border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[12vh]">
        <div className="mx-auto flex max-w-[1100px] flex-col gap-12">
          <Reveal>
            <h2 className="font-disp text-[clamp(40px,7vw,84px)] uppercase leading-[0.9] tracking-[-0.03em]">
              Nights that
              <br />
              <span className="font-serif-i normal-case text-flame">belong to you.</span>
            </h2>
          </Reveal>
          <Reveal delayMs={80}>
            <ul className="space-y-8">
              <li>
                <p className="font-disp text-[clamp(28px,4vw,44px)] uppercase leading-none text-[#EDE6DA]">
                  No interruptions
                </p>
                <p className="mt-2 font-disp text-xl uppercase tracking-tight text-[rgba(237,230,218,0.45)] sm:text-2xl">
                  The story stays on the screen — not behind an ad.
                </p>
              </li>
              <li>
                <p className="font-disp text-[clamp(28px,4vw,44px)] uppercase leading-none text-[#EDE6DA]">
                  No decision fatigue
                </p>
                <p className="mt-2 font-disp text-xl uppercase tracking-tight text-[rgba(237,230,218,0.45)] sm:text-2xl">
                  Open Forja. The night finds you.
                </p>
              </li>
              <li>
                <p className="font-disp text-[clamp(28px,4vw,44px)] uppercase leading-none text-[#EDE6DA]">
                  No small print
                </p>
                <p className="mt-2 font-disp text-xl uppercase tracking-tight text-[rgba(237,230,218,0.45)] sm:text-2xl">
                  Free means free. Stay as long as you want.
                </p>
              </li>
            </ul>
          </Reveal>
        </div>
      </section>

      {/* Beat 7 — platforms ONLY here */}
      <section className="relative overflow-hidden border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[12vh] text-center">
        <Reveal>
          <div className="font-disp text-[clamp(48px,12vw,140px)] uppercase leading-[0.9] tracking-[-0.04em]">
            Your screens.
          </div>
          <p className="mx-auto mt-8 max-w-3xl font-disp text-[clamp(22px,3.5vw,40px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]">
            Desk. Living room.
            <br />
            <span className="text-[#EDE6DA]">Same night. Same Forja.</span>
          </p>
          <p className="font-mono-ui mt-8 text-[clamp(12px,1.5vw,15px)] uppercase tracking-[0.2em] text-[rgba(237,230,218,0.42)]">
            Windows · macOS · Linux · Android TV
          </p>
        </Reveal>
      </section>

      {/* Beat 8 — close */}
      <section
        id="drop"
        className="grid grid-cols-1 items-center gap-10 border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh] md:grid-cols-[0.95fr_1.15fr] md:gap-14 lg:gap-16"
      >
        <Reveal>
          <h2 className="font-disp text-[clamp(40px,10vw,110px)] uppercase leading-[0.85] tracking-[-0.04em]">
            Don&apos;t wait
            <br />
            <span className="text-brand">for the night.</span>
          </h2>
          <p className="mt-6 max-w-lg font-disp text-[clamp(18px,3vw,36px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)] sm:mt-8">
            Download Forja.
            <br />
            Press play.
            <br />
            <span className="text-[#EDE6DA]">It&apos;s already free.</span>
          </p>
          <Link
            ref={magnetRef}
            to="/download"
            data-hover=""
            onMouseMove={onMagnetMove}
            onMouseLeave={onMagnetLeave}
            className="btn-magnet mt-7 inline-flex w-full items-center justify-center rounded-full px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] will-change-transform sm:mt-8 sm:w-auto sm:px-[34px] sm:py-5 sm:text-[15px]"
          >
            Get Forja
          </Link>
        </Reveal>

        <Reveal delayMs={100} className="w-full min-w-0">
          <NowPlayingPanel className="w-full max-w-none" />
        </Reveal>
      </section>

      <footer className="overflow-hidden pt-[6vh]">
        <div className="flex flex-col items-center gap-8 px-[5vw] pb-4">
          <BrandLogo
            to="/"
            imgClassName="h-14 w-auto drop-shadow-[0_0_28px_rgba(28,231,131,0.4)] sm:h-20"
          />
        </div>
        <div className="font-mono-ui mt-[2vh] flex flex-wrap justify-between gap-4 border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[26px] text-xs uppercase tracking-[0.1em] text-[rgba(237,230,218,0.42)]">
          <span>Forja</span>
          <Link to="/download" className="transition-colors hover:text-brand">
            Downloads
          </Link>
          <span>© {new Date().getFullYear()}</span>
        </div>
      </footer>
    </div>
  )
}
