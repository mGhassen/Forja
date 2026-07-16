import { useEffect, useState } from 'react'
import { PlatformDownloadButtons } from '@/components/platform-download-buttons'
import { cn } from '@/lib/utils'

const tmdb = (path: string, size: 'w342' | 'w780' = 'w342') =>
  `https://image.tmdb.org/t/p/${size}${path}`

/** Verified TMDB paths — same set as the hero TV mock */
const REEL = [
  {
    id: 'dune2',
    title: 'Dune: Part Two',
    tag: 'Film',
    poster: '/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg',
    backdrop: '/eZ239CUp1d6OryZEBPnO2n87gMG.jpg',
  },
  {
    id: 'shogun',
    title: 'Shōgun',
    tag: 'Series',
    poster: '/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg',
    backdrop: '/6Tb87q9Tog30F5AAHh1gyDT2Vve.jpg',
  },
  {
    id: 'fallout',
    title: 'Fallout',
    tag: 'Series',
    poster: '/c15BtJxCXMrISLVmysdsnZUPQft.jpg',
    backdrop: '/coaPCIqQBPUZsOnJcWZxhaORcDT.jpg',
  },
  {
    id: 'challengers',
    title: 'Challengers',
    tag: 'Film',
    poster: '/H6vke7zGiuLsz4v4RPeReb9rsv.jpg',
    backdrop: '/tq8COKsI99Bivjd4CZIYVGoKcIx.jpg',
  },
] as const

const CYCLE_MS = 4200

/** Animated “now playing” stack — replaces dry CTA stats. */
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
              src={tmdb(item.backdrop, 'w780')}
              alt=""
              aria-hidden
              className={cn(
                'absolute inset-0 h-full w-full object-cover transition-opacity duration-700',
                i === index ? 'opacity-40' : 'opacity-0',
              )}
            />
          ))}
          <div className="absolute inset-0 bg-gradient-to-t from-[#0B0A0A] via-[#0B0A0A]/85 to-[#0B0A0A]/40" />
        </div>

        <div className="relative flex gap-5 p-6 sm:gap-7 sm:p-8 lg:gap-8 lg:p-10">
          {/* Poster stack */}
          <div className="relative h-[260px] w-[152px] shrink-0 sm:h-[320px] sm:w-[188px] lg:h-[360px] lg:w-[210px]">
            <img
              src={tmdb(prev.poster)}
              alt=""
              aria-hidden
              className="absolute top-4 left-0 h-[85%] w-[85%] -rotate-6 rounded-xl object-cover opacity-35 shadow-lg"
            />
            <img
              src={tmdb(next.poster)}
              alt=""
              aria-hidden
              className="absolute top-4 right-0 h-[85%] w-[85%] rotate-6 rounded-xl object-cover opacity-35 shadow-lg"
            />
            {REEL.map((item, i) => (
              <img
                key={item.id}
                src={tmdb(item.poster)}
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
              <div className="animate-play-pulse flex h-14 w-14 items-center justify-center rounded-full bg-brand text-[#0B0A0A] shadow-[0_0_32px_rgba(28,231,131,0.5)] sm:h-16 sm:w-16">
                <svg viewBox="0 0 24 24" className="h-6 w-6 fill-current sm:h-7 sm:w-7">
                  <path d="M8 5v14l11-7z" />
                </svg>
              </div>
            </div>
          </div>

          {/* Copy + progress */}
          <div className="flex min-w-0 flex-1 flex-col justify-between py-1 sm:py-2">
            <div>
              <p className="font-mono-ui flex items-center gap-2 text-[11px] uppercase tracking-[0.22em] text-brand sm:text-xs">
                <span className="animate-live-dot inline-block h-2 w-2 rounded-full bg-brand" />
                Now playing
              </p>
              <p
                key={current.id}
                className="font-disp animate-now-title mt-4 text-[clamp(28px,4vw,48px)] uppercase leading-[0.95] tracking-tight text-[#EDE6DA]"
              >
                {current.title}
              </p>
              <p className="mt-3 font-disp text-base uppercase tracking-wide text-[rgba(237,230,218,0.45)] sm:text-lg">
                {current.tag}
                <span className="mx-2 text-[rgba(237,230,218,0.25)]">·</span>
                Watch now
              </p>
            </div>

            <div className="mt-8 sm:mt-10">
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
                <span>No ads</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <PlatformDownloadButtons variant="links" className="mt-5" />
    </div>
  )
}
