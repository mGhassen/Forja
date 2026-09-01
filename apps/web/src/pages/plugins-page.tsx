import { useMemo } from 'react'
import { Link } from '@tanstack/react-router'
import { Cloud, Download, Puzzle, Sparkles } from 'lucide-react'
import { PluginCatalogBrowser } from '@/components/plugin-catalog-browser'
import { PluginOrbitVisual } from '@/components/plugin-orbit-visual'
import { Reveal } from '@/components/reveal'
import { SiteFooter } from '@/components/legal-shell'
import { LiquidGlass } from '@/components/liquid-glass'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'
import { useForjaPluginCatalog } from '@/hooks/use-forja-plugin-catalog'
import { cn } from '@/lib/utils'

const MARQUEE = [
  'Providers',
  'Live sports',
  'Home hub',
  'Anime',
  'Asian drama',
  'Torrent',
  'IPTV VOD',
  'manifest.json',
  'Profile sync',
  'Cloud install',
] as const

const STEPS = [
  {
    n: '01',
    title: 'Pick a pack',
    copy: 'Browse official engine packs: providers, hubs, live, torrent, IPTV.',
    accent: 'brand' as const,
  },
  {
    n: '02',
    title: 'Add to Forja',
    copy: 'Confirm in your profile. The manifest saves to cloud sync, no app launch.',
    accent: 'flame' as const,
  },
  {
    n: '03',
    title: 'Play',
    copy: 'Forja fetches scripts on sync. Toggle plugins in Settings → Sources.',
    accent: 'brand' as const,
  },
]

