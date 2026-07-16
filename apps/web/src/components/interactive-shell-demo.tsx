import { useEffect, useState, type ReactNode } from 'react'
import { cn } from '@/lib/utils'

/** Freely licensed Blender Foundation open movies (CC BY). See /brand/open-films/ATTRIBUTION.txt */
const OPEN_FILMS = [
  {
    poster: '/brand/open-films/big-buck-bunny.jpg',
    hero: '/brand/open-films/heroes/big-buck-bunny-hero.jpg',
    label: 'Big Buck Bunny',
  },
  {
    poster: '/brand/open-films/sintel.jpg',
    hero: '/brand/open-films/heroes/sintel-hero.jpg',
    label: 'Sintel',
  },
  {
    poster: '/brand/open-films/tears-of-steel.jpg',
    hero: '/brand/open-films/heroes/tears-of-steel-hero.jpg',
    label: 'Tears of Steel',
  },
  {
    poster: '/brand/open-films/sprite-fright.jpg',
    hero: '/brand/open-films/heroes/sprite-fright-hero.jpg',
    label: 'Sprite Fright',
  },
  {
    poster: '/brand/open-films/cosmos-laundromat.jpg',
    hero: '/brand/open-films/heroes/cosmos-laundromat-hero.jpg',
    label: 'Cosmos Laundromat',
  },
] as const

const HERO_CYCLE_MS = 4500

function Icon({
  name,
  className,
}: {
  name: 'home' | 'search' | 'iptv' | 'settings'
  className?: string
}) {
  const common = { className: cn('h-[15px] w-[15px]', className), fill: 'currentColor' as const }
  switch (name) {
    case 'home':
      return (
        <svg viewBox="0 0 24 24" {...common}>
          <path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z" />
        </svg>
      )
    case 'search':
      return (
        <svg viewBox="0 0 24 24" {...common}>
          <path d="M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z" />
        </svg>
      )
    case 'iptv':
      return (
        <svg viewBox="0 0 24 24" {...common}>
          <path d="M21 3H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h5v2h8v-2h5c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 14H3V5h18v12z" />
        </svg>
      )
    case 'settings':
      return (
        <svg viewBox="0 0 24 24" {...common}>
          <path d="M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.48.48 0 0 0-.48-.41h-3.84a.48.48 0 0 0-.48.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.49.49 0 0 0-.59.22L2.74 8.87a.48.48 0 0 0 .12.61l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.48-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32a.49.49 0 0 0-.12-.61l-2.03-1.58zM12 15.6A3.6 3.6 0 1 1 12 8.4a3.6 3.6 0 0 1 0 7.2z" />
        </svg>
      )
  }
}

const NAV = [
  { id: 'home', label: 'Home', icon: 'home' as const },
  { id: 'search', label: 'Search', icon: 'search' as const },
  { id: 'iptv', label: 'Live', icon: 'iptv' as const },
]

