import { useMemo, useState } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
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
import { Route } from '@/routes/plugins'

const BUILD_GUIDE_URL =
  'https://github.com/mGhassen/Forja/blob/main/plugins/DEVELOPING.md'
const PACKS_REPO_URL = 'https://github.com/mGhassen/Forja/tree/main/plugins'

const MARQUEE = [
  'Community packs',
  'New providers',
  'Custom hubs',
  'Live sports',
  'Torrent search',
  'IPTV VOD',
  'manifest.json',
  'Fork & ship',
  'Profile sync',
  'Your manifest URL',
] as const

const STEPS = [
  {
    n: '01',
    title: 'Browse packs',
    copy: 'Official starters and community manifests — providers, hubs, live, torrent, IPTV.',
    accent: 'brand' as const,
  },
  {
    n: '02',
    title: 'Add to your profile',
    copy: 'Add it to your profile on the web. Open Forja on a device to download and install.',
    accent: 'flame' as const,
  },
  {
    n: '03',
    title: 'Ship your own',
    copy: 'Host a manifest on GitHub or your CDN. Share the URL — anyone can add it.',
    accent: 'brand' as const,
  },
]

export function PluginsPage() {
  const navigate = useNavigate()
  const search = Route.useSearch()
  const { data: packs, isLoading, error } = useForjaPluginCatalog()
  const [batchInstallOnMount, setBatchInstallOnMount] = useState(
    () => search.batchInstall === true,
  )

  const handleBatchInstallOnMountHandled = () => {
    if (!search.batchInstall) return
    setBatchInstallOnMount(false)
    void navigate({
      to: '/plugins',
      search: {},
      replace: true,
    })
  }

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
                  Community packs
                </div>

                <h1 className="font-disp text-[clamp(2.5rem,7vw,5.5rem)] uppercase leading-[0.88] tracking-[-0.04em]">
                  Extend
                  <br />
                  <span className="font-serif-i normal-case text-forja-flame">
                    your Forja.
                  </span>
                </h1>

                <p className="mt-6 max-w-lg font-disp text-[clamp(1.05rem,2.2vw,1.5rem)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.5)]">
                  New sources, hubs, and live feeds —{' '}
                  <span className="text-[#EDE6DA]">
                    install community packs or publish your own.
                  </span>
                </p>

                <div className="mt-8 flex flex-wrap gap-3">
                  <a
                    href="#catalog"
                    data-hover=""
                    className="btn-magnet inline-flex items-center justify-center rounded-full px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_32px_rgba(28,231,131,0.35)] will-change-transform sm:text-xs"
                  >
                    Browse packs
                  </a>
                  <a
                    href={BUILD_GUIDE_URL}
                    data-hover=""
                    rel="noopener noreferrer"
                    target="_blank"
                    className="inline-flex items-center justify-center gap-2 rounded-full border border-white/15 bg-white/[0.04] px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.7)] transition hover:border-forja-flame/40 hover:text-forja-flame sm:text-xs"
                  >
                    Build a pack
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
                  Official starters · community packs · yours too
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
                  Install or{' '}
                  <span className="text-forja-green">ship a pack.</span>
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
                    Community
                    <br />
                    <span className="text-forja-flame">pack catalog.</span>
                  </h2>
                  <p className="mt-4 text-[rgba(237,230,218,0.55)]">
                    Curated official packs from the Forja repo — the same
                    manifests anyone can fork, remix, and host. Search, pick a
                    pack, add it to your profile; the app downloads and installs
                    the scripts.
                  </p>
                </div>
              </Reveal>

              <PluginCatalogBrowser
                packs={packs ?? []}
                isLoading={isLoading}
                error={error}
                batchInstallOnMount={batchInstallOnMount}
                onBatchInstallOnMountHandled={handleBatchInstallOnMountHandled}
              />
            </div>
          </section>

          <section
            id="build"
            className="border-t border-[rgba(237,230,218,0.1)] px-[5vw] py-14 sm:py-20"
          >
            <div className="mx-auto max-w-[1400px]">
              <Reveal>
                <div className="mb-10 max-w-2xl">
                  <p className="font-mono-ui text-[10px] uppercase tracking-[0.18em] text-forja-flame">
                    Open platform
                  </p>
                  <h2 className="mt-2 font-disp text-[clamp(1.75rem,4vw,3rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                    Build what{' '}
                    <span className="text-forja-green">Forja is missing.</span>
                  </h2>
                  <p className="mt-4 text-[rgba(237,230,218,0.58)] leading-relaxed">
                    Forja is a host, not a walled garden. Write packs for stream
                    extractors, catalog hubs, live schedules, torrent indexers —
                    users install with one{' '}
                    <span className="text-[#EDE6DA]">manifest.json</span> URL.
                    Fork the official packs, use the SDK contracts, ship on
                    GitHub or your own CDN.
                  </p>
                </div>
              </Reveal>
              <div className="grid gap-4 md:grid-cols-3">
                {[
                  {
                    title: 'Start from official packs',
                    copy: 'Clone providers, hubs, live, torrent, and IPTV packs. See how extract, catalog, and search handlers work in production.',
                    href: PACKS_REPO_URL,
                    cta: 'Browse plugins repo',
                  },
                  {
                    title: 'Follow the SDK',
                    copy: 'Manifest schema, catalog envelopes, VOD stream rows, and JS kits — everything the host validates at install time.',
                    href: BUILD_GUIDE_URL,
                    cta: 'Read DEVELOPING.md',
                  },
                  {
                    title: 'Share one URL',
                    copy: 'Host your manifest anywhere. Users paste it in Settings or add it from this site — sync does the rest.',
                    href: '#catalog',
                    cta: 'See how install works',
                    internal: true,
                  },
                ].map((card, i) => (
                  <Reveal key={card.title} delayMs={i * 80} variant="scale">
                    <LiquidGlass className="hover-lift flex h-full flex-col border-white/10 p-6 sm:p-7">
                      <h3 className="font-disp text-xl uppercase tracking-tight text-[#EDE6DA]">
                        {card.title}
                      </h3>
                      <p className="mt-2 flex-1 text-sm leading-relaxed text-[rgba(237,230,218,0.58)]">
                        {card.copy}
                      </p>
                      {'internal' in card && card.internal ? (
                        <a
                          href={card.href}
                          data-hover=""
                          className="mt-5 inline-flex font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] text-forja-green transition hover:text-[#EDE6DA]"
                        >
                          {card.cta} →
                        </a>
                      ) : (
                        <a
                          href={card.href}
                          data-hover=""
                          rel="noopener noreferrer"
                          target="_blank"
                          className="mt-5 inline-flex font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] text-forja-green transition hover:text-[#EDE6DA]"
                        >
                          {card.cta} →
                        </a>
                      )}
                    </LiquidGlass>
                  </Reveal>
                ))}
              </div>
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
                      Download free for desktop, mobile, and TV — then install
                      community packs from your profile or paste any manifest
                      URL in Settings.
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
