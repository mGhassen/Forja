import { Link } from '@tanstack/react-router'
import { Reveal } from '@/components/reveal'
import { SiteFooter } from '@/components/legal-shell'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'

const STATS = [
  { value: '6', label: 'Platforms: Windows, macOS, Linux, Android, Android TV, iOS' },
  { value: '5', label: 'Profiles per account with synced packs and settings' },
  { value: '1', label: 'Native player for movies, series, live sport, and IPTV' },
]

const CROSS_PLATFORM = [
  'Windows installer, macOS DMG (Apple Silicon and Intel), Linux AppImage',
  'Android phone and Android TV APKs with D-pad-friendly shell',
  'iOS build available; same account and packs across devices',
]

const PACK_POINTS = [
  'Install official and community packs from the web catalog or a manifest URL',
  'Hubs for Home, Anime, Asian Drama, Live Sports, IPTV, Lists, and more once packs are installed',
  'Enable, update, or remove packs per profile; the app downloads scripts on each device',
]

const PLAYER_POINTS = [
  'Native playback with MediaKit (mpv) and ExoPlayer on Android, switchable in the player',
  'Subtitles with style and language prefs, audio tracks, quality, speed, and aspect ratio',
  'Skip intro, recap, and credits; auto next episode; continue watching across sessions',
  'Picture-in-picture on supported desktops and Android phones; in-app mini player on desktop',
  'External players such as VLC, mpv, and IINA where the platform allows',
]

const IPTV_POINTS = [
  'Xtream Codes, M3U/M3U8, and Stalker/Ministra portals',
  'Live, Movies, and Series shelves from your portals in one hub',
  'Channel guide, search, and what is on now inside the live player',
  'Live Sports schedule with providers and Live TV matching for native play',
]

const ADDON_POINTS = [
  'Playback preferences synced to your profile',
  'Stremio addon manifests for Sources and Live Sports',
  'Nuvio scraper manifests for Sources',
  'Direct torrent indexers and local torrent or magnet playback on desktop',
  'Simkl for My List sync and scrobble',
  'LAN pairing so a desktop torrent server can feed phones and Android TV',
]

const MORE_FEATURES = [
  {
    title: 'Continue watching',
    copy: 'Resume movies and episodes from where you left off, including across devices when you sign in.',
  },
  {
    title: 'My List',
    copy: 'Track titles with Plan to Watch, Watching, On Hold, Completed, and Dropped, with optional Simkl sync.',
  },
  {
    title: 'Features rail',
    copy: 'Show, hide, and reorder shell tabs, and pick a default tab from Settings → Features.',
  },
  {
    title: 'Device link',
    copy: 'Pair desktop and Android TV with a code or QR through the portal Connect page.',
  },
  {
    title: 'Backup and restore',
    copy: 'Export and import settings JSON, including IPTV portal CSV for your lists.',
  },
  {
    title: 'Open source',
    copy: 'Inspect the host, use the pack SDK, and publish community packs the catalog can install.',
  },
]

const FAQ = [
  {
    q: 'Does Forja include channels or movies?',
    a: 'No. Forja is a player and host. You connect your own sources, portals, and community packs. Forja does not sell or host media files.',
  },
  {
    q: 'What platforms can I install Forja on?',
    a: 'Windows, macOS, Linux, Android, Android TV, and iOS. Download installers from the Download page. Sign in to sync packs and settings across devices.',
  },
  {
    q: 'What are packs and addons?',
    a: 'Packs install hubs and plugins (catalogs, live modules, torrent indexers). Addons are product surfaces you enable per profile, such as Playback, IPTV portals, Stremio, Nuvio, and Direct torrent.',
  },
  {
    q: 'Do I need an account?',
    a: 'No. You can use Forja offline. An account unlocks up to five profiles, pack membership sync, playback prefs sync, and device link for TV and desktop.',
  },
]

