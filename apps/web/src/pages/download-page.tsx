import { useEffect, useMemo, useRef, useState, type MouseEvent } from 'react'
import { Link } from '@tanstack/react-router'
import { CustomCursor } from '@/components/custom-cursor'
import { DownloadHelp } from '@/components/download-help'
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
      <CustomCursor />
      <SiteHeader />

      <main className="relative px-[5vw] pb-16 pt-20 sm:pb-24 sm:pt-28">
        <Reveal>
          <h1 className="font-disp max-w-[14ch] text-[clamp(40px,11vw,140px)] uppercase leading-[0.84] tracking-[-0.04em]">
            Ready to
            <br />
            <span className="text-flame">watch?</span>
          </h1>
          <div className="mt-6 max-w-2xl space-y-4 text-lg leading-relaxed text-[rgba(237,230,218,0.5)]">
            <p>
              Unlimited movies, series, anime, live sport, and TV — free, with no
              ads. Download Forja for your screen and start watching.
            </p>
            <p>
              Windows, Mac, Linux, or Android TV. Same Forja everywhere.
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

        <Reveal delayMs={80}>
          <div className="mt-12 flex flex-wrap items-end justify-between gap-4 border-y border-[rgba(237,230,218,0.14)] py-5">
            <div>
              {isLoading && (
                <p className="font-mono-ui text-xs uppercase tracking-[0.16em] text-[rgba(237,230,218,0.42)]">
                  Checking latest…
                </p>
              )}
              {isError && (
                <p className="font-mono-ui text-xs uppercase tracking-[0.12em] text-red-300">
                  Downloads are taking a break
                  {error instanceof Error ? ` — ${error.message}` : ''}
                </p>
              )}
              {!isLoading && !isError && data && (
                <>
                  <p className="font-disp text-3xl uppercase tracking-tight sm:text-4xl">
                    v{data.version}
                  </p>
                  <p className="font-mono-ui mt-1 text-[11px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.42)]">
                    Fresh as of{' '}
                    {new Date(data.published_at).toLocaleDateString(undefined, {
                      year: 'numeric',
                      month: 'short',
                      day: 'numeric',
                    })}
                  </p>
                </>
              )}
              {!isLoading && !isError && !data && (
                <p className="font-mono-ui text-xs uppercase tracking-[0.14em] text-[rgba(237,230,218,0.42)]">
                  {supabaseConfigured
                    ? 'Nothing to grab yet — check back soon'
                    : 'Downloads are not ready on this site yet'}
                </p>
              )}
            </div>
          </div>
        </Reveal>

        <Reveal delayMs={120}>
          <div className="mt-14">
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
          <div className="mt-16 grid gap-10 border-t border-[rgba(237,230,218,0.14)] pt-12 lg:grid-cols-2">
            <div>
              <div className="space-y-3 text-[rgba(237,230,218,0.5)]">
                <p className="font-serif-i text-xl text-[#EDE6DA] sm:text-2xl">
                  Android TV for the big screen and the remote.
                </p>
                <p className="leading-relaxed">
                  Same movies, series, live TV, and sport as on your computer — made
                  for the couch. If two downloads are listed, pick the one for your TV
                  box; either way you&apos;re watching Forja.
                </p>
              </div>
            </div>
            <div>
              <div className="space-y-3 leading-relaxed text-[rgba(237,230,218,0.5)]">
                <p>
                  An account is optional. Download Forja and watch — no sign-up wall.
                </p>
                <p>
                  If you want one later for preferences across devices, it&apos;s there
                  when you need it.
                </p>
              </div>
              <div className="mt-5 flex flex-wrap gap-4 font-mono-ui text-xs uppercase tracking-[0.12em]">
                <Link to="/signup" className="text-brand hover:text-flame hover:underline">
                  Account
                </Link>
                <Link
                  to="/"
                  className="text-[rgba(237,230,218,0.42)] transition-colors hover:text-[#EDE6DA]"
                >
                  Home
                </Link>
              </div>
            </div>
          </div>
        </Reveal>

        <DownloadHelp />

        {data?.body ? (
          <Reveal delayMs={180}>
            <details className="mt-14 group border-t border-[rgba(237,230,218,0.14)] pt-10">
              <summary className="font-mono-ui cursor-pointer list-none text-xs uppercase tracking-[0.18em] text-[rgba(237,230,218,0.42)] transition-colors hover:text-flame [&::-webkit-details-marker]:hidden">
                <span className="group-open:text-brand">What&apos;s new · v{data.version}</span>
              </summary>
              <pre className="mt-5 max-h-72 overflow-auto whitespace-pre-wrap font-sans text-sm leading-relaxed text-[rgba(237,230,218,0.55)]">
                {data.body}
              </pre>
            </details>
          </Reveal>
        ) : null}
      </main>
    </div>
  )
}
