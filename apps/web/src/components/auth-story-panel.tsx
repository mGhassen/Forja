import { useEffect, useState } from 'react'
import { Reveal } from '@/components/reveal'
import { cn } from '@/lib/utils'

const WORDS = ['stream', 'sync', 'live', 'play'] as const

const BEATS = [
  {
    n: '01',
    title: 'One player',
    line: 'Movies, series, anime, live TV - same controls, same calm.',
    accent: 'brand' as const,
  },
  {
    n: '02',
    title: 'Your sources',
    line: 'Playlists you connect. Guides inside the player. Nothing hosted here.',
    accent: 'flame' as const,
  },
  {
    n: '03',
    title: 'Every screen',
    line: 'Desk, couch, TV - pick up where you left off when you sign in.',
    accent: 'brand' as const,
  },
]

const MARQUEE = [
  'Playback',
  'Guides',
  'Live lists',
  'Subtitles',
  'Desk to TV',
  'Sync',
]

const CYCLE_MS = 3200

type AuthStoryPanelProps = {
  eyebrow?: string
  lead?: string
  emphasis?: string
}

export function AuthStoryPanel({
  eyebrow = 'Creative player platform',
  lead = 'One player. Your sources. Every screen.',
  emphasis = 'Sign in to sync settings across your screens.',
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
    <section className="relative flex min-h-[min(52vh,520px)] flex-col justify-center overflow-hidden border-b border-[rgba(237,230,218,0.1)] px-[5vw] py-14 lg:min-h-0 lg:border-b-0 lg:border-r lg:py-20">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(ellipse 70% 60% at 20% 40%, rgba(28,231,131,0.14), transparent 55%), radial-gradient(ellipse 55% 50% at 85% 75%, rgba(255,77,28,0.12), transparent 50%)',
        }}
      />
      <div
        aria-hidden
        className="animate-login-glow pointer-events-none absolute -top-24 right-[-10%] h-64 w-64 rounded-full bg-forja-green/20 blur-3xl"
      />

      <div className="hero-enter relative z-[1] max-w-xl">
        <p className="font-mono-ui text-[11px] uppercase tracking-[0.22em] text-forja-green">
          <span className="animate-live-dot mr-2 inline-block h-1.5 w-1.5 rounded-full bg-forja-green align-middle" />
          {eyebrow}
        </p>

        <h1 className="mt-5 font-disp text-[clamp(36px,7vw,72px)] uppercase leading-[0.9] tracking-[-0.04em]">
          Built to
          <br />
          <span
            key={word}
            className="animate-word-in font-serif-i inline-block normal-case text-flame"
          >
            {word}.
          </span>
        </h1>

        <p className="mt-6 max-w-md font-disp text-[clamp(17px,2.4vw,26px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]">
          {lead}
          <br />
          <span className="text-[#EDE6DA]">{emphasis}</span>
        </p>
      </div>

      <ul className="relative z-[1] mt-10 space-y-4">
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
              <div>
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

      <div className="relative z-[1] mt-10 hidden overflow-hidden border border-[rgba(237,230,218,0.12)] bg-[#121110] py-4 sm:block">
        <div className="animate-marquee flex w-max gap-10 whitespace-nowrap px-4">
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