export function PlatformPage() {
  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="plugins" />
      <div className="relative z-10 flex min-h-screen flex-col">
        <SiteHeader solid />

        <main className="flex-1">
          {/* Hero */}
          <header className="relative px-[5vw] pb-14 pt-20 sm:pb-20 sm:pt-24 lg:pt-28">
            <div className="mx-auto max-w-[1100px]">
              <div className="hero-enter">
                <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
                  Platform features
                </p>
                <h1 className="mt-5 max-w-[18ch] font-disp text-[clamp(2.4rem,6vw,4.5rem)] uppercase leading-[0.92] tracking-[-0.04em]">
                  Everything you need to stream, in one modular player
                </h1>
                <p className="mt-6 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.65)] sm:text-lg">
                  Forja is an open-source streaming player for Windows, macOS,
                  Linux, Android, Android TV, and iOS. Install community packs
                  for hubs and sources, connect IPTV portals, turn on addons like
                  Stremio and Nuvio, and watch movies, series, live sport, and
                  live TV with the same native player everywhere.
                </p>
                <div className="mt-8 flex flex-wrap gap-3">
                  <Link
                    to="/download"
                    data-hover=""
                    className="btn-magnet inline-flex items-center justify-center rounded-full px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] shadow-[0_0_32px_rgba(28,231,131,0.35)]"
                  >
                    Download Forja
                  </Link>
                  <a
                    href="#features"
                    data-hover=""
                    className="inline-flex items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] text-[rgba(237,230,218,0.75)] transition hover:border-forja-flame/40 hover:text-forja-flame"
                  >
                    See features
                  </a>
                </div>
                <p className="mt-6 font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.4)]">
                  Open source · Your sources · Profile sync · Community packs
                </p>
              </div>
            </div>
          </header>

          {/* Stats strip */}
          <section className="border-y border-[rgba(237,230,218,0.14)] bg-[#0f0e0d]">
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

          <div id="features" className="scroll-mt-24">
            {/* 01 Cross-platform — text + bullets, no card */}
            <section className="border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24">
              <div className="mx-auto grid max-w-[1200px] items-start gap-12 lg:grid-cols-[0.85fr_1.15fr] lg:gap-16">
                <Reveal>
                  <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-flame">
                    01 / Platforms
                  </p>
                  <h2 className="mt-4 font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                    The same Forja on every screen you watch
                  </h2>
                </Reveal>
                <Reveal delayMs={80}>
                  <p className="text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                    Download native builds for desk, couch, and TV. Sign in once
                    to keep packs, playback preferences, and IPTV portal
                    assignments with your profiles across devices.
                  </p>
                  <ul className="mt-8 space-y-4">
                    {CROSS_PLATFORM.map((line) => (
                      <li
                        key={line}
                        className="border-l-2 border-forja-green/50 pl-4 text-base leading-relaxed text-[rgba(237,230,218,0.72)]"
                      >
                        {line}
                      </li>
                    ))}
                  </ul>
                </Reveal>
              </div>
            </section>

            {/* 02 Packs — image left, copy right */}
            <section className="border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24">
              <div className="mx-auto grid max-w-[1200px] items-center gap-12 lg:grid-cols-2 lg:gap-14">
                <Reveal variant="left">
                  <img
                    src="/brand/forja-home-hero.jpg"
                    alt="Forja home with cinematic hero and hub shelves"
                    width={1024}
                    height={643}
                    className="h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]"
                    loading="lazy"
                    decoding="async"
                  />
                </Reveal>
                <Reveal delayMs={80} variant="right">
                  <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
                    02 / Community packs
                  </p>
                  <h2 className="mt-4 font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                    Packs add the hubs and catalogs you stream
                  </h2>
                  <p className="mt-5 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                    Forja starts as a host. Packs bring Home, Anime, Asian Drama,
                    Live Sports, IPTV, Lists, and other hubs into the shell. Browse
                    official and community packs on the web, add them to a
                    profile, and open Forja to install.
                  </p>
                  <ul className="mt-6 space-y-3 text-base leading-relaxed text-[rgba(237,230,218,0.7)]">
                    {PACK_POINTS.map((line) => (
                      <li key={line} className="flex gap-3">
                        <span className="mt-2 size-1.5 shrink-0 rounded-full bg-forja-flame" />
                        <span>{line}</span>
                      </li>
                    ))}
                  </ul>
                  <Link
                    to="/plugins"
                    className="link-draw font-mono-ui mt-8 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
                  >
                    Browse community packs
                  </Link>
                </Reveal>
              </div>
            </section>

            {/* 03 Player — wide copy band, checklist */}
            <section className="border-b border-[rgba(237,230,218,0.14)] bg-[#121110] px-[5vw] py-16 sm:py-24">
              <div className="mx-auto max-w-[1100px]">
                <Reveal>
                  <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-flame">
                    03 / Native player
                  </p>
                  <h2 className="mt-4 max-w-[20ch] font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                    A player built for long sessions and every source
                  </h2>
                  <p className="mt-5 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                    Movies, series, hub titles, live sport, and IPTV all open in
                    the same native player with Sources, episodes, and playback
                    tools in one place.
                  </p>
                </Reveal>
                <div className="mt-12 grid gap-x-12 gap-y-5 sm:grid-cols-2">
                  {PLAYER_POINTS.map((line, i) => (
                    <Reveal key={line} delayMs={(i % 4) * 50}>
                      <p className="border-t border-[rgba(237,230,218,0.12)] pt-4 text-base leading-relaxed text-[rgba(237,230,218,0.72)]">
                        <span className="font-mono-ui mr-3 text-[10px] uppercase tracking-[0.16em] text-forja-green">
                          {String(i + 1).padStart(2, '0')}
                        </span>
                        {line}
                      </p>
                    </Reveal>
                  ))}
                </div>
              </div>
            </section>

            {/* 04 IPTV — copy left, image right */}
            <section className="border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24">
              <div className="mx-auto grid max-w-[1200px] items-center gap-12 lg:grid-cols-2 lg:gap-14">
                <Reveal variant="left" className="lg:order-1">
                  <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
                    04 / Live TV and IPTV
                  </p>
                  <h2 className="mt-4 font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                    Live channels, portal VOD, and live sport in the same app
                  </h2>
                  <p className="mt-5 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                    Connect the portals you already have. Browse Live, Movies, and
                    Series, search channels, and follow the guide without leaving
                    Forja. Live Sports sits alongside with schedule browse and
                    native stream play.
                  </p>
                  <ul className="mt-6 space-y-3 text-base leading-relaxed text-[rgba(237,230,218,0.7)]">
                    {IPTV_POINTS.map((line) => (
                      <li key={line} className="flex gap-3">
                        <span className="mt-2 size-1.5 shrink-0 rounded-full bg-forja-green" />
                        <span>{line}</span>
                      </li>
                    ))}
                  </ul>
                  <Link
                    to="/iptv"
                    className="link-draw font-mono-ui mt-8 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
                  >
                    More about the live player
                  </Link>
                </Reveal>
                <Reveal variant="right" className="lg:order-2">
                  <img
                    src="/brand/forja-iptv-live.jpg"
                    alt="Forja IPTV live channels and categories"
                    width={1024}
                    height={637}
                    className="h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]"
                    loading="lazy"
                    decoding="async"
                  />
                </Reveal>
              </div>
            </section>

            {/* 05 Addons — horizontal scroll-style rows */}
            <section className="border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24">
              <div className="mx-auto max-w-[1100px]">
                <Reveal>
                  <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-flame">
                    05 / Addons
                  </p>
                  <h2 className="mt-4 max-w-[22ch] font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                    Addons you enable for the tools you use
                  </h2>
                  <p className="mt-5 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                    Turn on Playback, IPTV, Stremio, Nuvio, Direct torrent, Simkl,
                    and LAN from Settings → Addons. The same surfaces sync to your
                    profile on the web portal.
                  </p>
                </Reveal>
                <ol className="mt-12 divide-y divide-[rgba(237,230,218,0.12)] border-y border-[rgba(237,230,218,0.12)]">
                  {ADDON_POINTS.map((line, i) => (
                    <Reveal key={line} delayMs={i * 40}>
                      <li className="grid grid-cols-[3rem_1fr] items-baseline gap-4 py-5 sm:grid-cols-[4rem_1fr] sm:gap-8">
                        <span className="font-mono-ui text-[11px] uppercase tracking-[0.16em] text-forja-green">
                          {String(i + 1).padStart(2, '0')}
                        </span>
                        <span className="text-base leading-relaxed text-[rgba(237,230,218,0.75)] sm:text-lg">
                          {line}
                        </span>
                      </li>
                    </Reveal>
                  ))}
                </ol>
              </div>
            </section>

            {/* 06 Sync — screenshot + short copy */}
            <section className="border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24">
              <div className="mx-auto grid max-w-[1200px] items-center gap-12 lg:grid-cols-2 lg:gap-14">
                <Reveal variant="left">
                  <img
                    src="/brand/forja-iptv-desk.png"
                    alt="Forja desk with Live, Movies, and Series catalog"
                    width={1024}
                    height={638}
                    className="h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]"
                    loading="lazy"
                    decoding="async"
                  />
                </Reveal>
                <Reveal delayMs={80} variant="right">
                  <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
                    06 / Profiles and sync
                  </p>
                  <h2 className="mt-4 font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                    Up to five profiles, synced across your devices
                  </h2>
                  <p className="mt-5 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                    An account is optional. When you sign in, each profile keeps
                    its own packs, Features rail, playback prefs, Stremio and
                    Nuvio URLs, and IPTV portal assignments. Pair desktop and
                    Android TV with device link from the portal.
                  </p>
                </Reveal>
              </div>
            </section>
          </div>

          {/* More inside — diversified: title + dense two-column text, not cards */}
          <section className="border-b border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24">
            <div className="mx-auto max-w-[1100px]">
              <Reveal>
                <h2 className="font-disp text-[clamp(28px,4vw,44px)] uppercase leading-[0.95] tracking-[-0.03em]">
                  More built into the platform
                </h2>
                <p className="mt-4 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-lg">
                  Everyday tools that sit beside the player, packs, and addons.
                </p>
              </Reveal>
              <dl className="mt-12 grid gap-10 sm:grid-cols-2 sm:gap-x-14 sm:gap-y-12">
                {MORE_FEATURES.map((item, i) => (
                  <Reveal key={item.title} delayMs={(i % 3) * 50}>
                    <div>
                      <dt className="font-disp text-xl uppercase tracking-tight text-[#EDE6DA] sm:text-2xl">
                        {item.title}
                      </dt>
                      <dd className="mt-2 text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                        {item.copy}
                      </dd>
                    </div>
                  </Reveal>
                ))}
              </dl>
            </div>
          </section>

          {/* FAQ */}
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

          {/* Close CTA */}
          <section className="px-[5vw] py-20 text-center sm:py-28">
            <Reveal>
              <h2 className="mx-auto max-w-[16ch] font-disp text-[clamp(32px,6vw,56px)] uppercase leading-[0.92] tracking-[-0.04em]">
                Download Forja and start streaming
              </h2>
              <p className="mx-auto mt-6 max-w-xl text-base leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-lg">
                Install the player on the device closest to you. Add packs and
                portals. Press play.
              </p>
              <div className="mt-10 flex flex-wrap items-center justify-center gap-3">
                <Link
                  to="/download"
                  data-hover=""
                  className="btn-magnet inline-flex items-center justify-center rounded-full px-10 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] shadow-[0_0_32px_rgba(28,231,131,0.35)]"
                >
                  Download Forja
                </Link>
                <Link
                  to="/plugins"
                  data-hover=""
                  className="inline-flex items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-10 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] text-[rgba(237,230,218,0.75)] transition hover:border-forja-flame/40 hover:text-forja-flame"
                >
                  Community Packs
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
