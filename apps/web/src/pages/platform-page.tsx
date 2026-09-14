import { Link } from '@tanstack/react-router'
import { Reveal } from '@/components/reveal'
import { SiteFooter } from '@/components/legal-shell'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'

const JUMP = [
  { href: '#platforms', label: 'Platforms' },
  { href: '#catalogs', label: 'Catalogs' },
  { href: '#webstreaming', label: 'Webstreaming' },
  { href: '#torrents', label: 'Torrents' },
  { href: '#player', label: 'Player' },
  { href: '#iptv', label: 'Live TV' },
  { href: '#sports', label: 'Sports' },
  { href: '#lan', label: 'LAN' },
  { href: '#sync', label: 'Sync' },
] as const

const STATS = [
  { value: '6', label: 'Desktop, mobile, and TV builds' },
  { value: '5', label: 'Profiles on one account' },
  { value: '1', label: 'Native player for every source' },
]

const PLATFORMS = [
  'Windows installer · macOS DMG for Apple Silicon and Intel · Linux AppImage',
  'Android phone and Android TV with a D-pad shell',
  'iOS build · the same account across devices',
]

const CATALOG_LINES = [
  'Featured heroes and poster shelves you can skim in seconds',
  'Title pages with episodes, related rows, and continue watching',
  'My List statuses and a navigation rail you can reshape',
]

const WEBSTREAM_LINES = [
  'Provider and resolver network for movies, series, anime, and drama',
  'Automatic resolve with the option to pin a server',
  'Links checked before they reach the player when possible',
]

const TORRENT_TRIO = [
  {
    n: '01',
    title: 'Torrents',
    copy: 'Search torrents and play magnets in the native player without waiting on a full download.',
  },
  {
    n: '02',
    title: 'Stremio',
    copy: 'Stremio-compatible addons bring extra streams into Forja, including sport when the addon supports it.',
  },
  {
    n: '03',
    title: 'Nuvio',
    copy: 'Nuvio scrapers add more stream links. Direct HTTP plays in place; magnets use the torrent engine.',
  },
]

const PLAYER_LINES = [
  'MediaKit and ExoPlayer where the platform allows, switchable while you watch',
  'Subtitles, audio tracks, quality, speed, and aspect',
  'Skip intro and credits, auto next episode, continue watching',
  'Picture-in-picture, desktop mini player, and external players such as VLC, mpv, and IINA',
  'Change torrent, Stremio, or Nuvio sources mid-session without leaving the player',
]

const IPTV_LINES = [
  'Xtream Codes, M3U and M3U8, and Stalker portals',
  'Live channels beside portal movies and series',
  'Channel guide and search inside the live player',
]

const SPORTS_LINES = [
  'Match schedules for the nights that matter',
  'Native stream playback in the same player as everything else',
  'Live TV channel matching when a broadcast sits on your portals',
]

const LAN_LINES = [
  'Desktop runs as a LAN server on the home network',
  'Phone and Android TV pair once with a short code',
  'Torrents on the TV pass through the paired desktop; direct streams still play on the device',
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
    copy: 'The host is open to inspect and extend. Modular by design.',
  },
]

const FAQ = [
  {
    q: 'Does Forja include movies or channels?',
    a: 'No. Forja is a player. You connect your own sources and portals. Forja does not sell or host media files.',
  },
  {
    q: 'Which platforms are supported?',
    a: 'Windows, macOS, Linux, Android, Android TV, and iOS. Installers live on the Download page.',
  },
  {
    q: 'Do I need an account?',
    a: 'No. Forja works offline. An account unlocks up to five profiles, sync, and device link for desktop and TV.',
  },
]

