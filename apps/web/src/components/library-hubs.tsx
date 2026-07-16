import { Reveal } from '@/components/reveal'
import { cn } from '@/lib/utils'

type Mood = {
  id: string
  label: string
  line: string
  accent: 'brand' | 'flame'
  /** Full-bleed visual — TMDB backdrop path or /brand/... */
  backdrop: string
  /** Optional logo chips for Live TV */
  logos?: { src: string; alt: string }[]
}

const tmdbBackdrop = (path: string) =>
  `https://image.tmdb.org/t/p/w780${path}`

function mediaSrc(path: string) {
  if (path.startsWith('/brand/')) return path
  return tmdbBackdrop(path)
}

/** Six moods — cinematic tiles (TMDB backdrops verified via API). */
const MOODS: Mood[] = [
  {
    id: 'movies',
    label: 'Movies',
    line: 'Blockbusters & more',
    accent: 'flame',
    backdrop: '/eZ239CUp1d6OryZEBPnO2n87gMG.jpg', // Dune: Part Two
  },
  {
    id: 'series',
    label: 'Series',
    line: 'Binge-worthy',
    accent: 'brand',
    backdrop: '/6Tb87q9Tog30F5AAHh1gyDT2Vve.jpg', // Shōgun
  },
  {
    id: 'anime',
    label: 'Anime',
    line: 'Worlds to explore',
    accent: 'flame',
    backdrop: '/3GQKYh6Trm8pxd2AypovoYQf4Ay.jpg', // Demon Slayer
  },
  {
    id: 'asian',
    label: 'Asian Drama',
    line: 'Stories that hit',
    accent: 'brand',
    backdrop: '/2meX1nMdScFOoV4370rqHWKmXhY.jpg', // Squid Game
  },
  {
    id: 'iptv',
    label: 'Live TV',
    line: 'On now',
    accent: 'flame',
    backdrop: '/brand/forja-iptv-live.jpg',
    logos: [
      { src: '/brand/hubs/tv/cnn.svg', alt: 'CNN' },
      { src: '/brand/hubs/tv/hbo.svg', alt: 'HBO' },
      { src: '/brand/hubs/tv/fox.svg', alt: 'FOX' },
      { src: '/brand/hubs/tv/sky.svg', alt: 'Sky' },
      { src: '/brand/hubs/tv/nbc.svg', alt: 'NBC' },
      { src: '/brand/hubs/tv/cbs.svg', alt: 'CBS' },
    ],
  },
  {
    id: 'sport',
    label: 'Live Sport',
    line: 'Never miss a game',
    accent: 'brand',
    backdrop: '/brand/hubs/sport/football.jpg',
  },
]

function MoodTile({ mood, index }: { mood: Mood; index: number }) {
  return (
    <article
      className={cn(
        'group relative isolate aspect-[5/4] overflow-hidden rounded-2xl border border-white/[0.1] bg-[#121110] sm:aspect-[4/3] lg:aspect-[5/4]',
        'shadow-[0_28px_70px_-28px_rgba(0,0,0,0.9)] transition duration-500',
        'hover:border-white/20 hover:shadow-[0_36px_90px_-24px_rgba(0,0,0,0.95)]',
      )}
    >
      <img
        src={mediaSrc(mood.backdrop)}
        alt=""
        aria-hidden
        className="absolute inset-0 h-full w-full object-cover transition duration-700 group-hover:scale-105"
        loading={index < 2 ? 'eager' : 'lazy'}
        decoding="async"
      />
      <div
        aria-hidden
        className="absolute inset-0"
        style={{
          background:
            'linear-gradient(180deg, rgba(11,10,10,0.15) 0%, rgba(11,10,10,0.35) 40%, rgba(11,10,10,0.92) 100%), linear-gradient(90deg, rgba(11,10,10,0.55) 0%, transparent 55%)',
        }}
      />

      {mood.logos ? (
        <div className="absolute inset-x-0 top-0 z-[1] flex flex-wrap justify-end gap-2 p-4 sm:p-5">
          {mood.logos.map((logo) => (
            <span
              key={logo.alt}
              className="flex h-8 w-8 items-center justify-center rounded-full bg-black/45 ring-1 ring-white/15 backdrop-blur-sm sm:h-9 sm:w-9"
            >
              <img
                src={logo.src}
                alt={logo.alt}
                className="h-[55%] w-[55%] object-contain brightness-0 invert"
                loading="lazy"
              />
            </span>
          ))}
        </div>
      ) : null}

      <div className="absolute inset-x-0 bottom-0 z-[1] p-5 sm:p-6">
        <p
          className={cn(
            'font-mono-ui text-[10px] uppercase tracking-[0.2em]',
            mood.accent === 'flame' ? 'text-flame' : 'text-brand',
          )}
        >
          {mood.line}
        </p>
        <h3 className="font-disp mt-2 text-[clamp(28px,3.5vw,42px)] uppercase leading-[0.92] tracking-tight text-[#EDE6DA]">
          {mood.label}
        </h3>
      </div>
    </article>
  )
}

export function LibraryHubs() {
  return (
    <section id="library" className="px-[5vw] py-[12vh]">
      <Reveal>
        <h2 className="max-w-[14ch] font-disp text-[clamp(36px,6vw,72px)] uppercase leading-[0.92] tracking-[-0.03em]">
          Pick a world.
          <br />
          <span className="text-flame">Disappear.</span>
        </h2>
        <p className="mt-6 font-disp text-[clamp(20px,2.8vw,32px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]">
          Six doors.
          <br />
          <span className="text-[#EDE6DA]">Which one tonight?</span>
        </p>
      </Reveal>

      <div className="mx-auto mt-12 grid max-w-[1400px] grid-cols-1 gap-4 sm:grid-cols-2 sm:gap-5 lg:grid-cols-3 lg:gap-6">
        {MOODS.map((mood, i) => (
          <Reveal key={mood.id} delayMs={(i % 3) * 60}>
            <MoodTile mood={mood} index={i} />
          </Reveal>
        ))}
      </div>
    </section>
  )
}
