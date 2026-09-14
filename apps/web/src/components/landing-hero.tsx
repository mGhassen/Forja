import { Link } from '@tanstack/react-router'
import { HeroTvMock } from '@/components/interactive-shell-demo'
import { Reveal } from '@/components/reveal'

/** Home hero: marketing first. Product depth lives on /platform. */
export function LandingHero() {
  return (
    <header className="relative pt-16 sm:pt-24">
      <div className="relative mx-auto grid w-full max-w-[1500px] items-center gap-8 px-[5vw] pb-12 pt-6 sm:pb-16 sm:pt-10 lg:grid-cols-[0.9fr_1.2fr] lg:gap-10 lg:pb-24 lg:pt-14">
        <div className="hero-enter max-w-xl">
          <p className="mb-5 font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
            Open-source streaming
          </p>
          <h1 className="font-disp text-[clamp(36px,8.5vw,72px)] uppercase leading-[0.9] tracking-[-0.04em]">
            Stream on your
            <br />
            <span className="font-serif-i normal-case text-flame">terms</span>
          </h1>
          <p className="mt-5 max-w-lg text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:mt-6 sm:text-lg">
            Forja is the modular streaming player built with the community.
            Install packs for hubs and sources, keep your setup, and watch on
            every screen. Open source from the ground up.
          </p>

          <div className="mt-7 flex flex-col gap-3 sm:mt-8 sm:flex-row sm:flex-wrap sm:items-center">
            <Link
              to="/download"
              data-hover=""
              className="btn-magnet inline-flex w-full items-center justify-center rounded-full px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] shadow-[0_0_32px_rgba(28,231,131,0.35)] will-change-transform sm:w-auto sm:px-10 sm:text-[15px]"
            >
              Download Forja
            </Link>
            <Link
              to="/platform"
              data-hover=""
              className="inline-flex w-full items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] text-[rgba(237,230,218,0.75)] transition hover:border-forja-flame/40 hover:text-forja-flame sm:w-auto sm:px-8 sm:text-[15px]"
            >
              Why Forja
            </Link>
          </div>
        </div>

        <Reveal
          variant="right"
          delayMs={120}
          className="w-full max-w-[600px] justify-self-center lg:justify-self-end"
        >
          <div className="animate-float">
            <HeroTvMock className="w-full" />
          </div>
        </Reveal>
      </div>
    </header>
  )
}
