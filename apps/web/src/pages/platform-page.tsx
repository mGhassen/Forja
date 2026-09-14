import { Link } from '@tanstack/react-router'
import { Reveal } from '@/components/reveal'
import { SiteFooter } from '@/components/legal-shell'
import { LiquidGlass } from '@/components/liquid-glass'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'
import { cn } from '@/lib/utils'

const UNIQUES = [
  {
    title: 'A host you control, not a locked catalog',
    copy: 'Forja is the player host. Packs and addons decide what you browse and play. You are not stuck inside one catalog owned by the app vendor.',
    accent: 'brand' as const,
  },
  {
    title: 'Community packs for hubs and sources',
    copy: 'Install hubs, providers, live feeds, torrent indexers, and more. Keep only what you need. Authors can publish a pack URL anyone can add.',
    accent: 'flame' as const,
  },
  {
    title: 'Addons for the surfaces you turn on',
    copy: 'Playback preferences, IPTV portals, Stremio, Nuvio, torrent, and related tools live as addons you enable per profile, the same way they appear in the app.',
    accent: 'brand' as const,
  },
  {
    title: 'Open source from the player to the SDK',
    copy: 'Inspect the project, contribute packs with the SDK, and grow the catalog with the community while the host stays generic.',
    accent: 'flame' as const,
  },
]

const CAPABILITIES = [
  {
    k: 'Movies and series',
    v: 'Watch full screen with player controls built for long sessions, episode flow, audio tracks, and subtitles when the stream supports them.',
  },
  {
    k: 'Anime and drama hubs',
    v: 'Install hub packs for the catalogs you care about. Shelves, details, and open behavior come from the pack, not hard-coded into Forja.',
  },
  {
    k: 'Live sport',
    v: 'Follow matches as they happen using the live feeds and sources you install, inside the same player you use for everything else.',
  },
  {
    k: 'Live TV and IPTV',
    v: 'Connect your channel list, search, see what is on now, and keep movies and series one step away without switching apps.',
  },
]

const LAYERS = [
  {
    title: 'Player host',
    copy: 'Forja provides the shell, native playback, profile sync, and pack install. It does not claim to own every title on the internet.',
  },
  {
    title: 'Packs',
    copy: 'Official and community packs add hubs, sources, and live modules. You browse them on Community Packs and install them to a profile.',
  },
  {
    title: 'Addons',
    copy: 'Addons are the product surfaces you enable: playback, IPTV portals, Stremio, Nuvio, torrent, and related preferences for that profile.',
  },
]

const BETTER = [
  {
    title: 'You assemble the stack',
    copy: 'Closed players ship one fixed opinion of what you can watch. Forja lets you assemble hubs and sources as packs, and leave out the rest.',
  },
  {
    title: 'Live and on-demand in one player',
    copy: 'Live channels, sport, movies, and series share the same app and controls, so you do not bounce between separate tools for a match and a film.',
  },
  {
    title: 'Settings and packs sync across screens',
    copy: 'Sign in to keep packs and preferences with you from a desk to the couch to Android TV.',
  },
  {
    title: 'Built so the community can extend it',
    copy: 'Authors start from the SDK, host a manifest URL, and land in the same catalog everyone else browses and installs.',
  },
]

