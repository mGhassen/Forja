import { Link } from '@tanstack/react-router'
import { BrandLogo } from '@/components/brand-logo'
import { CustomCursor } from '@/components/custom-cursor'
import { PlatformDownloadButtons } from '@/components/platform-download-buttons'
import { Reveal } from '@/components/reveal'
import { SiteHeader } from '@/components/site-header'

/** Player capabilities — from live IPTV feature docs (user-facing). */
const PLAYER_POWERS = [
  {
    title: 'Channel guide',
    copy: 'Flip groups and channels without leaving the picture — the guide lives inside the player.',
    accent: 'flame' as const,
  },
  {
    title: 'Find anything fast',
    copy: 'Search by name or category while you watch. Close it and you’re back in the stream.',
    accent: 'brand' as const,
  },
  {
    title: 'What’s on now',
    copy: 'See what’s playing and what’s next — with progress — when your list provides a guide.',
    accent: 'flame' as const,
  },
  {
    title: 'Live, films & series',
    copy: 'One player for live channels, movie night, and full seasons — switch the mood, keep the screen.',
    accent: 'brand' as const,
  },
  {
    title: 'Audio & subtitles',
    copy: 'Pick the track you need and load captions when the stream supports them.',
    accent: 'flame' as const,
  },
  {
    title: 'Your list. Your rules.',
    copy: 'Bring the channels you already have. Favorites stay on top. Add once — watch every night.',
    accent: 'brand' as const,
  },
]

const tmdbPoster = (path: string) => `https://image.tmdb.org/t/p/w342${path}`

const MODES = [
  {
    k: 'Live',
    v: 'Sports, news, and channels that never sleep.',
    accent: 'flame' as const,
    posters: [
      '/95BDrWmcfJDEa2WCfjmLgi67jhi.jpg',
      '/dR1Ju50iudrOh3YgfwkAU1g2HZe.jpg',
      '/cvsXj3I9Q2iyyIo95AecSd1tad7.jpg',
    ],
  },
  {
    k: 'Movies',
    v: 'Film night from the same player as the match.',
    accent: 'brand' as const,
    posters: [
      '/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg',
      '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
      '/H6vke7zGiuLsz4v4RPeReb9rsv.jpg',
    ],
  },
  {
    k: 'Series',
    v: 'Seasons ready when the live night ends.',
    accent: 'flame' as const,
    posters: [
      '/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg',
      '/c15BtJxCXMrISLVmysdsnZUPQft.jpg',
      '/dmo6TYuuJgaYinXBPjrgG9mB5od.jpg',
    ],
  },
]

const MARQUEE = [
  'Channel guide',
  'Search',
  'What’s on',
  'Live',
  'Movies',
  'Series',
  'Audio',
  'Subtitles',
  'No ads',
] as const

