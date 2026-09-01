import { useEffect, useMemo, useState } from 'react'
import { Link } from '@tanstack/react-router'
import { Cloud, Download, Puzzle, Sparkles } from 'lucide-react'
import { PluginOrbitVisual } from '@/components/plugin-orbit-visual'
import {
  PluginPackCard,
  PluginPackCardSkeleton,
} from '@/components/plugin-pack-card'
import { Reveal } from '@/components/reveal'
import { SiteFooter } from '@/components/legal-shell'
import { LiquidGlass } from '@/components/liquid-glass'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { SiteHeader } from '@/components/site-header'
import { useAuth } from '@/hooks/use-auth'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import { useForjaPluginCatalog } from '@/hooks/use-forja-plugin-catalog'
import { useForjaSetting } from '@/hooks/use-user-setting'
import { useProfiles } from '@/hooks/use-profiles'
import {
  groupPluginPacksByKind,
  type ForjaPluginKind,
} from '@/lib/forja-plugin-catalog'
import {
  clearPluginInstallIntent,
  packRowFromIntent,
  readPluginInstallIntent,
} from '@/lib/forja-plugin-install'
import {
  emptyForjaPayload,
  type ForjaPayload,
} from '@/lib/sync-domains'
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
  'One tap install',
  'Cloud sync',
] as const

const STEPS = [
  {
    n: '01',
    title: 'Pick a pack',
    copy: 'Browse official engine packs — providers, hubs, live, torrent, IPTV.',
    accent: 'brand' as const,
  },
  {
    n: '02',
    title: 'Add to Forja',
    copy: 'One tap saves the manifest to your profile and pings the app.',
    accent: 'flame' as const,
  },
  {
    n: '03',
    title: 'Play',
    copy: 'Forja fetches scripts on sync. Toggle plugins in Settings → Sources.',
    accent: 'brand' as const,
  },
]

function forjaFromServer(value: unknown): ForjaPayload {
  const payload = value as ForjaPayload | undefined
  return { packs: payload?.packs ?? [] }
}

function usePendingPluginInstall() {
  const { user } = useAuth()
  const { activeProfile } = useProfiles()
  const { data, profileId, isLoading, save } = useForjaSetting()
  const { commit } = useCommitDraft({
    profileId,
    updatedAt: data?.updated_at,
    isReady: Boolean(data) && !isLoading,
    serverValue: data?.payload,
    mapServer: forjaFromServer,
    makeEmpty: emptyForjaPayload,
    save,
  })

  useEffect(() => {
    if (!user || !activeProfile || !data || isLoading) return
    const intent = readPluginInstallIntent()
    if (!intent) return
    const row = packRowFromIntent(intent)
    void commit((prev) => {
      if (prev.packs.some((pack) => pack.manifestUrl === row.manifestUrl)) {
        return prev
      }
      return { packs: [...prev.packs, row] }
    }).finally(() => {
      clearPluginInstallIntent()
    })
  }, [activeProfile, commit, data, isLoading, user])
}

function KindNav({
  kinds,
  active,
  onSelect,
}: {
  kinds: Array<{ kind: ForjaPluginKind; label: string }>
  active: ForjaPluginKind | null
  onSelect: (kind: ForjaPluginKind) => void
}) {
  return (
    <LiquidGlass className="flex flex-wrap gap-1.5 p-2 sm:gap-2">
      {kinds.map((item) => {
        const selected = active === item.kind
        return (
          <button
            key={item.kind}
            type="button"
            onClick={() => onSelect(item.kind)}
            className={cn(
              'rounded-xl px-3.5 py-2 font-mono-ui text-[10px] font-bold uppercase tracking-[0.14em] transition-all duration-200',
              selected
                ? 'bg-forja-green text-[#0B0A0A] shadow-[0_0_20px_rgba(28,231,131,0.35)]'
                : 'text-[rgba(237,230,218,0.5)] hover:bg-white/8 hover:text-forja-green',
            )}
          >
            {item.label}
          </button>
        )
      })}
    </LiquidGlass>
  )
}

