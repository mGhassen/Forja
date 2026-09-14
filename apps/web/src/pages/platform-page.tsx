import { Link } from '@tanstack/react-router'
import { Reveal } from '@/components/reveal'
import { SiteFooter } from '@/components/legal-shell'
import { LiquidGlass } from '@/components/liquid-glass'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'
import { cn } from '@/lib/utils'

const UNIQUES = [
  {
    title: 'Host, not a walled garden',
    copy: 'Forja is the player host. Packs and addons decide what you browse and play. You are not locked into one catalog owned by the app.',
    accent: 'brand' as const,
  },
  {
    title: 'Community packs',
    copy: 'Install hubs, providers, live feeds, torrent indexers, and more. Add only what you want. Ship your own pack and share the URL.',
    accent: 'flame' as const,
  },
  {
    title: 'Addon surfaces',
    copy: 'Playback prefs, IPTV portals, Stremio, Nuvio, torrent, and more live as addons you turn on per profile. Same idea as the app Settings addons hub.',
    accent: 'brand' as const,
  },
  {
    title: 'Open source',
    copy: 'Inspect the project, fork it, and build on the SDK. The community grows the catalog while the host stays generic.',
    accent: 'flame' as const,
  },
]

const CAPABILITIES = [
  {
    k: 'Movies & series',
    v: 'Full-screen playback with controls built for long sessions and episode flow.',
  },
  {
    k: 'Anime & drama hubs',
    v: 'Install hub packs for the worlds you watch. Shelves and details come from the pack.',
  },
  {
    k: 'Live sport',
    v: 'Follow matches as they happen with sources and feeds you install.',
  },
  {
    k: 'Live TV & IPTV',
    v: 'Connect your list, search channels, see what is on, and keep films in the same player.',
  },
]

const LAYERS = [
  {
    n: '01',
    title: 'Player host',
    copy: 'Shell, playback, sync, and install. Forja does not pretend to own every title on earth.',
  },
  {
    n: '02',
    title: 'Packs',
    copy: 'Community (and official) packs add hubs, sources, and live modules. Browse them on Community Packs.',
  },
  {
    n: '03',
    title: 'Addons',
    copy: 'Profile surfaces you enable: playback, IPTV portals, Stremio, Nuvio, torrent, and related prefs.',
  },
]

