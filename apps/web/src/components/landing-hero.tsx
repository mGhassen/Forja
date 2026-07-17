import { Link } from '@tanstack/react-router'
import { HeroTvMock } from '@/components/interactive-shell-demo'
import { Reveal } from '@/components/reveal'

/**
 * Marketing hero - player app pitch, Download CTA, product mock.
 */
export function LandingHero() {
  return (
    <header className="relative pt-16 sm:pt-24">
      <div className="relative mx-auto grid w-full max-w-[1500px] items-center gap-8 px-[5vw] pb-12 pt-6 sm:pb-16 sm:pt-10 lg:grid-cols-[0.9fr_1.2fr] lg:gap-10 lg:pb-24 lg:pt-14">
        <div className="hero-enter max-w-xl">
          <h1 className="font-disp text-[clamp(34px,9vw,72px)] uppercase leading-[0.9] tracking-[-0.04em]">
            <span className="inline sm:whitespace-nowrap">A player built</span>
            <br />
            <span className="font-serif-i normal-case text-flame">to stream.</span>
          </h1>
          <p className="mt-4 max-w-lg font-disp text-[clamp(16px,4.2vw,28px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)] sm:mt-5">
            Playback. Guides. Live lists.
            <br />
            Sources you connect.
            <br />
            <span className="text-[#EDE6DA]">One app. Your screens.</span>
          </p>

          <Link
            to="/download"
            data-hover=""
            className="btn-magnet mt-7 inline-flex w-full items-center justify-center rounded-full px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] shadow-[0_0_32px_rgba(28,231,131,0.35)] will-change-transform sm:mt-8 sm:w-auto sm:px-10 sm:text-[15px]"
          >
            Get the app
          </Link>
        </div>

        <Reveal variant="right" delayMs={120} className="w-full max-w-[760px] justify-self-center lg:justify-self-end">
          <div className="animate-float">
            <HeroTvMock className="w-full" />
          </div>
        </Reveal>
      </div>
    </header>
  )
}
