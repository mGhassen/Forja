import { Link } from '@tanstack/react-router'
import { Reveal } from '@/components/reveal'
import { SiteFooter } from '@/components/legal-shell'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'

const CATALOG_LINES = [
  'Featured heroes and poster shelves you can skim in seconds',
  'Title pages with episodes, related rows, and continue watching',
  'My List statuses and a navigation rail you can reshape',
]

const SOURCE_WAYS = [
  {
    title: 'Provider plugins',
    copy: 'The main path for movies, series, anime, and drama. Stream provider plugins resolve links. Enable the ones you want, use automatic resolve, or pin a server.',
  },
  {
    title: 'Torrents',
    copy: 'Search torrents and play magnets in the native player without waiting on a full download.',
  },
  {
    title: 'Stremio',
    copy: 'Stremio-compatible addons bring extra streams into Forja, including sport when the addon supports it.',
  },
  {
    title: 'Nuvio',
    copy: 'Nuvio scrapers add more stream links. Direct HTTP plays in place; magnets use the torrent engine.',
  },
]

const PLAYER_CHIPS = [
  'MediaKit & ExoPlayer',
  'Skip intro',
  'Auto next episode',
  'Subtitles & audio',
  'Picture-in-picture',
  'External players',
  'Switch sources mid-play',
]

const IPTV_LINES = [
  'Xtream Codes, M3U and M3U8, and Stalker portals',
  'Live channels beside portal movies and series',
  'Channel guide and search inside the live player',
]

const SPORT_MOODS = [
  { label: 'Football', src: '/brand/hubs/sport/football.jpg' },
  { label: 'Basketball', src: '/brand/hubs/sport/basketball.jpg' },
  { label: 'Tennis', src: '/brand/hubs/sport/tennis.jpg' },
  { label: 'Racing', src: '/brand/hubs/sport/racing.jpg' },
]

const MORE = [
  {
    title: 'Debrid',
    copy: 'Optional debrid unlocks cached torrents when you have an account with a provider.',
  },
  {
    title: 'Simkl',
    copy: 'Optional Simkl sync for My List and scrobble.',
  },
  {
    title: 'Backup',
    copy: 'Export and import settings, including IPTV portal lists.',
  },
  {
    title: 'Open source',
    copy: 'Forja is a modular player platform, open to inspect and extend. The community ships hubs, providers, and live modules as packs.',
  },
]

const FAQ = [
  {
    q: 'Does Forja include movies or channels?',
    a: 'No. Forja is a modular player platform. You connect your own sources and portals. Forja does not sell or host media files.',
  },
  {
    q: 'Which platforms are supported?',
    a: 'Windows, macOS, Linux, Android, Android TV, and iOS. Installers live on the Download page.',
  },
  {
    q: 'Do I need an account?',
    a: 'No. You can use Forja without signing in. An account is a settings store across devices: up to five profiles, sync, and device link for desktop and TV.',
  },
]

const MARQUEE = [
  'Movies',
  'Series',
  'Anime',
  'Providers',
  'Torrents',
  'Stremio',
  'Nuvio',
  'IPTV',
  'Live sport',
  'LAN',
  'Open source',
]