export function PluginsPage() {
  const { data: packs, isLoading, error } = useForjaPluginCatalog()
  const [activeKind, setActiveKind] = useState<ForjaPluginKind | null>(null)
  usePendingPluginInstall()

  const groups = packs ? groupPluginPacksByKind(packs) : []
  const kindNav = groups.map((g) => ({ kind: g.kind, label: g.label }))

  const totalPlugins = useMemo(
    () => packs?.reduce((sum, p) => sum + (p.pluginCount ?? 0), 0) ?? 0,
    [packs],
  )

  function scrollToKind(kind: ForjaPluginKind) {
    setActiveKind(kind)
    document.getElementById(`kind-${kind}`)?.scrollIntoView({
      behavior: 'smooth',
      block: 'start',
    })
  }

  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="plugins" />
      <div className="relative z-10 flex min-h-screen flex-col">
        <SiteHeader solid />

        <main className="flex-1">
          {/* Hero */}
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
                  Official remote plugins —{' '}
                  <span className="text-[#EDE6DA]">one tap to install.</span>
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
                        {totalPlugins || '—'}
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

          {/* Marquee */}
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

          {/* How it works */}
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

          {/* Catalog */}
          <section
            id="catalog"
            className="scroll-mt-28 border-t border-[rgba(237,230,218,0.1)] px-[5vw] py-14 sm:py-20"
          >
            <div className="mx-auto max-w-[1400px]">
              <Reveal>
                <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
                  <div className="max-w-xl">
                    <h2 className="font-disp text-[clamp(2rem,5vw,3.5rem)] uppercase leading-[0.92] tracking-[-0.03em]">
                      Official
                      <br />
                      <span className="text-forja-flame">pack catalog.</span>
                    </h2>
                    <p className="mt-4 text-[rgba(237,230,218,0.55)]">
                      Remote manifests from the Forja repo. Add any pack to your
                      profile — the app validates and installs on sync.
                    </p>
                  </div>
                  {!isLoading && kindNav.length > 1 ? (
                    <div className="lg:max-w-md lg:shrink-0">
                      <KindNav
                        kinds={kindNav}
                        active={activeKind}
                        onSelect={scrollToKind}
                      />
                    </div>
                  ) : null}
                </div>
              </Reveal>

              {isLoading ? (
                <div className="mt-12 grid gap-5 sm:grid-cols-2 xl:grid-cols-3">
                  {Array.from({ length: 6 }).map((_, i) => (
                    <PluginPackCardSkeleton key={i} />
                  ))}
                </div>
              ) : error ? (
                <LiquidGlass className="mt-12 border-forja-flame/20 p-8 text-center">
                  <p className="text-forja-flame">
                    {error instanceof Error
                      ? error.message
                      : 'Could not load plugins.'}
                  </p>
                </LiquidGlass>
              ) : (
                <div className="mt-12 space-y-16">
                  {groups.map((group, groupIndex) => (
                    <section
                      key={group.kind}
                      id={`kind-${group.kind}`}
                      className="scroll-mt-32"
                      aria-labelledby={`heading-${group.kind}`}
                    >
                      <Reveal delayMs={groupIndex * 40}>
                        <div className="mb-7 flex items-end gap-4">
                          <h3
                            id={`heading-${group.kind}`}
                            className="font-disp text-[clamp(1.5rem,3vw,2.25rem)] uppercase tracking-[-0.03em] text-[#EDE6DA]"
                          >
                            {group.label}
                          </h3>
                          <span
                            aria-hidden
                            className="mb-1.5 h-px flex-1 bg-linear-to-r from-white/15 to-transparent"
                          />
                          <span className="mb-1 font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.35)]">
                            {group.packs.length} pack
                            {group.packs.length === 1 ? '' : 's'}
                          </span>
                        </div>
                        <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">
                          {group.packs.map((pack, packIndex) => (
                            <Reveal
                              key={pack.id}
                              delayMs={packIndex * 50}
                              variant="scale"
                            >
                              <PluginPackCard pack={pack} index={packIndex} />
                            </Reveal>
                          ))}
                        </div>
                      </Reveal>
                    </section>
                  ))}
                </div>
              )}
            </div>
          </section>

          {/* Bottom CTA */}
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
                      Download free for desktop, mobile, and TV — then come back
                      and add packs in one tap.
                    </p>
                  </div>
                  <Link
                    to="/download"
                    data-hover=""
                    className="btn-magnet shrink-0 inline-flex items-center justify-center rounded-full px-9 py-4 font-mono-ui text-xs font-bold uppercase tracking-[0.1em] shadow-[0_0_32px_rgba(28,231,131,0.35)] will-change-transform sm:text-sm"
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
