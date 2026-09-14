import { Link } from '@tanstack/react-router'
import { Code2, Download, Puzzle } from 'lucide-react'
import { Reveal } from '@/components/reveal'
import { SiteFooter } from '@/components/legal-shell'
import { LiquidGlass } from '@/components/liquid-glass'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'
import { cn } from '@/lib/utils'

const BUILD_GUIDE_URL =
  'https://github.com/mGhassen/forja-sdk/blob/main/DEVELOPING.md'
const STARTERS_URL =
  'https://github.com/mGhassen/forja-sdk/tree/main/starters'

const STEPS = [
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
    href: '/plugins',
    cta: 'See Community Packs',
    accent: 'brand' as const,
    internal: true,
  },
]

export function BuildPage() {
  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="plugins" />
      <div className="relative z-10 flex min-h-screen flex-col">
        <SiteHeader solid />

        <main className="flex-1">
          <header className="relative px-[5vw] pb-12 pt-20 sm:pb-16 sm:pt-24 lg:pb-20 lg:pt-28">
            <div className="mx-auto max-w-[900px]">
              <div className="hero-enter">
                <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-forja-flame/35 bg-forja-flame/10 px-3 py-1 font-mono-ui text-[10px] uppercase tracking-[0.16em] text-forja-flame">
                  <Code2 className="size-3.5" aria-hidden />
                  For pack authors
                </div>

                <h1 className="font-disp text-[clamp(2.4rem,6.5vw,4.75rem)] uppercase leading-[0.9] tracking-[-0.04em]">
                  Build community packs
                  <br />
                  <span className="font-serif-i normal-case text-forja-green">
                    for Forja
                  </span>
                </h1>

                <p className="mt-6 max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.58)] sm:text-lg">
                  Forja runs as a host. You build packs — hubs, providers, live
                  modules, and more — that anyone can install. Start from the SDK,
                  follow the guide, host your manifest URL, and share it.
                </p>

                <div className="mt-8 flex flex-wrap gap-3">
                  <a
                    href={BUILD_GUIDE_URL}
                    data-hover=""
                    rel="noopener noreferrer"
                    target="_blank"
                    className="btn-magnet inline-flex items-center justify-center rounded-full px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_32px_rgba(28,231,131,0.35)] will-change-transform sm:text-xs"
                  >
                    Read the guide
                  </a>
                  <Link
                    to="/plugins"
                    data-hover=""
                    className="inline-flex items-center justify-center gap-2 rounded-full border border-white/15 bg-white/[0.04] px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.7)] transition hover:border-forja-flame/40 hover:text-forja-flame sm:text-xs"
                  >
                    <Puzzle className="size-3.5" aria-hidden />
                    Browse packs
                  </Link>
                  <Link
                    to="/download"
                    data-hover=""
                    className="inline-flex items-center justify-center gap-2 rounded-full border border-white/15 bg-white/[0.04] px-8 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.7)] transition hover:border-forja-green/40 hover:text-forja-green sm:text-xs"
                  >
                    <Download className="size-3.5" aria-hidden />
                    Download Forja
                  </Link>
                </div>
              </div>
            </div>
          </header>

          <section className="border-t border-[rgba(237,230,218,0.12)] px-[5vw] py-14 sm:py-20">
            <div className="mx-auto max-w-[1400px]">
              <Reveal>
                <h2 className="font-disp text-[clamp(1.75rem,4vw,2.75rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                  Three steps to{' '}
                  <span className="text-forja-green">ship a pack</span>
                </h2>
              </Reveal>
              <div className="mt-10 grid gap-4 md:grid-cols-3">
                {STEPS.map((step, i) => (
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
                        <Link
                          to="/plugins"
                          data-hover=""
                          className="mt-5 inline-flex font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] text-forja-green transition hover:text-[#EDE6DA]"
                        >
                          {step.cta} →
                        </Link>
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

          <section className="border-t border-[rgba(237,230,218,0.1)] px-[5vw] py-14 sm:py-20">
            <div className="mx-auto max-w-[900px]">
              <Reveal>
                <LiquidGlass className="border-white/10 p-8 sm:p-10">
                  <h2 className="font-disp text-[clamp(1.5rem,3.5vw,2.25rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                    What the host does —{' '}
                    <span className="text-forja-flame">and what you own</span>
                  </h2>
                  <p className="mt-4 text-base leading-relaxed text-[rgba(237,230,218,0.58)]">
                    The host stays generic. Your pack owns the product experience —
                    catalogs, sources, and how titles open. Users install what they
                    want; Forja does not lock the catalog behind a single vendor.
                  </p>
                </LiquidGlass>
              </Reveal>
            </div>
          </section>

          <section className="border-t border-[rgba(237,230,218,0.1)] px-[5vw] py-16 sm:py-24">
            <Reveal>
              <div className="mx-auto flex max-w-[900px] flex-col items-start gap-6 sm:flex-row sm:items-center sm:justify-between">
                <div className="max-w-lg">
                  <h2 className="font-disp text-[clamp(1.75rem,4vw,2.5rem)] uppercase leading-[0.95] tracking-[-0.03em]">
                    Test in the real player
                  </h2>
                  <p className="mt-3 text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
                    Download Forja, add your pack URL, and verify install and
                    playback on desktop or Android TV.
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
            </Reveal>
          </section>
        </main>

        <SiteFooter />
      </div>
    </div>
  )
}