export function PlatformPage() {
  const marqueeItems = [...MARQUEE, ...MARQUEE]

  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="plugins" />
      <div className="relative z-10 flex min-h-screen flex-col">
        <SiteHeader solid />

        <main className="flex-1">
          <header id="top" className="relative px-[5vw] pb-12 pt-20 sm:pb-16 sm:pt-24 lg:pt-28">
            <div className="mx-auto max-w-[1100px]">
              <div className="hero-enter">
                <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
                  Open source · Modular · Every screen
                </p>
                <h1 className="mt-5 max-w-[18ch] font-disp text-[clamp(2.4rem,6vw,4.5rem)] uppercase leading-[0.92] tracking-[-0.04em]">
                  Open-source modular
                  <br />
                  <span className="font-serif-i normal-case text-flame">
                    player platform
                  </span>
                </h1>
                <p className="mt-6 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.65)] sm:text-lg">
                  Forja is a modular player platform for movies, series, anime,
                  live sport, and IPTV. Catalogs, provider plugins, torrents,
                  Stremio, Nuvio, portals, and LAN sit in one native app across
                  desktop, mobile, and TV.
                </p>
                <div className="mt-8 flex flex-wrap gap-3">
                  <Link
                    to="/download"
                    data-hover=""
                    className="btn-magnet inline-flex items-center justify-center rounded-full px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] shadow-[0_0_32px_rgba(28,231,131,0.35)]"
                  >
                    Download
                  </Link>
                  <a
                    href="#catalogs"
                    data-hover=""
                    className="inline-flex items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] text-[rgba(237,230,218,0.75)] transition hover:border-forja-flame/40 hover:text-forja-flame"
                  >
                    Explore
                  </a>
                </div>
              </div>
            </div>
          </header>

          <div className="overflow-hidden whitespace-nowrap border-b border-[rgba(237,230,218,0.14)] py-5">
            <div className="animate-marquee inline-flex w-max">
              {marqueeItems.map((w, i) => (
                <span key={`${w}-${i}`} className="inline-flex items-center">
                  <b className="font-serif-i px-[22px] text-[clamp(20px,3.2vw,36px)] text-[#EDE6DA]">
                    {w}
                  </b>
                  <span className="font-disp self-center px-1 text-[clamp(16px,2.2vw,28px)] text-flame">
                    ✦
                  </span>
                </span>
              ))}
            </div>
          </div>

          {/* Catalogs — full-bleed cinematic */}
          <section
            id="catalogs"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)]"
          >
            <div className="relative mx-auto max-w-[1400px] lg:min-h-[560px]">
              <div className="lg:absolute lg:inset-0">
                <img
                  src="/brand/forja-home-hero.jpg"
                  alt="Forja home with featured title and shelves"
                  width={1024}
                  height={643}
                  className="h-56 w-full object-cover sm:h-72 lg:h-full"
                  loading="lazy"
                  decoding="async"
                />
                <div className="pointer-events-none absolute inset-0 bg-gradient-to-r from-[#0c0b0a] via-[#0c0b0a]/85 to-transparent max-lg:hidden" />
                <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-[#0c0b0a] via-transparent to-transparent lg:hidden" />
              </div>
              <div className="relative px-[5vw] py-12 sm:py-16 lg:flex lg:min-h-[560px] lg:items-center lg:py-20">
                <Reveal className="max-w-lg">
                  <h2 className="font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                    A cinematic home for what is on next
                  </h2>
                  <p className="mt-5 text-base leading-relaxed text-[rgba(237,230,218,0.68)] sm:text-lg">
                    Forja opens on a featured title, rich posters, and shelves
                    that stay readable from a laptop to a living-room TV.
                  </p>
                  <ul className="mt-8 space-y-3 text-base leading-relaxed text-[rgba(237,230,218,0.78)]">
                    {CATALOG_LINES.map((line) => (
                      <li key={line} className="flex gap-3">
                        <span className="mt-2 size-1.5 shrink-0 rounded-full bg-flame" />
                        <span>{line}</span>
                      </li>
                    ))}
                  </ul>
                </Reveal>
              </div>
            </div>
          </section>

          {/* Sources — sticky label + stacked definitions */}
          <section
            id="sources"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24"
          >
            <div className="mx-auto grid max-w-[1200px] gap-12 lg:grid-cols-[minmax(0,0.42fr)_minmax(0,1fr)] lg:gap-20">
              <Reveal className="lg:sticky lg:top-28 lg:self-start">
                <p className="font-serif-i text-2xl text-flame sm:text-3xl">
                  Sources
                </p>
                <h2 className="mt-4 font-disp text-[clamp(28px,4vw,42px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Four ways to find a stream, one player
                </h2>
                <p className="mt-5 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                  Provider plugins come first for everyday webstreaming.
                  Torrents, Stremio, and Nuvio sit beside them. Switch sources
                  while a title is playing.
                </p>
              </Reveal>

              <div className="divide-y divide-[rgba(237,230,218,0.14)] border-y border-[rgba(237,230,218,0.14)]">
                {SOURCE_WAYS.map((item, i) => (
                  <Reveal key={item.title} delayMs={i * 40}>
                    <div className="py-8 sm:py-10">
                      <h3 className="font-serif-i text-[clamp(1.5rem,3vw,2.25rem)] leading-tight text-[#EDE6DA]">
                        {item.title}
                      </h3>
                      <p className="mt-3 max-w-xl text-base leading-relaxed text-[rgba(237,230,218,0.62)]">
                        {item.copy}
                      </p>
                    </div>
                  </Reveal>
                ))}
              </div>
            </div>
          </section>

          {/* Player — full-bleed shot, then chip strip */}
          <section
            id="player"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)]"
          >
            <div className="relative">
              <img
                src="/brand/forja-iptv-player.png"
                alt="Forja native player with playback controls"
                width={1024}
                height={640}
                className="max-h-[70vh] w-full object-cover object-top"
                loading="lazy"
                decoding="async"
              />
              <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-[#0c0b0a] via-[#0c0b0a]/40 to-transparent" />
              <div className="absolute inset-x-0 bottom-0 px-[5vw] pb-10 sm:pb-14">
                <Reveal className="mx-auto max-w-[900px]">
                  <h2 className="font-disp text-[clamp(28px,5vw,48px)] uppercase leading-[0.92] tracking-[-0.03em]">
                    One native player from first frame to last
                  </h2>
                  <p className="mt-4 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.75)] sm:text-lg">
                    Movies, series, live sport, and IPTV share the same player.
                    Engines, episodes, tracks, and sources stay with you for the
                    whole session.
                  </p>
                </Reveal>
              </div>
            </div>
            <div className="overflow-x-auto border-t border-[rgba(237,230,218,0.12)] bg-[#0f0e0d] px-[5vw] py-6 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
              <div className="mx-auto flex min-w-max max-w-[1200px] items-center gap-x-6 gap-y-3 sm:flex-wrap sm:justify-center sm:min-w-0">
                {PLAYER_CHIPS.map((chip, i) => (
                  <span key={chip} className="inline-flex items-center gap-6">
                    <span className="font-mono-ui text-[11px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.7)]">
                      {chip}
                    </span>
                    {i < PLAYER_CHIPS.length - 1 ? (
                      <span className="text-flame/70" aria-hidden>
                        ·
                      </span>
                    ) : null}
                  </span>
                ))}
              </div>
            </div>
          </section>

          {/* IPTV — type first, then edge-to-edge still */}
          <section
            id="iptv"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)]"
          >
            <div className="px-[5vw] pb-10 pt-16 sm:pb-12 sm:pt-24">
              <Reveal className="mx-auto max-w-[720px] text-center">
                <h2 className="font-disp text-[clamp(28px,4.5vw,48px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Portals, channels, and a guide in one place
                </h2>
                <p className="mt-5 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                  Connect the portals you already have. Browse live channels,
                  portal movies, and series without leaving Forja.
                </p>
              </Reveal>
              <div className="mx-auto mt-10 flex max-w-[900px] flex-col gap-4 sm:flex-row sm:justify-center sm:gap-0 sm:divide-x sm:divide-[rgba(237,230,218,0.16)]">
                {IPTV_LINES.map((line) => (
                  <p
                    key={line}
                    className="px-0 text-center text-sm leading-relaxed text-[rgba(237,230,218,0.72)] sm:flex-1 sm:px-6"
                  >
                    {line}
                  </p>
                ))}
              </div>
              <div className="mt-8 text-center">
                <Link
                  to="/iptv"
                  className="link-draw font-mono-ui inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
                >
                  IPTV
                </Link>
              </div>
            </div>
            <img
              src="/brand/forja-iptv-live.jpg"
              alt="Forja live TV channels"
              width={1024}
              height={637}
              className="h-auto w-full border-t border-[rgba(237,230,218,0.14)]"
              loading="lazy"
              decoding="async"
            />
          </section>

          {/* Sports — mosaic only, story in prose */}
          <section
            id="sports"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)]"
          >
            <div className="grid grid-cols-2 lg:grid-cols-4">
              {SPORT_MOODS.map((mood) => (
                <figure
                  key={mood.label}
                  className="group relative aspect-[3/4] overflow-hidden border-b border-r border-[rgba(237,230,218,0.12)] sm:aspect-[4/5]"
                >
                  <img
                    src={mood.src}
                    alt={mood.label}
                    className="h-full w-full object-cover transition duration-700 group-hover:scale-105"
                    loading="lazy"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent" />
                  <figcaption className="absolute inset-x-0 bottom-0 p-4 font-disp text-lg uppercase tracking-tight text-[#EDE6DA] sm:p-6 sm:text-xl">
                    {mood.label}
                  </figcaption>
                </figure>
              ))}
            </div>
            <div className="px-[5vw] py-14 sm:py-20">
              <Reveal className="mx-auto max-w-[720px]">
                <h2 className="font-disp text-[clamp(28px,4.5vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Today’s games. Watch them live.
                </h2>
                <p className="mt-6 text-base leading-relaxed text-[rgba(237,230,218,0.68)] sm:text-lg">
                  Browse what is airing and what is coming up by sport. Open a
                  match, choose a stream, and play it in Forja. If the game is
                  on one of your IPTV channels, you can watch that too.
                </p>
              </Reveal>
            </div>
          </section>

          {/* LAN — big device dialogue, no feature grid */}
          <section
            id="lan"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)] bg-[#0f0e0d] px-[5vw] py-16 sm:py-24"
          >
            <div className="mx-auto max-w-[1100px]">
              <Reveal>
                <div className="flex flex-col items-start gap-4 sm:flex-row sm:items-end sm:justify-between sm:gap-10">
                  <p className="font-disp text-[clamp(40px,8vw,88px)] uppercase leading-[0.9] tracking-[-0.04em] text-forja-green">
                    Desktop
                  </p>
                  <p
                    className="hidden font-mono-ui text-sm uppercase tracking-[0.3em] text-flame sm:block"
                    aria-hidden
                  >
                    ──→
                  </p>
                  <p className="font-disp text-[clamp(40px,8vw,88px)] uppercase leading-[0.9] tracking-[-0.04em] text-[#EDE6DA]">
                    TV
                  </p>
                </div>
                <h2 className="mt-10 max-w-[22ch] font-serif-i text-[clamp(1.6rem,3.5vw,2.4rem)] leading-snug text-[rgba(237,230,218,0.92)]">
                  Magnets on the TV. Torrents on the desktop.
                </h2>
                <div className="mt-8 grid gap-8 sm:grid-cols-2 sm:gap-14">
                  <p className="text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                    Forja on the PC listens on your Wi-Fi and keeps the torrent
                    engine warm. Phone and Android TV discover the desktop or
                    join with a short code. Pair once; every torrent night uses
                    that link.
                  </p>
                  <p className="text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                    Pick a magnet on the TV. The desktop downloads; the TV
                    plays. Leave the player and that download stops. HTTP
                    streams from Stremio and Nuvio still play on the phone or TV
                    when the desktop is offline.
                  </p>
                </div>
              </Reveal>
            </div>
          </section>

          {/* Sync — typography band, no image+copy clone */}
          <section
            id="sync"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-20 sm:py-28"
          >
            <Reveal className="mx-auto max-w-[820px] text-center">
              <p className="font-disp text-[clamp(72px,14vw,140px)] leading-none tracking-[-0.06em] text-forja-flame">
                5
              </p>
              <h2 className="mt-6 font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                Profiles on one account
              </h2>
              <p className="mx-auto mt-6 max-w-xl text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                You can use Forja without signing in. An account is a settings
                store across devices: each profile keeps its own preferences and
                syncs across desktop, phone, and TV. Device link pairs a
                computer with Android TV through the portal.
              </p>
            </Reveal>
          </section>

          {/* More — definition list */}
          <section className="border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24">
            <div className="mx-auto max-w-[1100px]">
              <Reveal>
                <h2 className="font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Also in the platform
                </h2>
              </Reveal>
              <dl className="mt-12 divide-y divide-[rgba(237,230,218,0.12)] border-y border-[rgba(237,230,218,0.12)]">
                {MORE.map((item, i) => (
                  <Reveal key={item.title} delayMs={(i % 4) * 40}>
                    <div className="grid gap-3 py-8 sm:grid-cols-[12rem_1fr] sm:gap-10">
                      <dt className="font-disp text-xl uppercase tracking-tight text-[#EDE6DA]">
                        {item.title}
                      </dt>
                      <dd className="text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                        {item.copy}
                      </dd>
                    </div>
                  </Reveal>
                ))}
              </dl>

              <Reveal delayMs={80}>
                <div className="mt-16 flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between sm:gap-12">
                  <div className="max-w-xl">
                    <h3 className="font-disp text-[clamp(24px,3.5vw,36px)] uppercase leading-[0.95] tracking-[-0.03em]">
                      Build packs for Forja
                    </h3>
                    <p className="mt-4 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                      Authors extend the modular player platform with hubs,
                      stream providers, live modules, and more. Ship a pack,
                      share the URL, and the catalog can install it.
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-3">
                    <Link
                      to="/plugins"
                      hash="build"
                      data-hover=""
                      className="btn-magnet inline-flex items-center justify-center rounded-full px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_28px_rgba(28,231,131,0.3)] sm:text-xs"
                    >
                      Build
                    </Link>
                    <Link
                      to="/plugins"
                      data-hover=""
                      className="inline-flex items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.7)] transition hover:border-forja-flame/40 hover:text-forja-flame sm:text-xs"
                    >
                      Packs
                    </Link>
                  </div>
                </div>
              </Reveal>
            </div>
          </section>

          <section className="border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24">
            <div className="mx-auto max-w-[640px]">
              <Reveal>
                <h2 className="font-serif-i text-[clamp(1.75rem,3vw,2.25rem)] leading-snug text-[#EDE6DA]">
                  Quick answers
                </h2>
              </Reveal>
              <div className="mt-12 space-y-10">
                {FAQ.map((item, i) => (
                  <Reveal key={item.q} delayMs={i * 40}>
                    <div>
                      <h3 className="text-base font-medium text-[#EDE6DA] sm:text-lg">
                        {item.q}
                      </h3>
                      <p className="mt-2 text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
                        {item.a}
                      </p>
                    </div>
                  </Reveal>
                ))}
              </div>
            </div>
          </section>

          <section className="relative overflow-hidden border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-20 sm:py-28">
            <div
              aria-hidden
              className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(28,231,131,0.08),transparent_55%)]"
            />
            <Reveal>
              <div className="relative mx-auto max-w-[900px] text-center">
                <h2 className="mx-auto max-w-[14ch] font-disp text-[clamp(32px,6vw,56px)] uppercase leading-[0.92] tracking-[-0.04em]">
                  Shape the night.
                  <br />
                  <span className="font-serif-i normal-case text-flame">
                    Press play.
                  </span>
                </h2>
                <p className="mx-auto mt-6 max-w-xl text-base leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-lg">
                  Catalogs, provider plugins, torrents, live sport, and IPTV in
                  one place. Browse community packs, or build the next one.
                </p>
                <div className="mt-10 flex flex-wrap items-center justify-center gap-3">
                  <Link
                    to="/download"
                    data-hover=""
                    className="btn-magnet inline-flex items-center justify-center rounded-full px-10 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] shadow-[0_0_32px_rgba(28,231,131,0.35)]"
                  >
                    Download
                  </Link>
                  <Link
                    to="/plugins"
                    data-hover=""
                    className="inline-flex items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-10 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] text-[rgba(237,230,218,0.75)] transition hover:border-forja-flame/40 hover:text-forja-flame"
                  >
                    Packs
                  </Link>
                  <Link
                    to="/plugins"
                    hash="build"
                    data-hover=""
                    className="inline-flex items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-10 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] text-[rgba(237,230,218,0.75)] transition hover:border-forja-green/40 hover:text-forja-green"
                  >
                    Build
                  </Link>
                </div>
              </div>
            </Reveal>
          </section>
        </main>

        <SiteFooter />
      </div>
    </div>
  )
}
