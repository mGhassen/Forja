import { useMemo, useState } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { Cloud, Download, Puzzle } from 'lucide-react'
import { PluginBundlesShowcase } from '@/components/plugin-bundles-showcase'
import { PluginCatalogBrowser } from '@/components/plugin-catalog-browser'
import { PluginOrbitVisual } from '@/components/plugin-orbit-visual'
import { Reveal } from '@/components/reveal'
import { SiteFooter } from '@/components/legal-shell'
import { LiquidGlass } from '@/components/liquid-glass'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'
import { useForjaPluginBundles } from '@/hooks/use-forja-plugin-bundles'
import { useForjaPluginCatalog } from '@/hooks/use-forja-plugin-catalog'
import { cn } from '@/lib/utils'
import { Route } from '@/routes/plugins'

const BUILD_GUIDE_URL =
  'https://github.com/mGhassen/forja-sdk/blob/main/DEVELOPING.md'
const STARTERS_URL =
  'https://github.com/mGhassen/forja-sdk/tree/main/starters'
const FORJA_SOURCE_URL = 'https://github.com/forjahq/forja'

const BUILD_STEPS = [
  {
    n: '01',
    title: 'Start from a starter',
    copy: 'Clone a starter from the SDK. Use a provider starter for Sources, or a hub starter for a shell tab with layout and details.',
    href: STARTERS_URL,
    cta: 'Open starters',
    accent: 'brand' as const,
  },
  {
    n: '02',
    title: 'Follow the developer guide',
    copy: 'Read DEVELOPING.md for pack layout, manifests, and how the host loads your code.',
    href: BUILD_GUIDE_URL,
    cta: 'Read the guide',
    accent: 'flame' as const,
  },
  {
    n: '03',
    title: 'Host and share',
    copy: 'Publish your manifest URL. Users add it from Community Packs or their profile; Forja installs it on their devices.',
    href: '#catalog',
    cta: 'Browse the catalog',
    accent: 'brand' as const,
    internal: true,
  },
]

