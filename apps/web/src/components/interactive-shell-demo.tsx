import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type PointerEvent as ReactPointerEvent,
  type ReactNode,
  type SVGProps,
} from 'react'
import { cn } from '@/lib/utils'

type MediaKind = 'film' | 'series'

type DemoTitle = {
  id: string
  title: string
  year: number
  kind: MediaKind
  rating: number
  genres: string[]
  overview: string
  poster: string
  backdrop: string
}

const tmdb = (path: string, size: 'w185' | 'w342' | 'w780' = 'w342') =>
  `https://image.tmdb.org/t/p/${size}${path}`

/** Verified TMDB paths (API-checked) */
const CATALOG: DemoTitle[] = [
  {
    id: 'dune2',
    title: 'Dune: Part Two',
    year: 2024,
    kind: 'film',
    rating: 8.5,
    genres: ['Sci-Fi', 'Adventure', 'Drama'],
    overview:
      'Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family.',
    poster: '/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg',
    backdrop: '/eZ239CUp1d6OryZEBPnO2n87gMG.jpg',
  },
  {
    id: 'shogun',
    title: 'Shōgun',
    year: 2024,
    kind: 'series',
    rating: 8.7,
    genres: ['Drama', 'History'],
    overview:
      'An English navigator becomes shipwrecked in Japan and ends up serving a powerful feudal lord.',
    poster: '/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg',
    backdrop: '/6Tb87q9Tog30F5AAHh1gyDT2Vve.jpg',
  },
  {
    id: 'oppenheimer',
    title: 'Oppenheimer',
    year: 2023,
    kind: 'film',
    rating: 8.3,
    genres: ['Drama', 'History'],
    overview:
      'The story of J. Robert Oppenheimer and the development of the atomic bomb during World War II.',
    poster: '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
    backdrop: '/neeNHeXjMF5fXoCJRsOmkNGC7q.jpg',
  },
  {
    id: 'fallout',
    title: 'Fallout',
    year: 2024,
    kind: 'series',
    rating: 8.4,
    genres: ['Sci-Fi', 'Adventure'],
    overview:
      'In a future decades after a nuclear war, a young woman leaves her vault home for the irradiated wasteland.',
    poster: '/c15BtJxCXMrISLVmysdsnZUPQft.jpg',
    backdrop: '/coaPCIqQBPUZsOnJcWZxhaORcDT.jpg',
  },
  {
    id: 'challengers',
    title: 'Challengers',
    year: 2024,
    kind: 'film',
    rating: 7.1,
    genres: ['Drama', 'Romance'],
    overview:
      'Tashi, a former tennis prodigy turned coach, turns a tournament into a high-stakes match of exes.',
    poster: '/H6vke7zGiuLsz4v4RPeReb9rsv.jpg',
    backdrop: '/tq8COKsI99Bivjd4CZIYVGoKcIx.jpg',
  },
  {
    id: 'the-bear',
    title: 'The Bear',
    year: 2022,
    kind: 'series',
    rating: 8.6,
    genres: ['Comedy', 'Drama'],
    overview:
      'A young chef from the fine-dining world returns to Chicago to run his family’s sandwich shop.',
    poster: '/eKfVzzEazSIjJMrw9ADa2x8ksLz.jpg',
    backdrop: '/aJtG4txtmiRHwAAqENQHZvBs6kY.jpg',
  },
]

/** SettingsService.defaultVisibleNavIds — exact labels from nav_config.dart */
const NAV = [
  { id: 'home', label: 'Home', icon: 'home' as const },
  { id: 'search', label: 'Search', icon: 'search' as const },
  { id: 'asian_drama', label: 'Asian Drama', icon: 'asian' as const },
  { id: 'anime', label: 'Anime', icon: 'anime' as const },
  { id: 'iptv', label: 'IPTV', icon: 'iptv' as const },
  { id: 'live_matches', label: 'Live Matches', icon: 'sport' as const },
  { id: 'mylist', label: 'My List', icon: 'list' as const },
]

