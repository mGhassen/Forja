import { useEffect, useMemo, useRef, useState, type MouseEvent } from 'react'
import { DownloadHelp } from '@/components/download-help'
import { SiteFooter } from '@/components/legal-shell'
import { ReleaseNotes } from '@/components/release-notes'
import { Reveal } from '@/components/reveal'
import { SiteHeader } from '@/components/site-header'
import {
  SHOWCASE_PLATFORMS,
  assetsForPlatform,
  primaryDownloadsByPlatform,
  useLatestRelease,
  type ShowcasePlatform,
  type ShowcasePlatformId,
} from '@/hooks/use-releases'
import { supabaseConfigured } from '@/lib/supabase'
import { startBackgroundDownload } from '@/lib/start-download'
import type { ReleaseAsset } from '@/lib/database.types'
import { cn } from '@/lib/utils'

function formatBytes(n: number | null): string | null {
  if (n == null || n <= 0) return null
  const mb = n / (1024 * 1024)
  if (mb >= 1) return `${mb.toFixed(1)} MB`
  return `${Math.round(n / 1024)} KB`
}

function guessPlatform(): ShowcasePlatformId {
  if (typeof navigator === 'undefined') return 'windows'
  const ua = navigator.userAgent.toLowerCase()
  const plat = navigator.platform?.toLowerCase() ?? ''
  if (plat.includes('mac') || ua.includes('mac')) return 'macos'
  if (plat.includes('linux') || ua.includes('linux')) return 'linux'
  return 'windows'
}

function MagnetDownload({
  href,
  label,
}: {
  href: string
  label: string
}) {
  const magnetRef = useRef<HTMLAnchorElement>(null)

  function onMove(e: MouseEvent<HTMLAnchorElement>) {
    const el = magnetRef.current
    if (!el) return
    if (!window.matchMedia('(hover: hover) and (pointer: fine)').matches) return
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
    const r = el.getBoundingClientRect()
    const x = e.clientX - (r.left + r.width / 2)
    const y = e.clientY - (r.top + r.height / 2)
    el.style.transform = `translate(${x * 0.12}px, ${y * 0.18}px)`
  }

  function onLeave() {
    if (magnetRef.current) magnetRef.current.style.transform = ''
  }

  return (
    <a
      ref={magnetRef}
      href={href}
      data-hover=""
      onMouseMove={onMove}
      onMouseLeave={onLeave}
      onClick={(e) => {
        e.preventDefault()
        startBackgroundDownload(href)
      }}
      className="btn-magnet inline-flex max-w-full items-center justify-center gap-3 rounded-full px-6 py-3.5 text-center font-mono-ui text-[11px] font-bold uppercase tracking-[0.1em] will-change-transform sm:px-8 sm:py-4 sm:text-xs"
    >
      {label}
    </a>
  )
}