export function PlatformPage() {
  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="plugins" />
      <div className="relative z-10 flex min-h-screen flex-col">
        <SiteHeader solid />

        <main className="flex-1">
          <header className="relative px-[5vw] pb-12 pt-20 sm:pb-16 sm:pt-24 lg:pb-20 lg:pt-28">
            <div className="mx-auto max-w-[900px]">
              <div className="hero-enter">
                <h1 className="font-disp text-[clamp(2.2rem,5.5vw,4rem)] uppercase leading-[0.92] tracking-[-0.03em]">
                  What Forja offers as a
                  <br />
                  <span className="font-serif-i normal-case text-forja-flame">
                    streaming platform
                  </span>
                </h1>
                <p className="mt-6 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg">
                  Most streaming apps sell a fixed catalog. Forja is an
                  open-source modular player: a host for packs and addons,
                  shaped by the community, with the same app across your
                  screens. This page explains how the pieces fit and why that
                  design is better than a closed player.
                </p>
                <div className="mt-8 flex flex-wrap gap-3">
                  <Link
                    to="/download"
                    data-hover=""
                    className="btn-magnet inline-flex items-center justify-center rounded-full px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_32px_rgba(28,231,131,0.35)] sm:text-xs"
                  >
                    Download Forja
                  </Link>
                  <Link
                    to="/plugins"
                    data-hover=""
                    className="inline-flex items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.7)] transition hover:border-forja-flame/40 hover:text-forja-flame sm:text-xs"
                  >
                    Browse community packs
                  </Link>
                </div>
              </div>
            </div>
          </header>

          <section className="border-t border-[rgba(237,230,218,0.12)] px-[5vw] py-14 sm:py-20">
            <div className="mx-auto max-w-[1400px]">
              <Reveal>
                <h2 className="font-disp text-[clamp(1.6rem,3.5vw,2.5rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                  What makes Forja different
                </h2>
                <p className="mt-4 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                  These are the product choices that separate Forja from a
                  normal file player or a closed streaming service.
                </p>
              </Reveal>
              <div className="mt-10 grid gap-4 sm:grid-cols-2">
                {UNIQUES.map((item, i) => (
                  <Reveal key={item.title} delayMs={(i % 2) * 80} variant="scale">
                    <LiquidGlass className="hover-lift h-full border-white/10 p-6 sm:p-7">
                      <h3
                        className={cn(
                          'font-disp text-xl uppercase leading-snug tracking-tight',
                          item.accent === 'flame'
                            ? 'text-forja-flame'
                            : 'text-forja-green',
                        )}
                      >
                        {item.title}
                      </h3>
                      <p className="mt-3 text-sm leading-relaxed text-[rgba(237,230,218,0.6)] sm:text-base">
                        {item.copy}
                      </p>
                    </LiquidGlass>
                  </Reveal>
                ))}
              </div>
            </div>
          </section>

          <section className="border-t border-[rgba(237,230,218,0.1)] px-[5vw] py-14 sm:py-20">
            <div className="mx-auto max-w-[1400px]">
              <Reveal>
                <h2 className="font-disp text-[clamp(1.6rem,3.5vw,2.5rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                  How the platform is organized
                </h2>
                <p className="mt-4 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                  Three clear layers. The host stays stable. Packs and addons
                  carry the product you actually use day to day.
                </p>
              </Reveal>
              <div className="mt-10 grid gap-4 md:grid-cols-3">
                {LAYERS.map((layer, i) => (
                  <Reveal key={layer.title} delayMs={i * 80} variant="scale">
                    <LiquidGlass className="hover-lift h-full border-white/10 p-6 sm:p-7">
                      <h3 className="font-disp text-xl uppercase tracking-tight text-[#EDE6DA]">
                        {layer.title}
                      </h3>
                      <p className="mt-3 text-sm leading-relaxed text-[rgba(237,230,218,0.6)] sm:text-base">
                        {layer.copy}
                      </p>
                    </LiquidGlass>
                  </Reveal>
                ))}
              </div>
            </div>
          </section>

          <section className="border-t border-[rgba(237,230,218,0.1)] px-[5vw] py-14 sm:py-20">
            <div className="mx-auto max-w-[1400px]">
              <Reveal>
                <h2 className="font-disp text-[clamp(1.6rem,3.5vw,2.5rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                  What you can stream in one player
                </h2>
                <p className="mt-4 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                  Packs and addons unlock these surfaces inside the same Forja
                  app. Live TV is part of the platform, not a separate product
                  sitting beside it.
                </p>
              </Reveal>
              <div className="mt-10 grid gap-4 sm:grid-cols-2">
                {CAPABILITIES.map((cap, i) => (
                  <Reveal key={cap.k} delayMs={(i % 2) * 70}>
                    <div className="hover-lift h-full border border-[rgba(237,230,218,0.14)] bg-[#121110] px-6 py-7 sm:px-8 sm:py-8">
                      <h3 className="font-disp text-[clamp(20px,2.2vw,28px)] uppercase leading-snug tracking-tight">
                        {cap.k}
                      </h3>
                      <p className="mt-3 text-base leading-relaxed text-[rgba(237,230,218,0.6)]">
                        {cap.v}
                      </p>
                    </div>
                  </Reveal>
                ))}
              </div>
              <Reveal delayMs={100}>
                <div className="mt-8 flex flex-wrap gap-6">
                  <Link
                    to="/iptv"
                    className="link-draw font-mono-ui text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
                  >
                    More about live TV and IPTV
                  </Link>
                  <a
                    href="/plugins#build"
                    className="link-draw font-mono-ui text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
                  >
                    How to build a community pack
                  </a>
                </div>
              </Reveal>
            </div>
          </section>

          <section className="border-t border-[rgba(237,230,218,0.1)] px-[5vw] py-14 sm:py-20">
            <div className="mx-auto max-w-[1100px]">
              <Reveal>
                <h2 className="font-disp text-[clamp(1.6rem,3.5vw,2.5rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Why this is better than a closed player
                </h2>
                <p className="mt-4 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                  The advantage is the architecture, not louder slogans.
                </p>
              </Reveal>
              <ul className="mt-10 space-y-10">
                {BETTER.map((row, i) => (
                  <Reveal key={row.title} delayMs={i * 60}>
                    <li>
                      <h3 className="font-disp text-[clamp(22px,2.8vw,32px)] uppercase leading-snug tracking-tight text-[#EDE6DA]">
                        {row.title}
                      </h3>
                      <p className="mt-3 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.6)]">
                        {row.copy}
                      </p>
                    </li>
                  </Reveal>
                ))}
              </ul>
            </div>
          </section>

          <section className="border-t border-[rgba(237,230,218,0.1)] px-[5vw] py-16 sm:py-24">
            <Reveal>
              <LiquidGlass className="relative mx-auto max-w-[1400px] overflow-hidden border-white/12 p-8 sm:p-12">
                <div
                  aria-hidden
                  className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_80%_20%,rgba(28,231,131,0.12),transparent_55%)]"
                />
                <div className="relative flex flex-col items-start gap-6 sm:flex-row sm:items-center sm:justify-between">
                  <div className="max-w-lg">
                    <h2 className="font-disp text-[clamp(1.6rem,3.5vw,2.25rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                      Download Forja and shape your setup
                    </h2>
                    <p className="mt-3 text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                      Install the player, add the packs you need, turn on the
                      addons you use, and stream on every screen.
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-3">
                    <Link
                      to="/download"
                      data-hover=""
                      className="btn-magnet inline-flex shrink-0 items-center justify-center rounded-full px-9 py-4 font-mono-ui text-xs font-bold uppercase tracking-[0.1em] shadow-[0_0_32px_rgba(28,231,131,0.35)] sm:text-sm"
                    >
                      Download Forja
                    </Link>
                    <Link
                      to="/plugins"
                      data-hover=""
                      className="inline-flex shrink-0 items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-9 py-4 font-mono-ui text-xs font-bold uppercase tracking-[0.1em] text-[rgba(237,230,218,0.75)] transition hover:border-forja-flame/40 hover:text-forja-flame sm:text-sm"
                    >
                      Community Packs
                    </Link>
                  </div>
                </div>
              </LiquidGlass>
            </Reveal>
          </section>
        </main>

        <SiteFooter />
      </div>
    </div>
  )
}
