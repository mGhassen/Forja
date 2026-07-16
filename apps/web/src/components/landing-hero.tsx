import { Link } from '@tanstack/react-router'
import { HeroTvMock } from '@/components/interactive-shell-demo'

/**
 * Marketing hero — headline, one line, Download CTA, product mock.
 */
export function LandingHero() {
  return (
    <header className="relative overflow-hidden pt-16 sm:pt-24">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(ellipse 55% 50% at 85% 40%, rgba(28,231,131,0.12), transparent 55%), radial-gradient(ellipse 45% 45% at 10% 70%, rgba(255,77,28,0.1), transparent 50%)',
        }}
      />

      <div className="relative z-[2] mx-auto grid w-full max-w-[1500px] items-center gap-8 px-[5vw] pb-10 pt-5 sm:pb-12 sm:pt-6 lg:grid-cols-[0.9fr_1.2fr] lg:gap-10 lg:pb-16 lg:pt-8">
        <div className="max-w-xl">
          <h1 className="font-disp text-[clamp(34px,9vw,72px)] uppercase leading-[0.9] tracking-[-0.04em]">
            <span className="inline sm:whitespace-nowrap">Tonight starts</span>
            <br />
            <span className="font-serif-i normal-case text-flame">here.</span>
          </h1>
          <p className="mt-4 max-w-lg font-disp text-[clamp(16px,4.2vw,28px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)] sm:mt-5">
            Blockbusters. Binges.
            <br />
            Matches. Late-night TV.
            <br />
            <span className="text-[#EDE6DA]">Your escape — free.</span>
          </p>

          <Link
            to="/download"
            data-hover=""
            className="btn-magnet mt-7 inline-flex w-full items-center justify-center rounded-full px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] shadow-[0_0_32px_rgba(28,231,131,0.35)] will-change-transform sm:mt-8 sm:w-auto sm:px-10 sm:text-[15px]"
          >
            Download Forja
          </Link>
        </div>

        <HeroTvMock className="w-full max-w-[760px] justify-self-center lg:justify-self-end" />
      </div>
    </header>
  )
}