function PlatformPicker({
  platforms,
  selectedId,
  onSelect,
  assetsById,
  primaryById,
}: {
  platforms: ShowcasePlatform[]
  selectedId: ShowcasePlatformId
  onSelect: (id: ShowcasePlatformId) => void
  assetsById: Record<ShowcasePlatformId, ReleaseAsset[]>
  primaryById: Record<ShowcasePlatformId, ReleaseAsset | null>
}) {
  const selected = platforms.find((p) => p.id === selectedId) ?? platforms[0]
  const assets = assetsById[selected.id] ?? []
  const primary = primaryById[selected.id] ?? assets[0] ?? null

  return (
    <div className="grid gap-10 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)] lg:gap-16 lg:items-start">
      <nav aria-label="Platforms" className="flex flex-col">
        {platforms.map((platform, i) => {
          const active = platform.id === selected.id
          const file = primaryById[platform.id]
          return (
            <div
              key={platform.id}
              className={cn(
                'group flex items-center gap-3 border-b border-[rgba(237,230,218,0.12)] sm:gap-4',
                active
                  ? 'border-[rgba(237,230,218,0.35)]'
                  : 'hover:border-[rgba(237,230,218,0.22)]',
              )}
            >
              <button
                type="button"
                data-hover=""
                onClick={() => onSelect(platform.id)}
                className="flex min-w-0 flex-1 items-baseline gap-3 py-4 text-left sm:gap-6 sm:py-6"
              >
                <span
                  className={cn(
                    'font-mono-ui w-6 shrink-0 text-[11px] tracking-[0.18em] transition-colors',
                    active
                      ? i % 2 === 0
                        ? 'text-flame'
                        : 'text-brand'
                      : 'text-[rgba(237,230,218,0.28)] group-hover:text-[rgba(237,230,218,0.5)]',
                  )}
                >
                  0{i + 1}
                </span>
                <span
                  className={cn(
                    'font-disp text-[clamp(28px,4.5vw,52px)] uppercase leading-none tracking-[-0.03em] transition-all duration-300',
                    active
                      ? 'translate-x-1 text-[#EDE6DA] sm:translate-x-2'
                      : 'text-[rgba(237,230,218,0.28)] group-hover:text-[rgba(237,230,218,0.55)]',
                  )}
                >
                  {platform.label}
                </span>
              </button>
              {file ? (
                <a
                  href={file.download_url}
                  data-hover=""
                  onClick={(e) => {
                    e.preventDefault()
                    startBackgroundDownload(file.download_url)
                  }}
                  className={cn(
                    'shrink-0 rounded-full px-4 py-2.5 font-mono-ui text-[10px] font-bold uppercase tracking-[0.12em] transition-colors sm:px-5',
                    active
                      ? 'btn-magnet'
                      : 'border border-[rgba(237,230,218,0.2)] text-[rgba(237,230,218,0.7)] hover:border-brand hover:text-brand',
                  )}
                >
                  Download
                </a>
              ) : (
                <span className="shrink-0 rounded-full border border-white/10 px-4 py-2.5 font-mono-ui text-[10px] font-bold uppercase tracking-[0.12em] text-white/25 sm:px-5">
                  Soon
                </span>
              )}
            </div>
          )
        })}
      </nav>

      <div
        key={selected.id}
        className="reveal is-visible relative min-h-[280px] border-t border-[rgba(237,230,218,0.14)] pt-8 lg:border-t-0 lg:border-l lg:pl-12 lg:pt-2"
      >
        <p
          className={cn(
            'font-mono-ui text-[11px] uppercase tracking-[0.2em]',
            selected.id === 'macos' || selected.id === 'linux'
              ? 'text-brand'
              : 'text-flame',
          )}
        >
          {selected.format}
        </p>
        <h2 className="font-disp mt-4 text-[clamp(40px,6vw,72px)] uppercase leading-[0.88] tracking-[-0.03em]">
          {selected.label}
        </h2>
        <p className="font-serif-i mt-3 max-w-md text-xl text-[rgba(237,230,218,0.72)] sm:text-2xl">
          {selected.tagline}
        </p>

        <div className="mt-10 space-y-5">
          {primary ? (
            <MagnetDownload
              href={primary.download_url}
              label={`Get Forja · ${selected.label}`}
            />
          ) : (
            <span className="inline-flex items-center rounded-full border border-white/15 px-8 py-4 font-mono-ui text-xs font-bold uppercase tracking-[0.1em] text-white/35">
              Coming soon
            </span>
          )}

          {assets.length > 0 && (
            <ul className="space-y-2.5 border-t border-[rgba(237,230,218,0.1)] pt-5">
              {assets.map((a) => (
                <li key={a.id}>
                  <a
                    href={a.download_url}
                    onClick={(e) => {
                      e.preventDefault()
                      startBackgroundDownload(a.download_url)
                    }}
                    className="group/file flex flex-wrap items-baseline gap-x-3 gap-y-1 font-mono-ui text-[11px] uppercase tracking-[0.08em] text-[rgba(237,230,218,0.48)] transition-colors hover:text-brand"
                  >
                    <span className="text-[rgba(237,230,218,0.72)] group-hover/file:text-brand">
                      {a.name}
                    </span>
                    {formatBytes(a.size_bytes) ? (
                      <span className="text-[rgba(237,230,218,0.32)]">
                        {formatBytes(a.size_bytes)}
                      </span>
                    ) : null}
                  </a>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  )
}

export function DownloadPage() {
  const { data, isLoading, isError, error } = useLatestRelease()
  const [selectedId, setSelectedId] = useState<ShowcasePlatformId>('windows')

  useEffect(() => {
    setSelectedId(guessPlatform())
  }, [])

  const assetsById = useMemo(() => {
    const map = {} as Record<ShowcasePlatformId, ReleaseAsset[]>
    for (const p of SHOWCASE_PLATFORMS) {
      map[p.id] = assetsForPlatform(data?.assets, p)
    }
    return map
  }, [data?.assets])

  const primaryById = useMemo(
    () => primaryDownloadsByPlatform(data?.assets),
    [data?.assets],
  )

  return (
    <div className="film-grain relative min-h-screen bg-[#0B0A0A] text-[#EDE6DA]">
      <SiteHeader />

      <main className="relative px-[5vw] pb-16 pt-20 sm:pb-24 sm:pt-28">
        <Reveal>
          <h1 className="font-disp max-w-[14ch] text-[clamp(40px,11vw,140px)] uppercase leading-[0.84] tracking-[-0.04em]">
            Get the
            <br />
            <span className="text-flame">player.</span>
          </h1>
          <div className="mt-6 max-w-2xl space-y-4 text-lg leading-relaxed text-[rgba(237,230,218,0.5)]">
            <p>
              Forja is a free media player for streaming - playback, live playlists,
              and controls on the screen you use.
            </p>
            <p>
              Windows, Mac, Linux, or Android TV. Same player everywhere.
            </p>
          </div>
          <div className="mt-8 flex flex-wrap gap-4 font-mono-ui text-[11px] uppercase tracking-[0.14em]">
            <a
              href="#faq"
              className="text-[rgba(237,230,218,0.45)] transition-colors hover:text-brand"
            >
              FAQ
            </a>
            <a
              href="#windows-smartscreen"
              className="text-[rgba(237,230,218,0.45)] transition-colors hover:text-brand"
            >
              Windows blocked the download?
            </a>
            <a
              href="#macos-gatekeeper"
              className="text-[rgba(237,230,218,0.45)] transition-colors hover:text-flame"
            >
              Mac won&apos;t open it?
            </a>
          </div>
        </Reveal>

        {(isLoading || isError || (!isLoading && !isError && !data)) && (
          <Reveal delayMs={80}>
            <div className="mt-12 border-y border-[rgba(237,230,218,0.14)] py-5">
              {isLoading && (
                <p className="font-mono-ui text-xs uppercase tracking-[0.16em] text-[rgba(237,230,218,0.42)]">
                  Checking latest…
                </p>
              )}
              {isError && (
                <p className="font-mono-ui text-xs uppercase tracking-[0.12em] text-red-300">
                  Downloads are taking a break
                  {error instanceof Error ? ` - ${error.message}` : ''}
                </p>
              )}
              {!isLoading && !isError && !data && (
                <p className="font-mono-ui text-xs uppercase tracking-[0.14em] text-[rgba(237,230,218,0.42)]">
                  {supabaseConfigured
                    ? 'Nothing to grab yet - check back soon'
                    : 'Downloads are not ready on this site yet'}
                </p>
              )}
            </div>
          </Reveal>
        )}

        <Reveal delayMs={120}>
          <div id="platforms" className="mt-14 scroll-mt-28">
            <PlatformPicker
              platforms={SHOWCASE_PLATFORMS}
              selectedId={selectedId}
              onSelect={setSelectedId}
              assetsById={assetsById}
              primaryById={primaryById}
            />
          </div>
        </Reveal>

        <Reveal delayMs={160}>
          <section className="relative mt-20 overflow-hidden border-t border-[rgba(237,230,218,0.14)] pt-16">
            <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-brand">
              From download to stream
            </p>
            <h2 className="mt-4 max-w-[14ch] font-disp text-[clamp(40px,8vw,88px)] uppercase leading-[0.88] tracking-[-0.04em]">
              Three steps.
              <br />
              <span className="font-serif-i normal-case text-flame">Zero drama.</span>
            </h2>

            <ol className="mt-14 grid gap-0 border-y border-[rgba(237,230,218,0.14)] md:grid-cols-3">
              {[
                {
                  n: '01',
                  title: 'Pick your screen',
                  body: 'Windows, Mac, Linux, or the TV. One click.',
                },
                {
                  n: '02',
                  title: 'Install & open',
                  body: "First launch takes a minute. Then you're set.",
                },
                {
                  n: '03',
                  title: 'Connect & play',
                  body: 'Add your sources or playlists. Start streaming.',
                },
              ].map((step, i) => (
                <li
                  key={step.n}
                  className={cn(
                    'hover-lift group relative px-0 py-10 md:px-8 md:py-12',
                    i < 2 && 'border-b border-[rgba(237,230,218,0.14)] md:border-b-0 md:border-r',
                  )}
                >
                  <span className="font-mono-ui text-xs tracking-[0.18em] text-flame transition-colors group-hover:text-brand">
                    {step.n}
                  </span>
                  <p className="mt-4 font-disp text-[clamp(26px,3.5vw,40px)] uppercase leading-[0.95] tracking-[-0.03em]">
                    {step.title}
                  </p>
                  <p className="mt-3 max-w-[28ch] text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
                    {step.body}
                  </p>
                </li>
              ))}
            </ol>

            <div className="mt-14 flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
              <p className="max-w-xl font-disp text-[clamp(22px,3.2vw,36px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.72)]">
                Desk. Couch.{' '}
                <span className="text-[#EDE6DA]">Big screen.</span>
                <br />
                <span className="text-brand">Same player.</span>
              </p>
              <a
                href="#platforms"
                className="link-draw font-mono-ui shrink-0 text-[11px] uppercase tracking-[0.16em] text-flame transition-colors hover:text-brand"
              >
                Back to downloads ↑
              </a>
            </div>
          </section>
        </Reveal>

        <DownloadHelp />

        {data?.body ? (
          <Reveal delayMs={180}>
            <details className="mt-14 group border-t border-[rgba(237,230,218,0.14)] pt-10">
              <summary className="font-mono-ui cursor-pointer list-none text-xs uppercase tracking-[0.18em] text-[rgba(237,230,218,0.42)] transition-colors hover:text-flame [&::-webkit-details-marker]:hidden">
                <span className="group-open:text-brand">What&apos;s new · v{data.version}</span>
              </summary>
              <div className="mt-5">
                <ReleaseNotes markdown={data.body} />
              </div>
            </details>
          </Reveal>
        ) : null}
      </main>
      <SiteFooter />
    </div>
  )
}
