import { Link } from '@tanstack/react-router'
import { LanFluxBus } from '@/components/lan-flux-bus'
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
    n: '01',
    title: 'Provider plugins',
    copy: 'The main path for movies, series, anime, and drama. Stream provider plugins resolve links. Enable the ones you want, use automatic resolve, or pin a server.',
  },
  {
    n: '02',
    title: 'Torrents',
    copy: 'Search torrents and play magnets in the native player without waiting on a full download.',
  },
  {
    n: '03',
    title: 'Stremio',
    copy: 'Stremio-compatible addons bring extra streams into Forja, including sport when the addon supports it.',
  },
  {
    n: '04',
    title: 'Nuvio',
    copy: 'Nuvio scrapers add more stream links. Direct HTTP plays in place; magnets use the torrent engine.',
  },
]

const PLAYER_FEATURES = [
  {
    title: 'Engines',
    copy: 'MediaKit and ExoPlayer where the platform allows. Switch engines while the title is open.',
  },
  {
    title: 'Series',
    copy: 'Skip intro and credits, auto next episode, and resume from where you stopped.',
  },
  {
    title: 'Tracks',
    copy: 'Subtitles, audio, quality, speed, and aspect from compact menus on the player.',
  },
  {
    title: 'Chrome',
    copy: 'Picture-in-picture, desktop mini player, and handoff to VLC, mpv, or IINA.',
  },
  {
    title: 'Sources',
    copy: 'Change provider plugins, torrents, Stremio, or Nuvio without leaving playback.',
  },
]

const IPTV_LINES = [
  'Xtream Codes, M3U and M3U8, and Stalker portals',
  'Live channels beside portal movies and series',
  'Channel guide and search inside the live player',
]

const SPORT_FEATURES = [
  {
    title: 'Schedule',
    copy: 'See what is airing and what is coming up. Filter by sport, search, and switch list or card views.',
  },
  {
    title: 'Streams',
    copy: 'Open a match and pick from stream options as they appear for that game.',
  },
  {
    title: 'Your channels',
    copy: 'If the game is on one of your IPTV channels, you can watch that too.',
  },
  {
    title: 'Native play',
    copy: 'The match opens in Forja’s live player — the same player as IPTV.',
  },
]

const LAN_FEATURES = [
  {
    title: 'Desktop server',
    copy: 'Forja on the PC listens on your Wi-Fi and keeps the torrent engine warm for the house.',
  },
  {
    title: 'Pair once',
    copy: 'Phone and Android TV discover the desktop or join with a short code. Same trust for every title after that.',
  },
  {
    title: 'Torrent passthrough',
    copy: 'Pick a magnet on the TV. The desktop downloads; the TV plays. Leave the player and that download stops.',
  },
  {
    title: 'Direct streams',
    copy: 'HTTP streams from Stremio and Nuvio still play on the phone or TV when the desktop is offline.',
  },
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
    q: 'What do I need before the first play?',
    a: 'Download Forja, then add packs or sources. Provider plugins, torrents, Stremio, Nuvio, and IPTV portals are how titles and channels get into the app. Forja does not ship a built-in movie or channel catalog.',
  },
  {
    q: 'What are community packs?',
    a: 'Packs are installable modules: hubs for anime or live sport, stream providers, torrent search, and more. Pick a ready-made set on the Packs page or add a pack URL to your profile.',
  },
  {
    q: 'Can the TV play magnets without downloading on the TV?',
    a: 'Yes. Pair the TV or phone with a desktop on the same Wi-Fi. Magnets open on the PC; the living-room screen plays the stream. HTTP streams still play on the TV when the desktop is offline.',
  },
  {
    q: 'What does an account actually do?',
    a: 'Nothing required for playback. Sign in if you want up to five profiles, settings sync across devices, and device link for desktop and Android TV.',
  },
]