const BETTER = [
  {
    title: 'You choose the stack',
    copy: 'Closed players ship one opinion. Forja lets you assemble hubs and sources as packs.',
  },
  {
    title: 'One app for live and VOD',
    copy: 'Live channels, sport, movies, and series share the same player instead of bouncing between tools.',
  },
  {
    title: 'Sync across screens',
    copy: 'Sign in to keep packs and settings with you from desk to couch to Android TV.',
  },
  {
    title: 'Built to be extended',
    copy: 'Authors use the SDK, host a manifest URL, and land in the same catalog everyone browses.',
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
                <p className="mb-5 font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
                  The Forja platform
                </p>
                <h1 className="font-disp text-[clamp(2.4rem,6.5vw,4.75rem)] uppercase leading-[0.9] tracking-[-0.04em]">
                  What makes Forja
                  <br />
                  <span className="font-serif-i normal-case text-forja-flame">
                    different
                  </span>
                </h1>
                <p className="mt-6 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-lg">
                  Most streaming apps sell a fixed catalog. Forja is a modular
                  open-source player: a host for packs and addons, shaped by the
                  community, synced across your screens.
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
                    Browse packs
                  </Link>
                </div>
              </div>
            </div>
          </header>

          <section className="border-t border-[rgba(237,230,218,0.12)] px-[5vw] py-14 sm:py-20">
            <div className="mx-auto max-w-[1400px]">
              <Reveal>
                <h2 className="font-disp text-[clamp(1.75rem,4vw,2.75rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Why people pick{' '}
                  <span className="text-forja-green">Forja</span>
                </h2>
                <p className="mt-4 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
                  Four traits that separate Forja from a normal media player or a
                  closed streaming app.
                </p>
              </Reveal>
              <div className="mt-10 grid gap-4 sm:grid-cols-2">
                {UNIQUES.map((item, i) => (
                  <Reveal key={item.title} delayMs={(i % 2) * 80} variant="scale">
                    <LiquidGlass className="hover-lift h-full border-white/10 p-6 sm:p-7">
                      <p
                        className={cn(
                          'font-mono-ui text-[10px] font-bold uppercase tracking-[0.2em]',
                          item.accent === 'flame'
                            ? 'text-forja-flame'
                            : 'text-forja-green',
                        )}
                      >
                        Unique
                      </p>
                      <h3 className="mt-3 font-disp text-xl uppercase tracking-tight text-[#EDE6DA]">
                        {item.title}
                      </h3>
                      <p className="mt-2 text-sm leading-relaxed text-[rgba(237,230,218,0.58)]">
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
                <h2 className="font-disp text-[clamp(1.75rem,4vw,2.75rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                  How the platform{' '}
                  <span className="text-forja-flame">fits together</span>
                </h2>
              </Reveal>
              <div className="mt-10 grid gap-4 md:grid-cols-3">
                {LAYERS.map((layer, i) => (
                  <Reveal key={layer.n} delayMs={i * 80} variant="scale">
                    <LiquidGlass className="hover-lift h-full border-white/10 p-6 sm:p-7">
                      <p className="font-mono-ui text-[10px] font-bold uppercase tracking-[0.2em] text-forja-green">
                        Layer {layer.n}
                      </p>
                      <h3 className="mt-3 font-disp text-xl uppercase tracking-tight text-[#EDE6DA]">
                        {layer.title}
                      </h3>
                      <p className="mt-2 text-sm leading-relaxed text-[rgba(237,230,218,0.58)]">
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
                <h2 className="font-disp text-[clamp(1.75rem,4vw,2.75rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                  What you can{' '}
                  <span className="text-forja-green">stream</span>
                </h2>
                <p className="mt-4 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
                  One player for the surfaces packs and addons unlock. Live TV is
                  part of the platform, not a separate product next to Forja.
                </p>
              </Reveal>
              <div className="mt-10 grid gap-4 sm:grid-cols-2">
                {CAPABILITIES.map((cap, i) => (
                  <Reveal key={cap.k} delayMs={(i % 2) * 70}>
                    <div className="hover-lift h-full border border-[rgba(237,230,218,0.14)] bg-[#121110] px-6 py-7 sm:px-8 sm:py-8">
                      <h3 className="font-disp text-[clamp(22px,2.5vw,30px)] uppercase leading-tight tracking-tight">
                        {cap.k}
                      </h3>
                      <p className="mt-3 text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
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
                    Deep dive: live TV & IPTV
                  </Link>
                  <a
                    href="/plugins#build"
                    className="link-draw font-mono-ui text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame"
                  >
                    Build a community pack
                  </a>
                </div>
              </Reveal>
            </div>
          </section>

          <section className="border-t border-[rgba(237,230,218,0.1)] px-[5vw] py-14 sm:py-20">
            <div className="mx-auto max-w-[1100px]">
              <Reveal>
                <h2 className="font-disp text-[clamp(1.75rem,4vw,2.75rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Better than a{' '}
                  <span className="text-forja-flame">closed player</span>
                </h2>
                <p className="mt-4 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
                  Not louder marketing. Clear architecture choices.
                </p>
              </Reveal>
              <ul className="mt-10 space-y-8">
                {BETTER.map((row, i) => (
                  <Reveal key={row.title} delayMs={i * 60}>
                    <li>
                      <p className="font-disp text-[clamp(24px,3vw,36px)] uppercase leading-none text-[#EDE6DA]">
                        {row.title}
                      </p>
                      <p className="mt-3 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
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
                    <p className="font-mono-ui text-[10px] uppercase tracking-[0.18em] text-forja-green">
                      Ready when you are
                    </p>
                    <h2 className="mt-2 font-disp text-[clamp(1.75rem,4vw,2.5rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                      Download Forja and shape your setup
                    </h2>
                    <p className="mt-3 text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
                      Install the player, add packs, turn on the addons you need,
                      and stream on every screen.
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