const MARQUEE = [
  'Movies',
  'Series',
  'Anime',
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
                    streaming player
                  </span>
                </h1>
                <p className="mt-6 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.65)] sm:text-lg">
                  Forja is a modular open-source player for movies, series,
                  anime, live sport, and IPTV. Catalogs, providers, torrents,
                  Stremio, Nuvio, portals, and LAN all sit in one native app
                  across desktop, mobile, and TV.
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
                    href="#map"
                    data-hover=""
                    className="inline-flex items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] text-[rgba(237,230,218,0.75)] transition hover:border-forja-flame/40 hover:text-forja-flame"
                  >
                    Explore
                  </a>
                </div>
              </div>
            </div>
          </header>

          <section
            id="map"
            className="sticky top-[4.25rem] z-30 scroll-mt-0 border-y border-[rgba(237,230,218,0.14)] bg-[#0c0b0a]/95 backdrop-blur-md sm:top-[4.75rem]"
          >
            <div className="mx-auto flex max-w-[1400px] gap-1 overflow-x-auto px-[5vw] py-3 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
              {JUMP.map((item) => (
                <a
                  key={item.href}
                  href={item.href}
                  data-hover=""
                  className="shrink-0 rounded-full px-4 py-2 font-mono-ui text-[10px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.55)] transition hover:bg-white/[0.06] hover:text-forja-green"
                >
                  {item.label}
                </a>
              ))}
            </div>
          </section>

          <section className="border-b border-[rgba(237,230,218,0.14)] bg-[#0f0e0d]">
            <div className="mx-auto grid max-w-[1400px] sm:grid-cols-3">
              {STATS.map((stat) => (
                <div
                  key={stat.value}
                  className="border-b border-[rgba(237,230,218,0.1)] px-[5vw] py-10 sm:border-b-0 sm:border-r sm:px-10 sm:last:border-r-0"
                >
                  <p className="font-disp text-[clamp(40px,6vw,64px)] uppercase leading-none tracking-tight text-forja-green">
                    {stat.value}
                  </p>
                  <p className="mt-3 max-w-xs text-sm leading-relaxed text-[rgba(237,230,218,0.55)]">
                    {stat.label}
                  </p>
                </div>
              ))}
            </div>
          </section>

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

          {/* 01 Platforms — sticky label + flowing list */}
          <section
            id="platforms"
            className="scroll-mt-32 border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24"
          >
            <div className="mx-auto grid max-w-[1200px] gap-10 lg:grid-cols-[0.7fr_1.3fr] lg:gap-16">
              <Reveal className="lg:sticky lg:top-24 lg:self-start">
                <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-flame">
                  01 / Platforms
                </p>
                <h2 className="mt-4 font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  One Forja on every screen
                </h2>
              </Reveal>
              <Reveal delayMs={80}>
                <p className="text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                  Native builds for desk, couch, and TV. Sign in and your
                  profiles travel with you.
                </p>
                <ul className="mt-10 space-y-0">
                  {PLATFORMS.map((line, i) => (
                    <li
                      key={line}
                      className="grid grid-cols-[3.5rem_1fr] gap-4 border-t border-[rgba(237,230,218,0.12)] py-6 last:border-b sm:grid-cols-[4.5rem_1fr]"
                    >
                      <span className="font-mono-ui text-[11px] uppercase tracking-[0.16em] text-forja-green">
                        {String(i + 1).padStart(2, '0')}
                      </span>
                      <span className="text-base leading-relaxed text-[rgba(237,230,218,0.78)] sm:text-lg">
                        {line}
                      </span>
                    </li>
                  ))}
                </ul>
              </Reveal>
            </div>
          </section>

          {/* 02 Catalogs — full-bleed image with overlay copy on large */}
          <section
            id="catalogs"
            className="scroll-mt-32 border-b border-[rgba(237,230,218,0.14)]"
          >
            <div className="relative mx-auto max-w-[1400px] lg:min-h-[520px]">
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
              <div className="relative px-[5vw] py-12 sm:py-16 lg:flex lg:min-h-[520px] lg:items-center lg:py-20">
                <Reveal className="max-w-lg">
                  <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
                    02 / Catalogs
                  </p>
                  <h2 className="mt-4 font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
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

          {/* 03 Webstreaming — huge number + diagonal feel via offset columns */}
          <section
            id="webstreaming"
            className="scroll-mt-32 border-b border-[rgba(237,230,218,0.14)] bg-[#121110] px-[5vw] py-16 sm:py-24"
          >
            <div className="mx-auto max-w-[1100px]">
              <Reveal>
                <div className="flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
                  <div>
                    <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-flame">
                      03 / Webstreaming
                    </p>
                    <h2 className="mt-4 max-w-[16ch] font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                      Providers and resolvers built into the app
                    </h2>
                  </div>
                  <p className="font-disp text-[clamp(64px,12vw,120px)] leading-none tracking-tight text-forja-green/25">
                    03
                  </p>
                </div>
                <p className="mt-6 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                  Forja resolves streams through a provider network for movies,
                  series, anime, and drama. Pick automatic resolve or stay on a
                  server you trust.
                </p>
              </Reveal>
              <div className="mt-14 grid gap-8 sm:grid-cols-3">
                {WEBSTREAM_LINES.map((line, i) => (
                  <Reveal key={line} delayMs={i * 70}>
                    <p className="font-mono-ui text-[10px] uppercase tracking-[0.18em] text-forja-green">
                      {String(i + 1).padStart(2, '0')}
                    </p>
                    <p className="mt-3 border-t border-[rgba(237,230,218,0.14)] pt-4 text-base leading-relaxed text-[rgba(237,230,218,0.75)]">
                      {line}
                    </p>
                  </Reveal>
                ))}
              </div>
            </div>
          </section>

          {/* 04 Torrents / Stremio / Nuvio — stacked full-width bands, not cards */}
          <section
            id="torrents"
            className="scroll-mt-32 border-b border-[rgba(237,230,218,0.14)]"
          >
            <div className="border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-14 sm:py-16">
              <div className="mx-auto max-w-[1100px]">
                <Reveal>
                  <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
                    04 / Torrents · Stremio · Nuvio
                  </p>
                  <h2 className="mt-4 max-w-[20ch] font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                    Three ways to find a stream, one player
                  </h2>
                  <p className="mt-5 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                    Torrents, Stremio addons, and Nuvio scrapers live beside each
                    other. Switch sources while a title is playing.
                  </p>
                </Reveal>
              </div>
            </div>
            {TORRENT_TRIO.map((item, i) => (
              <div
                key={item.title}
                className={
                  i % 2 === 0
                    ? 'border-b border-[rgba(237,230,218,0.1)] bg-[#0f0e0d] px-[5vw] py-12 sm:py-14'
                    : 'border-b border-[rgba(237,230,218,0.1)] px-[5vw] py-12 sm:py-14 last:border-b-0'
                }
              >
                <Reveal delayMs={i * 40}>
                  <div className="mx-auto grid max-w-[1100px] items-baseline gap-4 sm:grid-cols-[5rem_1fr_1.2fr] sm:gap-10">
                    <span className="font-disp text-4xl uppercase tracking-tight text-forja-flame sm:text-5xl">
                      {item.n}
                    </span>
                    <h3 className="font-disp text-2xl uppercase tracking-tight text-[#EDE6DA] sm:text-3xl">
                      {item.title}
                    </h3>
                    <p className="text-base leading-relaxed text-[rgba(237,230,218,0.65)] sm:text-lg">
                      {item.copy}
                    </p>
                  </div>
                </Reveal>
              </div>
            ))}
          </section>

          {/* 05 Player — dense checklist on dark */}
          <section
            id="player"
            className="scroll-mt-32 border-b border-[rgba(237,230,218,0.14)] bg-[#121110] px-[5vw] py-16 sm:py-24"
          >
            <div className="mx-auto max-w-[1100px]">
              <Reveal>
                <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-flame">
                  05 / Player
                </p>
                <h2 className="mt-4 max-w-[18ch] font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  A native player for long sessions
                </h2>
                <p className="mt-5 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                  Movies, series, live sport, and IPTV open in the same player
                  with the tools a real night of watching needs.
                </p>
              </Reveal>
              <div className="mt-12 columns-1 gap-x-12 sm:columns-2">
                {PLAYER_LINES.map((line, i) => (
                  <Reveal key={line} delayMs={(i % 3) * 40}>
                    <p className="mb-6 break-inside-avoid border-l-2 border-forja-green/40 pl-4 text-base leading-relaxed text-[rgba(237,230,218,0.75)]">
                      {line}
                    </p>
                  </Reveal>
                ))}
              </div>
            </div>
          </section>

          {/* 06 IPTV — image right, copy left */}
          <section
            id="iptv"
            className="scroll-mt-32 border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24"
          >
            <div className="mx-auto grid max-w-[1200px] items-center gap-12 lg:grid-cols-2 lg:gap-14">
              <Reveal variant="left">
                <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
                  06 / Live TV and IPTV
                </p>
                <h2 className="mt-4 font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Portals, channels, and a guide in one place
                </h2>
                <p className="mt-5 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                  Connect the portals you already have. Browse live channels,
                  portal movies, and series without leaving Forja.
                </p>
                <ul className="mt-8 space-y-4">
                  {IPTV_LINES.map((line) => (
                    <li
                      key={line}
                      className="border-l-2 border-forja-flame/50 pl-4 text-base leading-relaxed text-[rgba(237,230,218,0.75)]"
                    >
                      {line}
                    </li>
                  ))}
                </ul>
                <Link
                  to="/iptv"
                  className="link-draw font-mono-ui mt-10 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
                >
                  IPTV
                </Link>
              </Reveal>
              <Reveal variant="right">
                <img
                  src="/brand/forja-iptv-live.jpg"
                  alt="Forja live TV channels"
                  width={1024}
                  height={637}
                  className="h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]"
                  loading="lazy"
                  decoding="async"
                />
              </Reveal>
            </div>
          </section>

          {/* 07 Sports — centered statement */}
          <section
            id="sports"
            className="scroll-mt-32 border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-20 sm:py-28"
          >
            <div className="mx-auto max-w-[900px] text-center">
              <Reveal>
                <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-flame">
                  07 / Live Sports
                </p>
                <h2 className="mt-4 font-disp text-[clamp(28px,4.5vw,48px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Schedules and native play for match night
                </h2>
                <p className="mx-auto mt-6 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                  Browse the schedule, open a match, and watch in the same native
                  player as the rest of Forja.
                </p>
                <ul className="mx-auto mt-10 max-w-lg space-y-4 text-left text-base leading-relaxed text-[rgba(237,230,218,0.75)]">
                  {SPORTS_LINES.map((line) => (
                    <li key={line} className="flex gap-3">
                      <span className="mt-2 size-1.5 shrink-0 rounded-full bg-forja-green" />
                      <span>{line}</span>
                    </li>
                  ))}
                </ul>
              </Reveal>
            </div>
          </section>

          {/* 08 LAN — asymmetric two-column with oversized word */}
          <section
            id="lan"
            className="scroll-mt-32 overflow-hidden border-b border-[rgba(237,230,218,0.14)] bg-[#0f0e0d] px-[5vw] py-16 sm:py-24"
          >
            <div className="mx-auto max-w-[1200px]">
              <Reveal>
                <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
                  08 / LAN and passthrough
                </p>
                <div className="mt-4 flex flex-col gap-8 lg:flex-row lg:items-end lg:justify-between">
                  <h2 className="max-w-[14ch] font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                    Your desktop feeds the room
                  </h2>
                  <p
                    aria-hidden
                    className="font-disp text-[clamp(72px,18vw,180px)] leading-[0.8] tracking-tight text-forja-green/15"
                  >
                    LAN
                  </p>
                </div>
              </Reveal>
              <div className="mt-12 grid gap-10 lg:grid-cols-[1fr_1.1fr]">
                <Reveal delayMs={40}>
                  <p className="text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                    Pair once on the home network. The desktop runs the torrent
                    work so phones and Android TV can watch without doing the
                    heavy lifting alone.
                  </p>
                </Reveal>
                <Reveal delayMs={80}>
                  <ol className="space-y-6">
                    {LAN_LINES.map((line, i) => (
                      <li
                        key={line}
                        className="flex gap-5 border-t border-[rgba(237,230,218,0.12)] pt-5"
                      >
                        <span className="font-mono-ui text-[11px] uppercase tracking-[0.16em] text-flame">
                          {String(i + 1).padStart(2, '0')}
                        </span>
                        <span className="text-base leading-relaxed text-[rgba(237,230,218,0.75)]">
                          {line}
                        </span>
                      </li>
                    ))}
                  </ol>
                </Reveal>
              </div>
            </div>
          </section>

          {/* 09 Sync — image + copy */}
          <section
            id="sync"
            className="scroll-mt-32 border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24"
          >
            <div className="mx-auto grid max-w-[1200px] items-center gap-12 lg:grid-cols-2 lg:gap-14">
              <Reveal variant="left">
                <img
                  src="/brand/forja-iptv-desk.png"
                  alt="Forja on the desk with live and catalog shelves"
                  width={1024}
                  height={638}
                  className="h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]"
                  loading="lazy"
                  decoding="async"
                />
              </Reveal>
              <Reveal delayMs={80} variant="right">
                <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-flame">
                  09 / Profiles and sync
                </p>
                <h2 className="mt-4 font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Up to five profiles across your devices
                </h2>
                <p className="mt-5 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                  An account is optional. When you sign in, each profile keeps
                  its own preferences and syncs across desktop, phone, and TV.
                  Device link pairs a computer with Android TV through the
                  portal.
                </p>
              </Reveal>
            </div>
          </section>

          {/* More — definition list, not cards */}
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
            </div>
          </section>

          <section className="border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24">
            <div className="mx-auto max-w-[900px]">
              <Reveal>
                <h2 className="font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Quick answers
                </h2>
              </Reveal>
              <div className="mt-12 space-y-10">
                {FAQ.map((item, i) => (
                  <Reveal key={item.q} delayMs={i * 40}>
                    <div>
                      <h3 className="font-disp text-lg uppercase tracking-tight text-[#EDE6DA] sm:text-xl">
                        {item.q}
                      </h3>
                      <p className="mt-3 text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                        {item.a}
                      </p>
                    </div>
                  </Reveal>
                ))}
              </div>
            </div>
          </section>

          <section className="px-[5vw] py-20 text-center sm:py-28">
            <Reveal>
              <h2 className="mx-auto max-w-[16ch] font-disp text-[clamp(32px,6vw,56px)] uppercase leading-[0.92] tracking-[-0.04em]">
                Available for desktop, mobile, and TV
              </h2>
              <p className="mx-auto mt-6 max-w-xl text-base leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-lg">
                Forja is a modular open-source player. Builds are ready for
                Windows, macOS, Linux, and Android.
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
              </div>
            </Reveal>
          </section>
        </main>

        <SiteFooter />
      </div>
    </div>
  )
}
