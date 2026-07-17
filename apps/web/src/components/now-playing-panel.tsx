import { useEffect, useState } from 'react'
import { Link } from '@tanstack/react-router'
import { cn } from '@/lib/utils'

/** CC BY Blender Foundation open movies - no TMDB commercial art. */
const REEL = [
  {
    id: 'sintel',
    title: 'Sintel',
    tag: 'Open film',
    poster: '/brand/open-films/sintel.jpg',
    backdrop: '/brand/open-films/sintel.jpg',
  },
  {
    id: 'bbb',
    title: 'Big Buck Bunny',
    tag: 'Open film',
    poster: '/brand/open-films/big-buck-bunny.jpg',
    backdrop: '/brand/open-films/big-buck-bunny.jpg',
  },
  {
    id: 'tos',
    title: 'Tears of Steel',
    tag: 'Open film',
    poster: '/brand/open-films/tears-of-steel.jpg',
    backdrop: '/brand/open-films/tears-of-steel.jpg',
  },
  {
    id: 'cosmos',
    title: 'Cosmos Laundromat',
    tag: 'Open film',
    poster: '/brand/open-films/cosmos-laundromat.jpg',
    backdrop: '/brand/open-films/cosmos-laundromat.jpg',
  },
] as const

const CYCLE_MS = 4200

/** Animated “now playing” stack - replaces dry CTA stats. */
export function NowPlayingPanel({ className }: { className?: string }) {
  const [index, setIndex] = useState(0)
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
      setIndex((i) => (i + 1) % REEL.length)
    }, CYCLE_MS)
    return () => window.clearInterval(id)
  }, [reduced])

  const current = REEL[index]!
  const prev = REEL[(index - 1 + REEL.length) % REEL.length]!
  const next = REEL[(index + 1) % REEL.length]!

  return (
    <div className={cn('w-full', className)}>
      <div className="relative overflow-hidden rounded-2xl border border-[rgba(237,230,218,0.14)] bg-[#121110]">
        {/* Backdrop glow */}
        <div className="pointer-events-none absolute inset-0">
          {REEL.map((item, i) => (
            <img
              key={item.id}
              src={item.backdrop}
              alt=""
              aria-hidden
              className={cn(
                'absolute inset-0 h-full w-full object-cover transition-opacity duration-700',
                i === index ? 'opacity-40' : 'opacity-0',
              )}
            />
          ))}
          <div className="absolute inset-0 bg-gradient-to-t from-forja-bg via-forja-bg/85 to-forja-bg/40" />
        </div>

        <div className="relative flex flex-col gap-5 p-5 sm:flex-row sm:gap-7 sm:p-8 lg:gap-8 lg:p-10">
          {/* Poster stack */}
          <div className="relative mx-auto h-[220px] w-[128px] shrink-0 sm:mx-0 sm:h-[320px] sm:w-[188px] lg:h-[360px] lg:w-[210px]">
            <img
              src={prev.poster}
              alt=""
              aria-hidden
              className="absolute top-4 left-0 hidden h-[85%] w-[85%] -rotate-6 rounded-xl object-cover opacity-35 shadow-lg sm:block"
            />
            <img
              src={next.poster}
              alt=""
              aria-hidden
              className="absolute top-4 right-0 hidden h-[85%] w-[85%] rotate-6 rounded-xl object-cover opacity-35 shadow-lg sm:block"
            />
            {REEL.map((item, i) => (
              <img
                key={item.id}
                src={item.poster}
                alt={item.title}
                className={cn(
                  'absolute inset-0 h-full w-full rounded-xl object-cover shadow-2xl ring-1 ring-white/10 transition-all duration-500',
                  i === index
                    ? 'z-10 scale-100 opacity-100'
                    : 'z-0 scale-95 opacity-0',
                )}
              />
            ))}
            <div
              className="pointer-events-none absolute inset-0 z-20 flex items-center justify-center"
              aria-hidden
            >
              <div className="animate-play-pulse flex h-12 w-12 items-center justify-center rounded-full bg-brand text-[#0B0A0A] shadow-[0_0_32px_rgba(28,231,131,0.5)] sm:h-16 sm:w-16">
                <svg viewBox="0 0 24 24" className="h-5 w-5 fill-current sm:h-7 sm:w-7">
                  <path d="M8 5v14l11-7z" />
                </svg>
              </div>
            </div>
          </div>

          {/* Copy + progress */}
          <div className="flex min-w-0 flex-1 flex-col justify-between py-1 text-center sm:py-2 sm:text-left">
            <div>
              <p className="font-mono-ui flex items-center justify-center gap-2 text-[11px] uppercase tracking-[0.22em] text-brand sm:justify-start sm:text-xs">
                <span className="animate-live-dot inline-block h-2 w-2 rounded-full bg-brand" />
                Now playing
              </p>
              <p
                key={current.id}
                className="font-disp animate-now-title mt-3 text-[clamp(26px,7vw,48px)] uppercase leading-[0.95] tracking-tight text-[#EDE6DA] sm:mt-4"
              >
                {current.title}
              </p>
              <p className="mt-2 font-disp text-base uppercase tracking-wide text-[rgba(237,230,218,0.45)] sm:mt-3 sm:text-lg">
                {current.tag}
                <span className="mx-2 text-[rgba(237,230,218,0.25)]">·</span>
                Watch now
              </p>
            </div>

            <div className="mt-6 sm:mt-10">
              <div className="h-1.5 overflow-hidden rounded-full bg-[rgba(237,230,218,0.12)]">
                <div
                  key={current.id}
                  className={cn(
                    'h-full rounded-full bg-flame',
                    reduced ? 'w-[66%]' : 'animate-stream-progress',
                  )}
                />
              </div>
              <div className="font-mono-ui mt-3 flex justify-between text-[11px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.38)] sm:text-xs">
                <span>Free</span>
                <span>Desk to TV</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <Link
        to="/download"
        data-hover=""
        className="font-mono-ui mt-5 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
      >
        Download Forja
      </Link>
    </div>
  )
}