type Filter = 'all' | 'films' | 'tv'
type IconName =
  | 'home'
  | 'search'
  | 'asian'
  | 'anime'
  | 'iptv'
  | 'sport'
  | 'list'
  | 'settings'
  | 'play'
  | 'info'

function Icon({
  name,
  className,
  ...rest
}: { name: IconName; className?: string } & SVGProps<SVGSVGElement>) {
  const props = {
    viewBox: '0 0 24 24',
    fill: 'currentColor',
    className: cn('h-[15px] w-[15px]', className),
    'aria-hidden': true as const,
    ...rest,
  }
  switch (name) {
    case 'home':
      return (
        <svg {...props}>
          <path d="M12 5.69l5 4.5V18h-2v-6H9v6H7v-7.81l5-4.5M12 3 2 12h3v8h6v-6h2v6h6v-8h3L12 3z" />
        </svg>
      )
    case 'search':
      return (
        <svg {...props}>
          <path d="M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z" />
        </svg>
      )
    case 'asian':
      // theater_comedy (masks)
      return (
        <svg {...props}>
          <path d="M2.5 10.5c0 3.04 2.46 5.5 5.5 5.5.95 0 1.84-.24 2.62-.67L9.5 14.2c-.45.2-.95.32-1.5.32-2.21 0-4-1.79-4-4s1.79-4 4-4c.55 0 1.05.12 1.5.32l1.12-1.13A5.47 5.47 0 0 0 8 5c-3.04 0-5.5 2.46-5.5 5.5zm7.5.5c-.55 0-1 .45-1 1s.45 1 1 1 1-.45 1-1-.45-1-1-1zm10.5-.5c0-3.04-2.46-5.5-5.5-5.5-.95 0-1.84.24-2.62.67l1.12 1.13c.45-.2.95-.32 1.5-.32 2.21 0 4 1.79 4 4s-1.79 4-4 4c-.55 0-1.05-.12-1.5-.32l-1.12 1.13c.78.43 1.67.67 2.62.67 3.04 0 5.5-2.46 5.5-5.5zM14 11c-.55 0-1 .45-1 1s.45 1 1 1 1-.45 1-1-.45-1-1-1zM12 17.5c-1.93 0-3.6-1.07-4.47-2.64h8.94C15.6 16.43 13.93 17.5 12 17.5z" />
        </svg>
      )
    case 'anime':
      // animation
      return (
        <svg {...props}>
          <path d="M11.88 3.47 12 3l.12.47C13.07 7.21 16.79 10.93 20.53 12L21 12.12l-.47.12c-3.74 1.07-7.46 4.79-8.53 8.53L12 21l-.12-.47C10.93 16.79 7.21 13.07 3.47 12L3 11.88l.47-.12C7.21 10.93 10.93 7.21 11.88 3.47zM12 6.24C10.64 8.66 8.66 10.64 6.24 12 8.66 13.36 10.64 15.34 12 17.76c1.36-2.42 3.34-4.4 5.76-5.76C15.34 10.64 13.36 8.66 12 6.24z" />
        </svg>
      )
    case 'iptv':
      return (
        <svg {...props}>
          <path d="M21 6h-7.59l3.29-3.29L16 2l-4 4-4-4-.71.71L10.59 6H3c-1.1 0-2 .89-2 2v12c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.11-.9-2-2-2zm0 14H3V8h18v12zM9 10v8l7-4z" />
        </svg>
      )
    case 'sport':
      // sports_soccer_outlined
      return (
        <svg {...props}>
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 3.3 3.12 2.26-.48 1.47-1.96-.4L12 11.1l-1.68-2.47-1.96.4-.48-1.47L11 5.3V4.01c.33-.01.66-.01 1 0V5.3zM7.24 7.76l.48 1.47-1.18 1.73H4.1C4.74 9.3 5.84 8.26 7.24 7.76zM4.01 13c.01-.33.01-.66 0-1h2.45l.68 2.1-1.68 1.68C4.77 14.98 4.27 14.04 4.01 13zm3.23 4.94 1.96-.4L11 14.1v2.72l-2.26 1.64c-.58-.36-1.1-.8-1.5-1.32v-.2zm5.52 1.52L11 17.18v-3.08l1.68 2.47 1.96.4c-.4.52-.92.96-1.5 1.32l.12.07zm3.68-2.76-1.68-1.68.68-2.1h2.45c-.01.33-.01.66 0 1-.26 1.04-.76 1.98-1.45 2.78zm1.63-5.04h-2.44L16.28 9.23l.48-1.47c1.4.5 2.5 1.54 3.14 2.9z" />
        </svg>
      )
    case 'list':
      return (
        <svg {...props}>
          <path d="M17 3H7c-1.1 0-2 .9-2 2v16l7-3 7 3V5c0-1.1-.9-2-2-2zm0 15-5-2.18L7 18V5h10v13z" />
        </svg>
      )
    case 'settings':
      return (
        <svg {...props}>
          <path d="M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.484.484 0 0 0-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6A3.6 3.6 0 1 1 12 8.4a3.6 3.6 0 0 1 0 7.2z" />
        </svg>
      )
    case 'play':
      return (
        <svg {...props}>
          <path d="M8 5v14l11-7z" />
        </svg>
      )
    case 'info':
      return (
        <svg {...props}>
          <path d="M11 7h2v2h-2V7zm0 4h2v6h-2v-6zm1-9C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z" />
        </svg>
      )
  }
}