export function PluginsPage() {
  const navigate = useNavigate()
  const search = Route.useSearch()
  const { data: packs, isLoading, error } = useForjaPluginCatalog()
  const {
    data: bundles,
    isLoading: bundlesLoading,
    error: bundlesError,
  } = useForjaPluginBundles()
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

                <h1 className="font-disp text-[clamp(2.5rem,7vw,5rem)] uppercase leading-[0.9] tracking-[-0.04em]">
                  Community packs
                  <br />
                  <span className="font-serif-i normal-case text-forja-flame">
                    for Forja
                  </span>
                </h1>

                <p className="mt-6 max-w-lg text-base leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-lg">
                  Packs extend Forja, the modular player platform. Anime, live
                  sport, IPTV, torrent search, and more install from the catalog
                  onto your profile.
                </p>

                <div className="mt-8 flex flex-wrap gap-3">
                  <a
                    href="#bundles"
                    data-hover=""
                    className="btn-magnet inline-flex items-center justify-center rounded-full px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_32px_rgba(28,231,131,0.35)] will-change-transform sm:text-xs"
                  >
                    Start with a set
                  </a>
                  <a
                    href="#catalog"
                    data-hover=""
                    className="inline-flex items-center justify-center gap-2 rounded-full border border-white/15 bg-white/[0.04] px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.7)] transition hover:border-forja-flame/40 hover:text-forja-flame sm:text-xs"
                  >
                    Browse packs
                  </a>
                  <a
                    href="#build"
                    data-hover=""
                    className="inline-flex items-center justify-center gap-2 rounded-full border border-white/15 bg-white/[0.04] px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.7)] transition hover:border-forja-green/40 hover:text-forja-green sm:text-xs"
                  >
                    Build a pack
                  </a>
                  <Link
                    to="/download"
                    data-hover=""
                    className="inline-flex items-center justify-center gap-2 rounded-full border border-white/15 bg-white/[0.04] px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.7)] transition hover:border-forja-green/40 hover:text-forja-green sm:text-xs"
                  >
                    <Download className="size-3.5" aria-hidden />
                    Download Forja
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

          <section
            id="bundles"
            className="scroll-mt-28 border-t border-[rgba(237,230,218,0.1)] px-[5vw] py-10 sm:py-14"
          >
            <div className="mx-auto max-w-[1400px]">
              <Reveal>
                <div className="mb-6 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between sm:gap-8">
                  <div>
                    <p className="font-mono-ui text-[10px] uppercase tracking-[0.18em] text-forja-flame">
                      Sets
                    </p>
                    <h2 className="mt-1 font-disp text-[clamp(1.5rem,3vw,2rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                      Start with a bundle
                    </h2>
                  </div>
                  <p className="max-w-md text-sm leading-relaxed text-[rgba(237,230,218,0.5)]">
                    Ready-made pack sets in one step. Full catalog below.
                  </p>
                </div>
              </Reveal>

              <PluginBundlesShowcase
                packs={packs ?? []}
                bundles={bundles ?? []}
                isLoading={bundlesLoading || isLoading}
                error={bundlesError ?? null}
              />
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
                    <span className="text-forja-flame">pack catalog</span>
                  </h2>
                  <p className="mt-4 text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
                    Search packs, add them to your profile, and open Forja on a
                    device to download and install.
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
            className="scroll-mt-28 border-t border-[rgba(237,230,218,0.1)] px-[5vw] py-14 sm:py-20"
          >
            <div className="mx-auto max-w-[1400px]">
              <Reveal>
                <div className="mb-8 max-w-2xl">
                  <p className="font-mono-ui text-[10px] uppercase tracking-[0.18em] text-forja-flame">
                    Open source · pack authors
                  </p>
                  <h2 className="mt-2 font-disp text-[clamp(1.75rem,4vw,3rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                    Build packs for the{' '}
                    <span className="text-forja-green">community</span>
                  </h2>
                  <p className="mt-4 text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
                    Forja is a modular player platform. Build a hub, a source, or
                    a live module with the SDK, host your manifest URL, and share
                    it with people who want to install it.
                  </p>
                  <div className="mt-6 flex flex-wrap gap-3">
                    <a
                      href={BUILD_GUIDE_URL}
                      data-hover=""
                      rel="noopener noreferrer"
                      target="_blank"
                      className="btn-magnet inline-flex items-center justify-center rounded-full px-7 py-3 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_28px_rgba(28,231,131,0.3)] sm:text-xs"
                    >
                      Read the guide
                    </a>
                    <a
                      href={FORJA_SOURCE_URL}
                      data-hover=""
                      rel="noopener noreferrer"
                      target="_blank"
                      className="inline-flex items-center justify-center rounded-full border border-white/15 bg-white/[0.04] px-7 py-3 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.7)] transition hover:border-forja-green/40 hover:text-forja-green sm:text-xs"
                    >
                      View source
                    </a>
                  </div>
                </div>
              </Reveal>
              <div className="mt-4 grid gap-4 md:grid-cols-3">
                {BUILD_STEPS.map((step, i) => (
                  <Reveal key={step.n} delayMs={i * 80} variant="scale">
                    <LiquidGlass className="hover-lift flex h-full flex-col border-white/10 p-6 sm:p-7">
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
                      <p className="mt-2 flex-1 text-sm leading-relaxed text-[rgba(237,230,218,0.58)]">
                        {step.copy}
                      </p>
                      {step.internal ? (
                        <a
                          href={step.href}
                          data-hover=""
                          className="mt-5 inline-flex font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] text-forja-green transition hover:text-[#EDE6DA]"
                        >
                          {step.cta} →
                        </a>
                      ) : (
                        <a
                          href={step.href}
                          data-hover=""
                          rel="noopener noreferrer"
                          target="_blank"
                          className="mt-5 inline-flex font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] text-forja-green transition hover:text-[#EDE6DA]"
                        >
                          {step.cta} →
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
                  className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_20%_20%,rgba(255,77,28,0.1),transparent_55%)]"
                />
                <div className="relative flex flex-col items-start gap-6 sm:flex-row sm:items-center sm:justify-between">
                  <div className="max-w-lg">
                    <p className="font-mono-ui text-[10px] uppercase tracking-[0.18em] text-forja-green">
                      No account required to browse
                    </p>
                    <h2 className="mt-2 font-disp text-[clamp(1.75rem,4vw,2.5rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                      Don&apos;t have Forja yet?
                    </h2>
                    <p className="mt-3 text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
                      Download Forja for desktop and Android TV, then install
                      community packs from your profile or paste any pack URL in
                      Settings.
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