export function PluginsPage() {
  const { data: packs, isLoading, error } = useForjaPluginCatalog()

  const totalPlugins = useMemo(
    () => packs?.reduce((sum, p) => sum + (p.pluginCount ?? 0), 0) ?? 0,
    [packs],
  )

  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="plugins" />
      <div className="relative z-10 flex min-h-screen flex-col">
        <SiteHeader solid />

        <main className="flex-1">
          <header className="relative px-[5vw] pb-10 pt-20 sm:pb-14 sm:pt-24 lg:pb-20 lg:pt-28">
            <div className="mx-auto grid max-w-[1400px] gap-12 lg:grid-cols-[1fr_0.95fr] lg:items-center">
              <div className="hero-enter">
                <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-forja-green/35 bg-forja-green/10 px-3 py-1 font-mono-ui text-[10px] uppercase tracking-[0.16em] text-forja-green">
                  <Puzzle className="size-3.5" aria-hidden />
                  Engine packs
                </div>

                <h1 className="font-disp text-[clamp(2.5rem,7vw,5.5rem)] uppercase leading-[0.88] tracking-[-0.04em]">
                  Power up
                  <br />
                  <span className="font-serif-i normal-case text-forja-flame">
                    your Forja.
                  </span>
                </h1>

                <p className="mt-6 max-w-lg font-disp text-[clamp(1.05rem,2.2vw,1.5rem)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.5)]">
                  Official remote plugins.{' '}
                  <span className="text-[#EDE6DA]">add to your profile.</span>
                </p>

                <div className="mt-8 flex flex-wrap gap-3">
                  <a
                    href="#catalog"
                    data-hover=""
                    className="btn-magnet inline-flex items-center justify-center rounded-full px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_32px_rgba(28,231,131,0.35)] will-change-transform sm:text-xs"
                  >
                    Browse packs
                  </a>
                  <Link
                    to="/download"
                    data-hover=""
                    className="inline-flex items-center justify-center gap-2 rounded-full border border-white/15 bg-white/[0.04] px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.7)] transition hover:border-forja-green/40 hover:text-forja-green sm:text-xs"
                  >
                    <Download className="size-3.5" aria-hidden />
                    Get the app
                  </Link>
                </div>

                {!isLoading && packs ? (
                  <dl className="mt-10 grid grid-cols-3 gap-4 border-t border-white/10 pt-8 sm:max-w-md">
                    <div>
                      <dt className="font-mono-ui text-[9px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.4)]">
                        Packs
                      </dt>
                      <dd className="mt-1 font-disp text-3xl uppercase tracking-tight text-[#EDE6DA]">
                        {packs.length}
                      </dd>
                    </div>
                    <div>
                      <dt className="font-mono-ui text-[9px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.4)]">
                        Plugins
                      </dt>
                      <dd className="mt-1 font-disp text-3xl uppercase tracking-tight text-forja-green">
                        {totalPlugins || 'n/a'}
                      </dd>
                    </div>
                    <div>
                      <dt className="font-mono-ui text-[9px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.4)]">
                        Hosted
                      </dt>
                      <dd className="mt-1 flex items-center gap-1.5 font-disp text-lg uppercase tracking-tight text-[#EDE6DA]">
                        <Cloud className="size-4 text-forja-flame" aria-hidden />
                        GitHub
                      </dd>
                    </div>
                  </dl>
                ) : null}
              </div>

              <Reveal variant="right" delayMs={100} className="relative">
                <PluginOrbitVisual />
                <p className="font-mono-ui mt-5 text-center text-[10px] uppercase tracking-[0.18em] text-[rgba(237,230,218,0.38)]">
                  Providers · hubs · live · torrent · IPTV
                </p>
              </Reveal>
            </div>
          </header>

          <div className="overflow-hidden border-y border-[rgba(237,230,218,0.12)] bg-[#0f0e0d] py-4">
            <div className="animate-marquee flex w-max gap-10 whitespace-nowrap px-4">
              {[...MARQUEE, ...MARQUEE].map((word, i) => (
                <span key={`${word}-${i}`} className="inline-flex items-center gap-3">
                  <b className="font-serif-i text-[clamp(1.25rem,2.8vw,2rem)] text-[#EDE6DA]">
                    {word}
                  </b>
                  <Sparkles
                    className={cn(
                      'size-4',
                      i % 2 === 0 ? 'text-forja-green' : 'text-forja-flame',
                    )}
                    aria-hidden
                  />
                </span>
              ))}
            </div>
          </div>

          <section className="px-[5vw] py-14 sm:py-20">
            <div className="mx-auto max-w-[1400px]">
              <Reveal>
                <h2 className="font-disp text-[clamp(1.75rem,4vw,2.75rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Three taps to{' '}
                  <span className="text-forja-green">go live.</span>
                </h2>
              </Reveal>
              <div className="mt-10 grid gap-4 md:grid-cols-3">
                {STEPS.map((step, i) => (
                  <Reveal key={step.n} delayMs={i * 80} variant="scale">
                    <LiquidGlass className="hover-lift h-full border-white/10 p-6 sm:p-7">
                      <p
                        className={cn(
                          'font-mono-ui text-[10px] font-bold uppercase tracking-[0.2em]',
                          step.accent === 'flame'
                            ? 'text-forja-flame'
                            : 'text-forja-green',
                        )}
                      >
                        Step {step.n}
                      </p>
                      <h3 className="mt-3 font-disp text-xl uppercase tracking-tight text-[#EDE6DA]">
                        {step.title}
                      </h3>
                      <p className="mt-2 text-sm leading-relaxed text-[rgba(237,230,218,0.58)]">
                        {step.copy}
                      </p>
                    </LiquidGlass>
                  </Reveal>
                ))}
              </div>
            </div>
          </section>

          <section
            id="catalog"
            className="scroll-mt-28 border-t border-[rgba(237,230,218,0.1)] px-[5vw] py-14 sm:py-20"
          >
            <div className="mx-auto max-w-[1400px]">
              <Reveal>
                <div className="mb-8 max-w-xl">
                  <h2 className="font-disp text-[clamp(2rem,5vw,3.5rem)] uppercase leading-[0.92] tracking-[-0.03em]">
                    Official
                    <br />
                    <span className="text-forja-flame">pack catalog.</span>
                  </h2>
                  <p className="mt-4 text-[rgba(237,230,218,0.55)]">
                    Remote manifests from the Forja repo. Search, pick a pack,
                    confirm in your profile. The app installs on sync.
                  </p>
                </div>
              </Reveal>

              <PluginCatalogBrowser
                packs={packs ?? []}
                isLoading={isLoading}
                error={error}
              />
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
                      No account required to browse
                    </p>
                    <h2 className="mt-2 font-disp text-[clamp(1.75rem,4vw,2.5rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                      Don&apos;t have Forja yet?
                    </h2>
                    <p className="mt-3 text-[rgba(237,230,218,0.55)]">
                      Download free for desktop, mobile, and TV, then come back
                      and add packs from your profile.
                    </p>
                  </div>
                  <Link
                    to="/download"
                    data-hover=""
                    className="btn-magnet inline-flex shrink-0 items-center justify-center rounded-full px-9 py-4 font-mono-ui text-xs font-bold uppercase tracking-[0.1em] shadow-[0_0_32px_rgba(28,231,131,0.35)] will-change-transform sm:text-sm"
                  >
                    Download Forja
                  </Link>
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
