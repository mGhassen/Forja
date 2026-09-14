import { useEffect, useState } from 'react'
import { Reveal } from '@/components/reveal'
import { cn } from '@/lib/utils'

const WORDS = ['stream', 'sync', 'live', 'play'] as const

const BEATS = [
  {
    n: '01',
    title: 'One modular platform',
    line: 'Movies, series, anime, live sport, and IPTV use the same controls in one app.',
    accent: 'brand' as const,
  },
  {
    n: '02',
    title: 'Community packs',
    line: 'Install hubs and sources you want. Leave out everything else.',
    accent: 'flame' as const,
  },
  {
    n: '03',
    title: 'Open source',
    line: 'Inspect the project, ship packs with the SDK, and sync settings across every screen.',
    accent: 'brand' as const,
  },
]

const MARQUEE = [
  'Playback',
  'Community packs',
  'Live lists',
  'Profile sync',
  'Desk to TV',
]

const CYCLE_MS = 3200

type AuthStoryPanelProps = {
  eyebrow?: string
  lead?: string
  emphasis?: string
}

export function AuthStoryPanel({
  eyebrow = 'Forja',
  lead = 'The modular player platform. Community packs for what you watch.',
  emphasis = 'Open source. Sync across every screen.',
}: AuthStoryPanelProps) {
  const [wordIndex, setWordIndex] = useState(0)
  const [reduced, setReduced] = useState(false)

  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)')
    setReduced(mq.matches)
    const onChange = () => setReduced(mq.matches)
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [])

  useEffect(() => {
    if (reduced) return
    const id = window.setInterval(() => {
      setWordIndex((i) => (i + 1) % WORDS.length)
    }, CYCLE_MS)
    return () => window.clearInterval(id)
  }, [reduced])

  const word = WORDS[wordIndex]!

  return (
    <section className="relative flex h-full min-h-[min(52vh,520px)] flex-col justify-center overflow-hidden border-t border-[rgba(237,230,218,0.1)] py-14 lg:min-h-0 lg:border-t-0 lg:border-r lg:py-16">
      <div className="hero-enter relative z-[1] w-full max-w-xl px-5 sm:px-8 lg:px-10">
        <p className="font-mono-ui text-[11px] uppercase tracking-[0.22em] text-forja-green">
          <span className="animate-live-dot mr-2 inline-block h-1.5 w-1.5 rounded-full bg-forja-green align-middle" />
          {eyebrow}
        </p>

        <h1 className="mt-5 font-disp text-[clamp(36px,4.2vw,64px)] uppercase leading-[0.9] tracking-[-0.04em]">
          Built to
          <br />
          <span
            key={word}
            className="animate-word-in font-serif-i inline-block normal-case text-flame"
          >
            {word}.
          </span>
        </h1>

        <p className="mt-6 max-w-md text-base leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-lg">
          {lead}{' '}
          <span className="text-[#EDE6DA]">{emphasis}</span>
        </p>
      </div>

      <ul className="relative z-[1] mt-8 space-y-3 px-5 sm:px-8 lg:mt-10 lg:space-y-4 lg:px-10">
        {BEATS.map((beat, i) => (
          <Reveal key={beat.n} delayMs={i * 90} variant="left">
            <li className="group flex gap-4 border-l-2 border-[rgba(237,230,218,0.12)] py-1 pl-4 transition-colors hover:border-forja-green/50">
              <span
                className={cn(
                  'font-mono-ui shrink-0 text-[11px] tracking-[0.16em]',
                  beat.accent === 'flame' ? 'text-flame' : 'text-brand',
                )}
              >
                {beat.n}
              </span>
              <div className="min-w-0">
                <p className="font-disp text-lg uppercase tracking-tight text-[#EDE6DA]">
                  {beat.title}
                </p>
                <p className="mt-1 text-sm leading-relaxed text-[rgba(237,230,218,0.48)]">
                  {beat.line}
                </p>
              </div>
            </li>
          </Reveal>
        ))}
      </ul>

      <div className="relative z-[1] mt-8 hidden min-w-0 overflow-hidden border-y border-[rgba(237,230,218,0.12)] bg-[#121110] py-4 sm:block lg:mt-10">
        <div className="animate-marquee flex w-max max-w-none gap-10 whitespace-nowrap px-4">
          {[...MARQUEE, ...MARQUEE].map((item, i) => (
            <span key={`${item}-${i}`} className="inline-flex items-center gap-3">
              <span className="font-serif-i text-xl text-[#EDE6DA]">{item}</span>
              <span className={i % 2 === 0 ? 'text-brand' : 'text-flame'}>✦</span>
            </span>
          ))}
        </div>
      </div>
    </section>
  )
}