function ShellScreen() {
  const [activeIndex, setActiveIndex] = useState(0)
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
      setActiveIndex((i) => (i + 1) % OPEN_FILMS.length)
    }, HERO_CYCLE_MS)
    return () => window.clearInterval(id)
  }, [reduced])

  const hero = OPEN_FILMS[activeIndex]!

  return (
    <div className="flex h-full min-h-0 bg-[#0B0A0A] text-[#EDE6DA]">
      <aside className="flex w-9 shrink-0 flex-col items-center border-r border-white/[0.06] py-2 sm:w-10">
        <img
          src="/brand/logo-dark.svg"
          alt=""
          className="mb-2 h-3.5 w-auto max-w-[36px] object-contain sm:h-4 sm:max-w-[42px]"
        />
        <nav className="flex flex-1 flex-col items-center gap-0.5" aria-label="Forja navigation">
          {NAV.map((item) => {
            const selected = item.id === 'home'
            return (
              <span
                key={item.id}
                title={item.label}
                aria-current={selected ? 'page' : undefined}
                className={cn(
                  'flex h-7 w-7 items-center justify-center rounded-md transition-colors sm:h-8 sm:w-8',
                  selected
                    ? 'bg-white/[0.08] text-[#1CE783]'
                    : 'cursor-default text-white/35',
                )}
              >
                <Icon name={item.icon} />
              </span>
            )
          })}
        </nav>
        <span
          title="Settings"
          className="mb-0.5 flex h-7 w-7 cursor-default items-center justify-center rounded-md text-white/35 sm:h-8 sm:w-8"
        >
          <Icon name="settings" />
        </span>
      </aside>

      <div className="relative min-w-0 flex-1 overflow-hidden">
        <div className="absolute inset-0 overflow-hidden">
          <div
            className={cn(
              'flex h-full',
              reduced ? '' : 'transition-transform duration-700 ease-[cubic-bezier(0.4,0,0.2,1)]',
            )}
            style={{ transform: `translateX(-${activeIndex * 100}%)` }}
          >
            {OPEN_FILMS.map((film) => (
              <img
                key={film.hero}
                src={film.hero}
                alt=""
                className="h-full min-w-full shrink-0 object-cover object-center"
              />
            ))}
          </div>
        </div>
        <div
          aria-hidden
          className="absolute inset-0 z-[1]"
          style={{
            background:
              'linear-gradient(90deg, #0B0A0A 0%, rgba(11,10,10,0.9) 32%, rgba(11,10,10,0.4) 58%, transparent 100%), linear-gradient(0deg, #0B0A0A 0%, transparent 38%), linear-gradient(180deg, rgba(11,10,10,0.55) 0%, transparent 28%)',
          }}
        />

        <div className="absolute inset-x-0 top-0 z-20 flex items-center gap-3 px-2.5 py-2 sm:gap-5 sm:px-3.5 sm:py-2.5">
          <span className="text-[9px] font-semibold tracking-wide text-white sm:text-[10px]">
            Home
          </span>
          <span className="text-[9px] font-semibold tracking-wide text-white/55 sm:text-[10px]">
            Live
          </span>
          <span className="text-[9px] font-semibold tracking-wide text-white/55 sm:text-[10px]">
            Library
          </span>
          <span className="ml-auto text-white/45">
            <Icon name="search" className="h-3.5 w-3.5" />
          </span>
        </div>

        <div className="relative z-[2] flex h-full max-w-[58%] flex-col justify-end px-2.5 pb-[4.75rem] pt-10 sm:max-w-[55%] sm:px-3.5 sm:pb-[5.5rem]">
          <h3
            key={hero.hero}
            className={cn(
              'font-disp text-[clamp(14px,2.4vw,22px)] uppercase leading-[0.95] tracking-tight',
              !reduced && 'animate-now-title',
            )}
          >
            {hero.label}
          </h3>
          <p className="mt-1 text-[8px] text-white/65 sm:text-[9px]">
            Open movie · Blender Foundation
          </p>
          <p className="mt-2 line-clamp-2 text-[8px] leading-snug text-white/50 sm:text-[9px]">
            Connect a playlist and press Play.
          </p>
          <div className="mt-3 flex gap-2">
            <span className="rounded-full bg-[#1CE783] px-2.5 py-1 text-[8px] font-bold uppercase tracking-wider text-[#0B0A0A]">
              Play
            </span>
            <span className="rounded-full border border-white/20 px-2.5 py-1 text-[8px] font-semibold uppercase tracking-wider text-white/70">
              Details
            </span>
          </div>
        </div>

        <div className="absolute inset-x-0 bottom-0 z-[2] px-2 pb-2 sm:px-3 sm:pb-2.5">
          <p className="mb-1.5 text-[8px] font-semibold uppercase tracking-[0.14em] text-white/45">
            Featured
          </p>
          <div className="flex gap-1.5 overflow-hidden">
            {OPEN_FILMS.map((item, i) => {
              const selected = i === activeIndex
              return (
                <button
                  key={item.poster}
                  type="button"
                  aria-label={`Show ${item.label}`}
                  aria-current={selected ? 'true' : undefined}
                  onClick={() => setActiveIndex(i)}
                  className={cn(
                    'relative aspect-[2/3] w-[18%] min-w-[2.4rem] overflow-hidden rounded-md ring-1 transition duration-300',
                    selected
                      ? 'z-[1] scale-[1.06] ring-[#1CE783]/80'
                      : 'ring-white/10 opacity-75 hover:opacity-100',
                  )}
                >
                  <img
                    src={item.poster}
                    alt=""
                    className="absolute inset-0 h-full w-full object-cover"
                  />
                  <span className="absolute inset-x-0 bottom-0 bg-black/55 px-0.5 py-0.5 text-center text-[5px] font-semibold uppercase leading-tight tracking-wide text-white/85 sm:text-[6px]">
                    {item.label}
                  </span>
                </button>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}

function TvBezel({ children }: { children: ReactNode }) {
  return (
    <div className="relative mx-auto w-full max-w-[760px]">
      <div className="rounded-[1.1rem] border border-white/15 bg-[#1a1816] p-[0.55rem] shadow-[0_40px_100px_-24px_rgba(0,0,0,0.95)] sm:rounded-[1.35rem] sm:p-[0.7rem]">
        <div className="overflow-hidden rounded-[0.75rem] border border-white/8 bg-black sm:rounded-[0.95rem]">
          <div className="aspect-[16/10] w-full">{children}</div>
        </div>
      </div>
    </div>
  )
}

/** TV mock of Forja Home for the landing hero - CC BY open-film posters. */
export function HeroTvMock({ className }: { className?: string }) {
  return (
    <div className={cn(className)}>
      <TvBezel>
        <ShellScreen />
      </TvBezel>
    </div>
  )
}

export const InteractiveShellDemo = HeroTvMock