export function IptvPage() {
  return (
    <div className="film-grain relative bg-[#0B0A0A] text-[#EDE6DA]">
      <CustomCursor />
      <SiteHeader />

      <main className="relative pt-[5.5rem] sm:pt-24">
        <header className="relative overflow-hidden px-[5vw] pb-16 pt-10 lg:pb-24 lg:pt-14">
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0"
            style={{
              background:
                'radial-gradient(ellipse 60% 55% at 80% 35%, rgba(255,77,28,0.2), transparent 55%), radial-gradient(ellipse 45% 50% at 15% 60%, rgba(28,231,131,0.14), transparent 50%)',
            }}
          />

          <div className="relative z-[2] mx-auto grid max-w-[1400px] gap-12 lg:grid-cols-[1fr_1.05fr] lg:items-center">
            <div>
              <div className="mb-6 flex flex-wrap items-center gap-3">
                <span className="rounded-full border border-brand/40 bg-brand/10 px-3 py-1 font-mono-ui text-[10px] uppercase tracking-[0.16em] text-brand">
                  New IPTV Player
                </span>
              </div>

              <h1 className="font-disp text-[clamp(40px,7.5vw,96px)] uppercase leading-[0.88] tracking-[-0.04em]">
                The player
                <br />
                built for
                <br />
                <span className="font-serif-i normal-case text-flame">live.</span>
              </h1>

              <div className="mt-6 max-w-lg space-y-4 font-disp text-[clamp(18px,2.4vw,28px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]">
                <p>
                  Guide. Search. What’s on now.
                </p>
                <p>
                  <span className="text-[#EDE6DA]">
                    Movies &amp; series in the same player — free, no ads.
                  </span>
                </p>
              </div>

              <div className="mt-9">
                <PlatformDownloadButtons variant="pills" />
              </div>
            </div>

            <div className="relative" id="proof">
              <img
                src="/brand/forja-iptv-live.jpg"
                alt="Forja IPTV Player — live channels and categories"
                width={1024}
                height={637}
                className="h-auto w-full rounded-lg border border-white/10 shadow-[0_40px_100px_-20px_rgba(0,0,0,0.9)]"
                decoding="async"
              />
              <p className="font-mono-ui mt-4 text-[10px] uppercase tracking-[0.18em] text-[rgba(237,230,218,0.4)]">
                IPTV Player · live · films · series
              </p>
            </div>
          </div>
        </header>

        <div className="overflow-hidden border-y border-[rgba(237,230,218,0.14)] bg-[#0f0e0d] py-5">
          <div className="animate-marquee flex w-max gap-10 whitespace-nowrap px-4">
            {[...MARQUEE, ...MARQUEE].map((w, i) => (
              <span key={`${w}-${i}`} className="inline-flex items-center gap-3">
                <b className="font-serif-i text-[clamp(22px,3.5vw,40px)] text-[#EDE6DA]">
                  {w}
                </b>
                <span className={i % 2 === 0 ? 'text-brand' : 'text-flame'}>✦</span>
              </span>
            ))}
          </div>
        </div>

        {/* Player benefits */}
        <section className="px-[5vw] py-24 sm:py-28">
          <Reveal>
            <h2 className="max-w-[16ch] font-disp text-[clamp(32px,5vw,64px)] uppercase leading-[0.95] tracking-[-0.03em]">
              Why this player
              <br />
              <span className="text-flame">wins the night.</span>
            </h2>
            <p className="mt-5 max-w-2xl font-disp text-[clamp(18px,2.4vw,28px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.5)]">
              Built for live — then ready for the film.
            </p>
          </Reveal>

          <div className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {PLAYER_POWERS.map((p, i) => (
              <Reveal key={p.title} delayMs={(i % 3) * 70}>
                <article className="h-full rounded-2xl border border-[rgba(237,230,218,0.14)] bg-[#121110] p-7 transition-colors hover:border-brand/35">
                  <p
                    className={`font-mono-ui text-[10px] uppercase tracking-[0.2em] ${
                      p.accent === 'flame' ? 'text-flame' : 'text-brand'
                    }`}
                  >
                    Player
                  </p>
                  <h3 className="font-disp mt-4 text-[clamp(24px,3vw,32px)] uppercase leading-tight">
                    {p.title}
                  </h3>
                  <p className="mt-3 leading-relaxed text-[rgba(237,230,218,0.48)]">
                    {p.copy}
                  </p>
                </article>
              </Reveal>
            ))}
          </div>
        </section>

        {/* Catalog through the player */}
        <section className="border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-24">
          <Reveal>
            <h2 className="font-disp text-[clamp(28px,4.5vw,52px)] uppercase tracking-[-0.03em]">
              Three shelves.
              <br />
              <span className="text-brand">One player.</span>
            </h2>
            <p className="mt-4 max-w-xl font-disp text-[clamp(18px,2.2vw,26px)] uppercase leading-snug tracking-tight text-[rgba(237,230,218,0.5)]">
              Live. Movies. Series — open any of them without switching apps.
            </p>
          </Reveal>

          <div className="mt-14 grid gap-5 md:grid-cols-3">
            {MODES.map((mode, i) => (
              <Reveal key={mode.k} delayMs={i * 110}>
                <article
                  data-hover=""
                  className="group relative h-full overflow-hidden rounded-2xl border border-[rgba(237,230,218,0.14)] bg-[#121110] transition duration-500 hover:-translate-y-1.5 hover:border-brand/40 hover:shadow-[0_28px_60px_-28px_rgba(0,0,0,0.85)]"
                >
                  <div className="relative flex h-44 items-end justify-center gap-2 overflow-hidden bg-[#0B0A0A] px-5 pt-8 sm:h-52">
                    <div
                      aria-hidden
                      className="pointer-events-none absolute inset-0 opacity-70 transition duration-700 group-hover:opacity-100"
                      style={{
                        background:
                          mode.accent === 'flame'
                            ? 'radial-gradient(ellipse 70% 80% at 50% 100%, rgba(255,77,28,0.28), transparent 60%)'
                            : 'radial-gradient(ellipse 70% 80% at 50% 100%, rgba(28,231,131,0.22), transparent 60%)',
                      }}
                    />
                    {mode.posters.map((path, pi) => (
                      <div
                        key={path}
                        className="relative w-[30%] max-w-[6.5rem]"
                        style={{
                          transform: `rotate(${(pi - 1) * 6}deg) translateY(${Math.abs(pi - 1) * 6}px)`,
                          zIndex: pi === 1 ? 2 : 1,
                        }}
                      >
                        <div
                          className="transition duration-500 ease-out group-hover:-translate-y-2.5"
                          style={{ transitionDelay: `${pi * 45}ms` }}
                        >
                          <img
                            src={tmdbPoster(path)}
                            alt=""
                            aria-hidden
                            className="aspect-[2/3] w-full rounded-md object-cover shadow-lg transition duration-500 group-hover:brightness-110"
                            loading="lazy"
                            decoding="async"
                          />
                        </div>
                      </div>
                    ))}
                  </div>

                  <div className="border-t border-[rgba(237,230,218,0.1)] p-6">
                    <h3 className="font-disp text-[clamp(28px,3vw,40px)] uppercase leading-none">
                      {mode.k}
                    </h3>
                    <p className="mt-3 text-sm leading-relaxed text-[rgba(237,230,218,0.45)]">
                      {mode.v}
                    </p>
                  </div>
                </article>
              </Reveal>
            ))}
          </div>
        </section>

        {/* Screens + player close */}
        <section className="border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh]">
          <div className="mx-auto grid max-w-[1400px] items-center gap-10 lg:grid-cols-2 lg:gap-14">
            <Reveal>
              <h2 className="font-disp text-[clamp(32px,5vw,56px)] uppercase leading-[0.95]">
                Desk or couch.
                <br />
                <span className="text-flame">Same player.</span>
              </h2>
              <div className="mt-5 space-y-3 font-disp text-[clamp(18px,2.2vw,26px)] uppercase leading-snug tracking-tight text-[rgba(237,230,218,0.55)]">
                <p>Windows. Mac. Linux.</p>
                <p>
                  <span className="text-[#EDE6DA]">Android TV for the living room.</span>
                </p>
              </div>
              <PlatformDownloadButtons variant="row" className="mt-8 max-w-md" />
            </Reveal>
            <Reveal delayMs={60}>
              <img
                src="/brand/forja-iptv-live.jpg"
                alt="Forja IPTV Player on screen"
                width={1024}
                height={637}
                className="h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]"
                decoding="async"
              />
            </Reveal>
          </div>
        </section>

        <section className="px-[5vw] py-28 text-center">
          <Reveal>
            <h2 className="font-disp text-[clamp(40px,8vw,96px)] uppercase leading-[0.9] tracking-[-0.04em]">
              Press play
              <br />
              <span className="text-flame">on live.</span>
            </h2>
            <p className="mx-auto mt-6 max-w-lg font-disp text-[clamp(18px,2.4vw,28px)] uppercase leading-snug tracking-tight text-[rgba(237,230,218,0.5)]">
              Download Forja.
              <br />
              <span className="text-[#EDE6DA]">The IPTV Player is waiting.</span>
            </p>
            <div className="mt-10 flex flex-col items-center gap-6">
              <PlatformDownloadButtons variant="pills" className="justify-center" />
              <Link
                to="/"
                className="font-mono-ui inline-flex items-center px-4 py-2 text-[11px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.4)] transition-colors hover:text-[#EDE6DA]"
              >
                Home
              </Link>
            </div>
          </Reveal>
        </section>

        <footer className="border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-8">
          <div className="font-mono-ui flex flex-wrap items-center justify-between gap-4 text-[11px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.35)]">
            <BrandLogo to="/" imgClassName="h-5 w-auto" />
            <span>IPTV Player · Free · No ads</span>
            <Link to="/download" className="hover:text-brand">
              Downloads
            </Link>
          </div>
        </footer>
      </main>
    </div>
  )
}
