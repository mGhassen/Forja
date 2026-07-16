import { useEffect, useState } from 'react'
import { Link } from '@tanstack/react-router'
import { cn } from '@/lib/utils'

/** CC BY Blender Foundation open movies used as demo artwork. */
const REEL = [
  {
    id: 'sintel',
    title: 'Sintel',
    tag: 'Open film demo',
    poster: '/brand/open-films/sintel.jpg',
    backdrop: '/brand/open-films/sintel.jpg',
  },
  {
    id: 'bbb',
    title: 'Big Buck Bunny',
    tag: 'Open film demo',
    poster: '/brand/open-films/big-buck-bunny.jpg',
    backdrop: '/brand/open-films/big-buck-bunny.jpg',
  },
  {
    id: 'tos',
    title: 'Tears of Steel',
    tag: 'Open film demo',
    poster: '/brand/open-films/tears-of-steel.jpg',
    backdrop: '/brand/open-films/tears-of-steel.jpg',
  },
  {
    id: 'cosmos',
    title: 'Cosmos Laundromat',
    tag: 'Open film demo',
    poster: '/brand/open-films/cosmos-laundromat.jpg',
    backdrop: '/brand/open-films/cosmos-laundromat.jpg',
  },
] as const

const CYCLE_MS = 4200

/** Demo artwork carousel for the landing download CTA. */
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
          <div className="absolute inset-0 bg-gradient-to-t from-[#0B0A0A] via-[#0B0A0A]/85 to-[#0B0A0A]/40" />
        </div>

        <div className="relative flex flex-col gap-5 p-5 sm:flex-row sm:gap-7 sm:p-8 lg:gap-8 lg:p-10">
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
          </div>

          <div className="flex min-w-0 flex-1 flex-col justify-between py-1 text-center sm:py-2 sm:text-left">
            <div>
              <p className="font-mono-ui text-[11px] uppercase tracking-[0.22em] text-brand sm:text-xs">
                Demo artwork
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
                Blender Foundation
              </p>
            </div>

            <div className="font-mono-ui mt-6 text-[11px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.38)] sm:mt-10 sm:text-xs">
              Free download · Windows · Mac · Linux · Android TV
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