export function PlatformPage() {
  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="plugins" />
      <div className="relative z-10 flex min-h-screen flex-col">
        <SiteHeader solid />

        <main className="flex-1">
          <header id="top" className="relative px-[5vw] pb-14 pt-20 sm:pb-20 sm:pt-24 lg:pt-28">
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

          {/* Catalogs — text only */}
          <section
            id="catalogs"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24"
          >
            <Reveal className="mx-auto max-w-[720px]">
              <h2 className="font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                A cinematic home for what is on next
              </h2>
              <p className="mt-5 text-base leading-relaxed text-[rgba(237,230,218,0.68)] sm:text-lg">
                Forja opens on a featured title, rich posters, and shelves that
                stay readable from a laptop to a living-room TV.
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
          </section>

          {/* Sources — sticky + stacked full copy */}
          <section
            id="sources"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)] bg-[#0f0e0d] px-[5vw] py-16 sm:py-24"
          >
            <div className="mx-auto grid max-w-[1200px] gap-12 lg:grid-cols-[minmax(0,0.4fr)_minmax(0,1fr)] lg:gap-16">
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
                    <div className="grid gap-3 py-9 sm:grid-cols-[4rem_1fr] sm:gap-8">
                      <span className="font-disp text-3xl uppercase tracking-tight text-forja-green sm:text-4xl">
                        {item.n}
                      </span>
                      <div>
                        <h3 className="font-disp text-2xl uppercase tracking-tight text-[#EDE6DA] sm:text-3xl">
                          {item.title}
                        </h3>
                        <p className="mt-3 max-w-xl text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                          {item.copy}
                        </p>
                      </div>
                    </div>
                  </Reveal>
                ))}
              </div>
            </div>
          </section>

          {/* Player — headline + feature rail */}
          <section
            id="player"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)]"
          >
            <div className="px-[5vw] pt-16 sm:pt-24">
              <Reveal className="mx-auto max-w-[900px]">
                <h2 className="font-disp text-[clamp(28px,5vw,48px)] uppercase leading-[0.92] tracking-[-0.03em]">
                  One native player from first frame to last
                </h2>
                <p className="mt-5 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                  Movies, series, live sport, and IPTV share the same player.
                  Engines, episodes, tracks, and sources stay with you for the
                  whole session.
                </p>
              </Reveal>
            </div>

            <div className="mt-12 overflow-x-auto border-t border-[rgba(237,230,218,0.12)] bg-[#0f0e0d] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
              <div className="mx-auto flex min-w-max max-w-[1400px] divide-x divide-[rgba(237,230,218,0.12)]">
                {PLAYER_FEATURES.map((item) => (
                  <article
                    key={item.title}
                    className="w-[min(78vw,260px)] shrink-0 px-[5vw] py-12 sm:w-[240px] sm:px-9 sm:py-14 lg:w-[260px]"
                  >
                    <h3 className="font-disp text-xl uppercase tracking-tight text-[#EDE6DA] sm:text-2xl">
                      {item.title}
                    </h3>
                    <p className="mt-3 text-sm leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-base">
                      {item.copy}
                    </p>
                  </article>
                ))}
              </div>
            </div>
          </section>

          {/* IPTV — centered text */}
          <section
            id="iptv"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24"
          >
            <Reveal className="mx-auto max-w-[720px] text-center">
              <h2 className="font-disp text-[clamp(28px,4.5vw,48px)] uppercase leading-[0.95] tracking-[-0.03em]">
                Portals, channels, and a guide in one place
              </h2>
              <p className="mt-5 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                Connect the portals you already have. Browse live channels,
                portal movies, and series without leaving Forja.
              </p>
              <ul className="mt-10 space-y-4 text-left sm:text-center">
                {IPTV_LINES.map((line) => (
                  <li
                    key={line}
                    className="border-l-2 border-forja-flame/50 pl-4 text-base leading-relaxed text-[rgba(237,230,218,0.75)] sm:border-l-0 sm:pl-0"
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
          </section>

          {/* Sports — split type + numbered steps */}
          <section
            id="sports"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)]"
          >
            <div className="mx-auto grid max-w-[1200px] gap-12 px-[5vw] py-16 sm:py-24 lg:grid-cols-[0.85fr_1.15fr] lg:gap-20 lg:items-end">
              <Reveal variant="left">
                <ul className="space-y-1 font-serif-i text-[clamp(1.75rem,4vw,2.75rem)] leading-[1.05] text-[rgba(237,230,218,0.22)]">
                  <li className="text-[#EDE6DA]">Football</li>
                  <li>Basketball</li>
                  <li>Tennis</li>
                  <li>Racing</li>
                  <li className="text-flame/70">and more</li>
                </ul>
              </Reveal>
              <Reveal delayMs={60} variant="right">
                <h2 className="font-disp text-[clamp(28px,4.5vw,48px)] uppercase leading-[0.92] tracking-[-0.03em]">
                  Today’s games.
                  <br />
                  <span className="font-serif-i normal-case text-flame">
                    Watch them live.
                  </span>
                </h2>
                <p className="mt-6 max-w-lg text-base leading-relaxed text-[rgba(237,230,218,0.65)] sm:text-lg">
                  Browse what is airing and what is coming up by sport. Open a
                  match, choose a stream, and play it in Forja. If the game is
                  on one of your IPTV channels, you can watch that too.
                </p>
              </Reveal>
            </div>

            <ol className="mx-auto grid max-w-[1200px] border-t border-[rgba(237,230,218,0.12)] sm:grid-cols-2 lg:grid-cols-4">
              {SPORT_FEATURES.map((item, i) => (
                <li
                  key={item.title}
                  className="border-b border-[rgba(237,230,218,0.1)] px-[5vw] py-10 sm:border-r sm:px-8 sm:py-12 lg:border-b-0 lg:px-8"
                >
                  <span className="font-mono-ui text-[10px] uppercase tracking-[0.18em] text-forja-green">
                    {String(i + 1).padStart(2, '0')}
                  </span>
                  <h3 className="font-disp mt-3 text-lg uppercase tracking-tight text-[#EDE6DA] sm:text-xl">
                    {item.title}
                  </h3>
                  <p className="mt-2 text-sm leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-base">
                    {item.copy}
                  </p>
                </li>
              ))}
            </ol>
          </section>

          {/* LAN — flux bus + definition list */}
          <section
            id="lan"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24"
          >
            <div className="mx-auto max-w-[1100px]">
              <Reveal>
                <LanFluxBus />
                <h2 className="mt-10 max-w-[22ch] font-serif-i text-[clamp(1.6rem,3.5vw,2.4rem)] leading-snug text-[rgba(237,230,218,0.92)]">
                  Magnets on the TV. Torrents on the desktop.
                </h2>
                <p className="mt-5 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                  Forja pairs Android TV and phones with a desktop on the same
                  Wi-Fi. Magnets open on the PC; the living-room screen plays
                  the stream. Pair once, then every torrent night uses that
                  link.
                </p>
              </Reveal>

              <dl className="mt-12 divide-y divide-[rgba(237,230,218,0.12)] border-y border-[rgba(237,230,218,0.12)]">
                {LAN_FEATURES.map((item) => (
                  <div
                    key={item.title}
                    className="grid gap-3 py-8 sm:grid-cols-[14rem_1fr] sm:gap-10"
                  >
                    <dt className="font-disp text-lg uppercase tracking-tight text-[#EDE6DA] sm:text-xl">
                      {item.title}
                    </dt>
                    <dd className="text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                      {item.copy}
                    </dd>
                  </div>
                ))}
              </dl>
            </div>
          </section>

          {/* Sync */}
          <section
            id="sync"
            className="scroll-mt-28 border-b border-[rgba(237,230,218,0.14)] bg-[#0f0e0d] px-[5vw] py-20 sm:py-28"
          >
            <div className="mx-auto grid max-w-[1100px] items-center gap-10 lg:grid-cols-[auto_1fr] lg:gap-16">
              <p className="font-disp text-[clamp(96px,18vw,180px)] leading-none tracking-[-0.06em] text-forja-flame">
                5
              </p>
              <div>
                <h2 className="font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Profiles on one account
                </h2>
                <p className="mt-5 max-w-xl text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                  You can use Forja without signing in. An account is a settings
                  store across devices: each profile keeps its own preferences
                  and syncs across desktop, phone, and TV. Device link pairs a
                  computer with Android TV through the portal.
                </p>
              </div>
            </div>
          </section>

          {/* More */}
          <section className="border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24">
            <div className="mx-auto max-w-[1100px]">
              <h2 className="font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                Also in the platform
              </h2>
              <dl className="mt-12 divide-y divide-[rgba(237,230,218,0.12)] border-y border-[rgba(237,230,218,0.12)]">
                {MORE.map((item) => (
                  <div
                    key={item.title}
                    className="grid gap-3 py-8 sm:grid-cols-[12rem_1fr] sm:gap-10"
                  >
                    <dt className="font-disp text-xl uppercase tracking-tight text-[#EDE6DA]">
                      {item.title}
                    </dt>
                    <dd className="text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                      {item.copy}
                    </dd>
                  </div>
                ))}
              </dl>

              <div className="mt-16 flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between sm:gap-12">
                <div className="max-w-xl">
                  <h3 className="font-disp text-[clamp(24px,3.5vw,36px)] uppercase leading-[0.95] tracking-[-0.03em]">
                    Build packs for Forja
                  </h3>
                  <p className="mt-4 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                    Authors extend the modular player platform with hubs, stream
                    providers, live modules, and more. Ship a pack, share the
                    URL, and the catalog can install it.
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
            </div>
          </section>

          <section className="border-b border-[rgba(237,230,218,0.14)] bg-[#0f0e0d] px-[5vw] py-16 sm:py-24">
            <div className="mx-auto max-w-[1100px]">
              <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between sm:gap-12">
                <h2 className="max-w-[14ch] font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Before you install
                </h2>
                <p className="max-w-sm text-sm leading-relaxed text-[rgba(237,230,218,0.5)] sm:text-right">
                  Windows, macOS, Linux, Android, Android TV, and iOS — installers
                  on Download.
                </p>
              </div>

              <ol className="mt-12 divide-y divide-[rgba(237,230,218,0.12)] border-y border-[rgba(237,230,218,0.12)]">
                {FAQ.map((item, i) => (
                  <li
                    key={item.q}
                    className="grid gap-4 py-10 sm:grid-cols-[3.5rem_1fr] sm:gap-10"
                  >
                    <span className="font-mono-ui text-[11px] uppercase tracking-[0.18em] text-forja-green">
                      {String(i + 1).padStart(2, '0')}
                    </span>
                    <div>
                      <h3 className="font-serif-i text-[clamp(1.25rem,2.5vw,1.65rem)] leading-snug text-[#EDE6DA]">
                        {item.q}
                      </h3>
                      <p className="mt-3 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                        {item.a}
                      </p>
                    </div>
                  </li>
                ))}
              </ol>
            </div>
          </section>

          <section className="relative overflow-hidden border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-20 sm:py-28">
            <div
              aria-hidden
              className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(28,231,131,0.08),transparent_55%)]"
            />
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
          </section>
        </main>

        <SiteFooter />
      </div>
    </div>
  )
}
