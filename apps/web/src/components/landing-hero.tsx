import { HeroTvMock } from '@/components/interactive-shell-demo'
import { PlatformDownloadButtons } from '@/components/platform-download-buttons'

/**
 * Marketing hero — the opening line of the story.
 */
export function LandingHero() {
  return (
    <header className="relative overflow-hidden pt-[5.5rem] sm:pt-24">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(ellipse 55% 50% at 85% 40%, rgba(28,231,131,0.12), transparent 55%), radial-gradient(ellipse 45% 45% at 10% 70%, rgba(255,77,28,0.1), transparent 50%)',
        }}
      />

      <div className="relative z-[2] mx-auto grid max-w-[1500px] items-center gap-10 px-[5vw] pb-16 pt-10 lg:grid-cols-[0.9fr_1.2fr] lg:gap-10 lg:pb-24 lg:pt-14">
        <div className="max-w-xl">
          <h1 className="font-disp text-[clamp(40px,8vw,80px)] uppercase leading-[0.88] tracking-[-0.04em]">
            Tonight starts
            <br />
            <span className="font-serif-i normal-case text-flame">here.</span>
          </h1>
          <p className="mt-6 max-w-lg font-disp text-[clamp(20px,2.8vw,32px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]">
            Blockbusters. Binges.
            <br />
            Matches. Late-night TV.
            <br />
            <span className="text-[#EDE6DA]">Your escape — free.</span>
          </p>

          <div className="mt-9">
            <PlatformDownloadButtons variant="pills" />
          </div>
        </div>

        <HeroTvMock className="w-[min(100%,800px)] justify-self-center lg:justify-self-end" />
      </div>
    </header>
  )
}