function ShellScreen() {
  const [filter, setFilter] = useState<Filter>('all')
  const [heroId, setHeroId] = useState(CATALOG[0]!.id)
  const [dragX, setDragX] = useState(0)
  const [dragging, setDragging] = useState(false)
  const startX = useRef(0)
  const startY = useRef(0)
  const dragRef = useRef(0)
  const axis = useRef<'x' | 'y' | null>(null)
  const paused = useRef(false)

  const pool = useMemo(() => {
    if (filter === 'films') return CATALOG.filter((t) => t.kind === 'film')
    if (filter === 'tv') return CATALOG.filter((t) => t.kind === 'series')
    return CATALOG
  }, [filter])

  const hero = pool.find((t) => t.id === heroId) ?? pool[0] ?? CATALOG[0]!
  const featured = pool.slice(0, 5)
  const heroIndex = Math.max(
    0,
    pool.findIndex((t) => t.id === hero.id),
  )

  function setFilterAndHero(next: Filter) {
    setFilter(next)
    const nextPool =
      next === 'films'
        ? CATALOG.filter((t) => t.kind === 'film')
        : next === 'tv'
          ? CATALOG.filter((t) => t.kind === 'series')
          : CATALOG
    if (!nextPool.some((t) => t.id === heroId)) {
      setHeroId(nextPool[0]?.id ?? CATALOG[0]!.id)
    }
  }

  function goHero(delta: number) {
    if (pool.length === 0) return
    const next = (heroIndex + delta + pool.length) % pool.length
    setHeroId(pool[next]!.id)
  }

  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
    const id = window.setInterval(() => {
      if (paused.current || dragging) return
      setHeroId((current) => {
        const i = pool.findIndex((t) => t.id === current)
        const next = ((i >= 0 ? i : 0) + 1) % pool.length
        return pool[next]?.id ?? current
      })
    }, 5000)
    return () => window.clearInterval(id)
  }, [dragging, pool])

  function onPointerDown(e: ReactPointerEvent<HTMLDivElement>) {
    if (e.button !== 0) return
    const target = e.target as HTMLElement
    if (target.closest('button, a')) return
    paused.current = true
    setDragging(true)
    startX.current = e.clientX
    startY.current = e.clientY
    axis.current = null
    dragRef.current = 0
    setDragX(0)
    e.currentTarget.setPointerCapture(e.pointerId)
  }

  function onPointerMove(e: ReactPointerEvent<HTMLDivElement>) {
    if (!dragging) return
    const dx = e.clientX - startX.current
    const dy = e.clientY - startY.current
    if (axis.current === null && (Math.abs(dx) > 6 || Math.abs(dy) > 6)) {
      axis.current = Math.abs(dx) > Math.abs(dy) ? 'x' : 'y'
    }
    if (axis.current === 'x') {
      dragRef.current = dx
      setDragX(dx)
    }
  }

  function onPointerUp(e: ReactPointerEvent<HTMLDivElement>) {
    if (!dragging) return
    try {
      e.currentTarget.releasePointerCapture(e.pointerId)
    } catch {
      /* already released */
    }
    setDragging(false)
    const dx = dragRef.current
    if (axis.current === 'x') {
      if (dx <= -40) goHero(1)
      else if (dx >= 40) goHero(-1)
    }
    dragRef.current = 0
    setDragX(0)
    axis.current = null
    window.setTimeout(() => {
      paused.current = false
    }, 5000)
  }

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
                    : 'cursor-default text-white/35 hover:bg-white/[0.06] hover:text-white/80',
                )}
              >
                <Icon name={item.icon} />
              </span>
            )
          })}
        </nav>
        <span
          title="Settings"
          className="mb-0.5 flex h-7 w-7 cursor-default items-center justify-center rounded-md text-white/35 transition-colors hover:bg-white/[0.06] hover:text-white/80 sm:h-8 sm:w-8"
        >
          <Icon name="settings" />
        </span>
      </aside>

      <div className="relative min-w-0 flex-1 overflow-hidden">
        <div
          className="relative h-full touch-pan-y select-none"
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={onPointerUp}
          style={{
            transform: dragging ? `translateX(${dragX * 0.08}px)` : undefined,
            transition: dragging ? 'none' : 'transform 0.3s ease-out',
          }}
        >
          <img
            key={hero.id}
            src={tmdb(hero.backdrop, 'w780')}
            alt=""
            draggable={false}
            className="absolute inset-0 h-full w-full object-cover object-[center_20%]"
          />
          <div
            aria-hidden
            className="absolute inset-0"
            style={{
              background:
                'linear-gradient(90deg, #0B0A0A 0%, rgba(11,10,10,0.9) 32%, rgba(11,10,10,0.4) 58%, transparent 100%), linear-gradient(0deg, #0B0A0A 0%, transparent 38%), linear-gradient(180deg, rgba(11,10,10,0.55) 0%, transparent 28%)',
            }}
          />

          <div className="absolute inset-x-0 top-0 z-20 flex items-center gap-3 px-2.5 py-2 sm:gap-5 sm:px-3.5 sm:py-2.5">
            <button
              type="button"
              onClick={() => setFilterAndHero(filter === 'films' ? 'all' : 'films')}
              className={cn(
                'text-[9px] font-semibold tracking-wide sm:text-[10px]',
                filter === 'films' ? 'text-white' : 'text-white/55 hover:text-white/85',
              )}
            >
              Films
            </button>
            <button
              type="button"
              onClick={() => setFilterAndHero(filter === 'tv' ? 'all' : 'tv')}
              className={cn(
                'text-[9px] font-semibold tracking-wide sm:text-[10px]',
                filter === 'tv' ? 'text-white' : 'text-white/55 hover:text-white/85',
              )}
            >
              TV Shows
            </button>
            <span className="text-[9px] font-semibold tracking-wide text-white/55 sm:text-[10px]">
              Categories
            </span>
            <span className="ml-auto text-white/45">
              <Icon name="search" className="h-3.5 w-3.5" />
            </span>
          </div>

          <div className="relative z-[1] flex h-full max-w-[58%] flex-col justify-end px-2.5 pb-[4.75rem] pt-10 sm:max-w-[55%] sm:px-3.5 sm:pb-[5.5rem]">
            <h3 className="font-disp text-[clamp(14px,2.4vw,22px)] uppercase leading-[0.95] tracking-tight">
              {hero.title}
            </h3>
            <p className="mt-1 flex flex-wrap items-center gap-x-1.5 gap-y-0.5 text-[8px] text-white/65 sm:text-[9px]">
              <span className="text-amber-300">★ {hero.rating.toFixed(1)}</span>
              <span>·</span>
              <span>{hero.year}</span>
              <span>·</span>
              <span className="rounded border border-white/25 px-1 py-px text-[7px] uppercase tracking-wider sm:text-[8px]">
                {hero.kind === 'film' ? 'Film' : 'Series'}
              </span>
              <span className="hidden text-white/40 sm:inline">
                {hero.genres.slice(0, 2).join(' · ')}
              </span>
            </p>
            <p className="mt-1.5 line-clamp-2 text-[8px] leading-relaxed text-white/50 sm:text-[9px]">
              {hero.overview}
            </p>
            <div className="mt-2 flex items-center gap-1.5">
              <span className="inline-flex items-center gap-1 rounded-full bg-[#1CE783] px-2.5 py-1 text-[8px] font-bold text-[#0B0A0A] sm:text-[9px]">
                <Icon name="play" className="h-2.5 w-2.5" />
                Play
              </span>
              <span className="flex h-5 w-5 items-center justify-center rounded-full border border-white/20 bg-black/35 text-white/75 sm:h-6 sm:w-6">
                <Icon name="info" className="h-3 w-3" />
              </span>
              <span className="flex h-5 w-5 items-center justify-center rounded-full border border-white/20 bg-black/35 text-white/75 sm:h-6 sm:w-6">
                <Icon name="list" className="h-3 w-3" />
              </span>
            </div>
            <div className="mt-2.5 flex gap-1">
              {pool.slice(0, 6).map((item) => (
                <span
                  key={item.id}
                  className={cn(
                    'h-0.5 rounded-full transition-all',
                    item.id === hero.id ? 'w-4 bg-[#1CE783]' : 'w-1 bg-white/25',
                  )}
                />
              ))}
            </div>
          </div>

          <div className="absolute inset-x-0 bottom-0 z-[1] px-2 pb-2 sm:px-3 sm:pb-2.5">
            <p className="mb-1 text-[8px] font-semibold text-[#EDE6DA] sm:text-[9px]">
              Featured This Month
            </p>
            <div className="flex gap-1.5 overflow-hidden">
              {featured.map((item) => (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setHeroId(item.id)}
                  className={cn(
                    'relative w-[2.65rem] shrink-0 overflow-hidden rounded sm:w-12',
                    item.id === hero.id && 'ring-1 ring-[#1CE783]',
                  )}
                >
                  <img
                    src={tmdb(item.poster, 'w185')}
                    alt={item.title}
                    className="aspect-[2/3] w-full object-cover"
                    loading="lazy"
                    draggable={false}
                  />
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

function TvBezel({ children }: { children: ReactNode }) {
  return (
    <div className="mx-auto w-full max-w-[560px] sm:max-w-[640px] lg:max-w-[720px] xl:max-w-[800px]">
      <div className="rounded-[1.25rem] border border-white/12 bg-[#161412] p-[0.65rem] shadow-[0_50px_110px_-30px_rgba(0,0,0,0.95)] sm:rounded-[1.4rem] sm:p-3">
        <div className="overflow-hidden rounded-[0.8rem] border border-white/[0.08] bg-black sm:rounded-[1rem]">
          <div className="aspect-[16/10] w-full">{children}</div>
        </div>
      </div>
      <div className="mx-auto mt-0 flex w-[38%] flex-col items-center">
        <div className="h-3.5 w-[16%] bg-gradient-to-b from-[#2a2724] to-[#1a1816]" />
        <div className="h-2 w-full rounded-full bg-[#2a2724]" />
      </div>
    </div>
  )
}

/** TV mock of Forja Home for the landing hero. */
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
