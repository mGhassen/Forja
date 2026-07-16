import { Reveal } from '@/components/reveal'
import { cn } from '@/lib/utils'

type Hub = {
  id: string
  label: string
  line: string
  accent: 'brand' | 'flame'
  backdrop: string
}

/** Anime + Asian Drama only - other categories live in the “What you can watch” grid. */
const HUBS: Hub[] = [
  {
    id: 'anime',
    label: 'Anime',
    line: 'Series and movies',
    accent: 'flame',
    backdrop: '/brand/open-films/sprite-fright.jpg',
  },
  {
    id: 'asian',
    label: 'Asian Drama',
    line: 'Korean, Chinese, and more',
    accent: 'brand',
    backdrop: '/brand/open-films/tears-of-steel.jpg',
  },
]

function HubTile({ hub, index }: { hub: Hub; index: number }) {
  return (
    <article
      className={cn(
        'group relative isolate aspect-[5/4] overflow-hidden rounded-2xl border border-white/[0.1] bg-[#121110] sm:aspect-[16/9]',
        'hover-lift hover-zoom shadow-[0_28px_70px_-28px_rgba(0,0,0,0.9)]',
        'hover:border-white/20',
      )}
    >
      <img
        src={hub.backdrop}
        alt=""
        aria-hidden
        className="absolute inset-0 h-full w-full object-cover"
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

      <div className="absolute inset-x-0 bottom-0 z-[1] p-5 sm:p-6">
        <p
          className={cn(
            'font-mono-ui text-[10px] uppercase tracking-[0.2em]',
            hub.accent === 'flame' ? 'text-flame' : 'text-brand',
          )}
        >
          {hub.line}
        </p>
        <h3 className="font-disp mt-2 text-[clamp(28px,3.5vw,42px)] uppercase leading-[0.92] tracking-tight text-[#EDE6DA]">
          {hub.label}
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
          Anime and
          <br />
          <span className="text-flame">Asian drama.</span>
        </h2>
        <p className="mt-6 font-disp text-[clamp(20px,2.8vw,32px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]">
          <span className="text-[#EDE6DA]">Their own hubs in the app.</span>
        </p>
      </Reveal>

      <div className="mx-auto mt-12 grid max-w-[1400px] grid-cols-1 gap-4 sm:grid-cols-2 sm:gap-5 lg:gap-6">
        {HUBS.map((hub, i) => (
          <Reveal key={hub.id} delayMs={i * 60}>
            <HubTile hub={hub} index={i} />
          </Reveal>
        ))}
      </div>
    </section>
  )
}
