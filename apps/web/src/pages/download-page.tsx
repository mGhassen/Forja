import { Link } from '@tanstack/react-router'
import { useEffect, useMemo, useRef, useState, type MouseEvent, type ReactNode } from 'react'
import { DownloadHelp } from '@/components/download-help'
import { SiteFooter } from '@/components/legal-shell'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { Reveal } from '@/components/reveal'
import { SiteHeader } from '@/components/site-header'
import {
  SHOWCASE_PLATFORMS,
  assetsForPlatform,
  notesForVersion,
  primaryDownloadsByPlatform,
  useChangelogNotes,
  useLatestRelease,
  versionForAsset,
  versionForPlatform,
  type ShowcasePlatform,
  type ShowcasePlatformId,
} from '@/hooks/use-releases'
import {
  guessCpuArch,
  guessOsPlatform,
  type ClientCpuArch,
} from '@/lib/client-platform'
import { startBackgroundDownload } from '@/lib/start-download'
import type { ReleaseAsset } from '@/hooks/use-releases'
import { cn } from '@/lib/utils'

function WindowsIcon({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className={className}
      aria-hidden
      fill="currentColor"
    >
      <path d="M3 5.5 10.5 4.4v7.1H3V5.5Zm0 13L10.5 19.6v-7.1H3v6ZM11.7 4.2 21 3v8.5h-9.3V4.2Zm0 16.6L21 21v-8.5h-9.3v8.3Z" />
    </svg>
  )
}

function AppleIcon({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className={className}
      aria-hidden
      fill="currentColor"
    >
      <path d="M16.7 12.6c0-2.1 1.7-3.1 1.8-3.2-1-1.4-2.5-1.6-3-1.7-1.3-.1-2.5.8-3.1.8-.7 0-1.7-.7-2.8-.7-1.4 0-2.8.9-3.5 2.2-1.5 2.6-.4 6.4 1.1 8.5.7 1 1.6 2.2 2.8 2.1 1.1 0 1.5-.7 2.9-.7s1.7.7 2.9.7c1.2 0 1.9-1 2.7-2 .8-1.2 1.2-2.3 1.2-2.4-.1 0-2.3-.9-2.3-3.6ZM14.9 6.4c.6-.8 1.1-1.8.9-2.9-1 .1-2.1.7-2.7 1.5-.6.7-1.1 1.8-.9 2.8 1 .1 2.1-.5 2.7-1.4Z" />
    </svg>
  )
}

function LinuxIcon({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className={className}
      aria-hidden
      fill="currentColor"
    >
      <path d="M12.5 2c-1.2 0-2.2 1.3-2.2 3 0 1.2.5 2.3 1.3 2.9-.1 0-.3 0-.4.1-2.2.6-3.7 2.8-3.7 5.3 0 1.3.5 2.5 1.3 3.4-.8.7-1.3 1.8-1.3 3 0 2.1 1.7 3.3 4.2 3.3 1.1 0 2.1-.3 2.8-.7.7.4 1.7.7 2.8.7 2.5 0 4.2-1.2 4.2-3.3 0-1.2-.5-2.3-1.3-3 .8-.9 1.3-2.1 1.3-3.4 0-2.5-1.5-4.7-3.7-5.3-.1-.1-.3-.1-.4-.1.8-.6 1.3-1.7 1.3-2.9 0-1.7-1-3-2.2-3zm0 1.5c.4 0 .7.6.7 1.5s-.3 1.5-.7 1.5-.7-.6-.7-1.5.3-1.5.7-1.5zM9.4 9.2c.3 0 .6.1.8.2-.2.4-.3.9-.3 1.4 0 1.1.4 2.1 1.1 2.8-.7.5-1.2 1.4-1.2 2.4 0 .9.4 1.6 1.2 2-.5.3-1.1.5-1.8.5-1.6 0-2.7-.7-2.7-1.8 0-.8.4-1.5 1.1-1.9-.5-.7-.8-1.5-.8-2.4 0-1.7 1.1-3.1 2.6-3.2zm6.2 0c1.5.1 2.6 1.5 2.6 3.2 0 .9-.3 1.7-.8 2.4.7.4 1.1 1.1 1.1 1.9 0 1.1-1.1 1.8-2.7 1.8-.7 0-1.3-.2-1.8-.5.8-.4 1.2-1.1 1.2-2 0-1-.5-1.9-1.2-2.4.7-.7 1.1-1.7 1.1-2.8 0-.5-.1-1-.3-1.4.2-.1.5-.2.8-.2z" />
    </svg>
  )
}

function AndroidTvIcon({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className={className}
      aria-hidden
      fill="currentColor"
    >
      <path d="M4 6.5A2.5 2.5 0 0 1 6.5 4h11A2.5 2.5 0 0 1 20 6.5v8a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 14.5v-8ZM8 19.2h8v1.3H8v-1.3Z" />
    </svg>
  )
}

function PlatformGlyph({
  id,
  className,
}: {
  id: ShowcasePlatformId
  className?: string
}) {
  switch (id) {
    case 'windows':
      return <WindowsIcon className={className} />
    case 'macos':
      return <AppleIcon className={className} />
    case 'linux':
      return <LinuxIcon className={className} />
    case 'android_tv':
      return <AndroidTvIcon className={className} />
  }
}

/** First-open help for Windows / macOS detail panes — always flame (alert), never brand green. */
function PlatformOpenHelp({ platformId }: { platformId: ShowcasePlatformId }) {
  const isWindows = platformId === 'windows'
  const isMac = platformId === 'macos'
  if (!isWindows && !isMac) return null

  return (
    <div className="rounded-2xl border border-flame/30 bg-flame/6 px-5 py-5 sm:px-6">
      <div className="flex items-center gap-2.5">
        {isWindows ? (
          <WindowsIcon className="size-5 shrink-0 text-flame" />
        ) : (
          <AppleIcon className="size-5 shrink-0 text-flame" />
        )}
        <p className="font-mono-ui text-[11px] uppercase tracking-[0.18em] text-flame">
          Stuck opening Forja?
        </p>
      </div>
      <p className="mt-2 text-base leading-relaxed text-[rgba(237,230,218,0.62)]">
        {isWindows
          ? 'Windows often blocks the first open. Photo steps — one click.'
          : 'Mac often blocks the first open. Photo steps — one click.'}
      </p>
      <a
        href={isWindows ? '#windows-smartscreen' : '#macos-gatekeeper'}
        data-hover=""
        className="mt-4 inline-flex items-center justify-center gap-2.5 rounded-full border border-flame/60 bg-flame/15 px-5 py-3 font-mono-ui text-[11px] font-bold uppercase tracking-[0.1em] text-flame transition-colors hover:border-flame hover:bg-flame/25"
      >
        {isWindows ? (
          <WindowsIcon className="size-4 shrink-0" />
        ) : (
          <AppleIcon className="size-4 shrink-0" />
        )}
        {isWindows ? 'Windows blocked it?' : "Mac won't open it?"}
      </a>
    </div>
  )
}

function formatBytes(n: number | null): string | null {
  if (n == null || n <= 0) return null
  const mb = n / (1024 * 1024)
  if (mb >= 1) return `${mb.toFixed(1)} MB`
  return `${Math.round(n / 1024)} KB`
}

/** Short arch / package label from installer filename. */
function assetVariantLabel(
  name: string,
  platformId?: ShowcasePlatformId,
): string {
  const n = name.toLowerCase()
  if (n.includes('armeabi-v7a') || n.includes('armeabi_v7a')) return 'ARMv7'
  if (n.includes('arm64') || n.includes('aarch64')) {
    return platformId === 'macos' ? 'Apple Silicon' : 'ARM64'
  }
  if (n.includes('x86_64') || n.includes('x86-64') || n.includes('amd64')) {
    return platformId === 'macos' ? 'Intel' : 'x86_64'
  }
  if (/\bx86\b/.test(n) || n.includes('i686')) return 'x86'
  if (n.endsWith('.appimage')) return 'AppImage'
  if (n.endsWith('.deb')) return 'Deb'
  if (n.endsWith('.dmg')) return 'DMG'
  if (n.endsWith('.exe')) return 'Installer'
  if (n.endsWith('.apk')) return 'APK'
  return name
}

/** True when the filename encodes CPU arch / package variant worth showing. */
function hasNamedVariant(name: string): boolean {
  const n = name.toLowerCase()
  return (
    n.includes('armeabi-v7a') ||
    n.includes('armeabi_v7a') ||
    n.includes('arm64') ||
    n.includes('aarch64') ||
    n.includes('x86_64') ||
    n.includes('x86-64') ||
    n.includes('amd64') ||
    /\bx86\b/.test(n) ||
    n.includes('i686') ||
    n.endsWith('.appimage') ||
    n.endsWith('.deb')
  )
}

function downloadButtonLabel(
  platform: ShowcasePlatform,
  asset: ReleaseAsset,
  opts?: { multi?: boolean; showVersion?: boolean },
): string {
  const version = opts?.showVersion ? versionForAsset(asset) : null
  const versionSuffix = version ? ` · v${version}` : ''
  if (opts?.multi || hasNamedVariant(asset.name)) {
    return `Get Forja · ${assetVariantLabel(asset.name, platform.id)}${versionSuffix}`
  }
  return `Get Forja · ${platform.label}${versionSuffix}`
}

/** Unique (version, arch label) rows for What's New when arches diverge. */
function changelogEntriesForAssets(
  assets: ReleaseAsset[],
  platformId: ShowcasePlatformId,
  resolveNotes: (version: string | null) => string | null,
): Array<{
  key: string
  version: string
  label: string | null
  title: string
}> {
  const seen = new Set<string>()
  const entries: Array<{
    key: string
    version: string
    label: string | null
    title: string
  }> = []

  for (const asset of assets) {
    const version = versionForAsset(asset)
    if (!version || seen.has(version)) continue
    seen.add(version)
    const notes = resolveNotes(version)
    const title = releaseTitleFromNotes(notes, version)
    if (!title) continue
    entries.push({
      key: version,
      version,
      label:
        assets.length > 1
          ? assetVariantLabel(asset.name, platformId)
          : null,
      title,
    })
  }
  return entries
}

/** Primary asset first, then remaining variants. */
function orderPlatformAssets(
  assets: ReleaseAsset[],
  primary: ReleaseAsset | null,
): ReleaseAsset[] {
  if (!assets.length) return []
  if (!primary) return assets
  const rest = assets.filter((a) => a.id !== primary.id)
  return [primary, ...rest]
}

/** First `# …` heading from a release notes body (e.g. `1.2.365 — Dabaghin`). */
function releaseTitleFromNotes(
  notes: string | null | undefined,
  version: string | null | undefined,
): string | null {
  if (notes) {
    for (const line of notes.split(/\r?\n/)) {
      const t = line.trim()
      if (t.startsWith('# ')) {
        const title = t.slice(2).trim()
        if (title) return title
      }
    }
  }
  return version ? version : null
}

function MagnetDownload({
  href,
  label,
  icon,
}: {
  href: string
  label: string
  icon?: ReactNode
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
      {icon}
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
  versionById,
  resolveNotes,
}: {
  platforms: ShowcasePlatform[]
  selectedId: ShowcasePlatformId
  onSelect: (id: ShowcasePlatformId) => void
  assetsById: Record<ShowcasePlatformId, ReleaseAsset[]>
  primaryById: Record<ShowcasePlatformId, ReleaseAsset | null>
  versionById: Record<ShowcasePlatformId, string | null>
  resolveNotes: (version: string | null) => string | null
}) {
  const selected = platforms.find((p) => p.id === selectedId) ?? platforms[0]
  const assets = assetsById[selected.id] ?? []
  const primary = primaryById[selected.id] ?? assets[0] ?? null
  const orderedAssets = orderPlatformAssets(assets, primary)
  const version = versionById[selected.id] ?? null
  const assetVersions = orderedAssets
    .map((a) => versionForAsset(a))
    .filter((v): v is string => !!v)
  const uniqueVersions = [...new Set(assetVersions)]
  const versionsDiverge = uniqueVersions.length > 1
  const headerVersionLabel = versionsDiverge
    ? uniqueVersions.map((v) => `v${v}`).join(' / ')
    : uniqueVersions[0]
      ? `v${uniqueVersions[0]}`
      : version
        ? `v${version}`
        : null
  const changelogEntries = changelogEntriesForAssets(
    orderedAssets,
    selected.id,
    resolveNotes,
  )

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
                className="flex min-w-0 flex-1 items-center gap-3 py-4 text-left sm:gap-6 sm:py-6"
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
                    'inline-flex min-w-0 items-center gap-2.5 transition-all duration-300 sm:gap-3',
                    active ? 'translate-x-1 sm:translate-x-2' : '',
                  )}
                >
                  <PlatformGlyph
                    id={platform.id}
                    className={cn(
                      'size-5 shrink-0 sm:size-6',
                      active
                        ? i % 2 === 0
                          ? 'text-flame'
                          : 'text-brand'
                        : 'text-[rgba(237,230,218,0.28)] group-hover:text-[rgba(237,230,218,0.5)]',
                    )}
                  />
                  <span
                    className={cn(
                      'font-disp text-[clamp(28px,4.5vw,52px)] uppercase leading-none tracking-[-0.03em] transition-colors duration-300',
                      active
                        ? 'text-[#EDE6DA]'
                        : 'text-[rgba(237,230,218,0.28)] group-hover:text-[rgba(237,230,218,0.55)]',
                    )}
                  >
                    {platform.label}
                  </span>
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
          {headerVersionLabel ? (
            <span className="text-[rgba(237,230,218,0.35)]">
              {' '}
              · {headerVersionLabel}
            </span>
          ) : null}
        </p>
        <h2 className="mt-4 flex flex-wrap items-center gap-3 sm:gap-4">
          <PlatformGlyph
            id={selected.id}
            className={cn(
              'size-8 shrink-0 sm:size-10',
              selected.id === 'macos' || selected.id === 'linux'
                ? 'text-brand'
                : 'text-flame',
            )}
          />
          <span className="font-disp text-[clamp(40px,6vw,72px)] uppercase leading-[0.88] tracking-[-0.03em]">
            {selected.label}
          </span>
        </h2>
        <p className="font-serif-i mt-3 max-w-md text-xl text-[rgba(237,230,218,0.72)] sm:text-2xl">
          {selected.tagline}
        </p>

        <div className="mt-10 space-y-5">
          {orderedAssets.length > 0 ? (
            <div className="flex flex-col items-start gap-3">
              {orderedAssets.map((a) => {
                const size = formatBytes(a.size_bytes)
                const multi = orderedAssets.length > 1
                return (
                  <div key={a.id} className="flex flex-wrap items-center gap-x-4 gap-y-1.5">
                    <MagnetDownload
                      href={a.download_url}
                      label={downloadButtonLabel(selected, a, {
                        multi,
                        showVersion: versionsDiverge,
                      })}
                      icon={
                        <PlatformGlyph
                          id={selected.id}
                          className="size-4 shrink-0"
                        />
                      }
                    />
                    {a.downloader_code ? (
                      <>
                        <span
                          aria-hidden
                          className="font-mono-ui text-lg text-[rgba(237,230,218,0.4)]"
                        >
                          →
                        </span>
                        <span className="font-mono-ui text-[clamp(22px,4vw,32px)] font-bold leading-none tracking-[0.16em] text-[#EDE6DA]">
                          {a.downloader_code}
                        </span>
                      </>
                    ) : null}
                    {size ? (
                      <span className="basis-full font-mono-ui px-1 text-[10px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.32)]">
                        {size}
                      </span>
                    ) : null}
                  </div>
                )
              })}
            </div>
          ) : (
            <span className="inline-flex items-center rounded-full border border-white/15 px-8 py-4 font-mono-ui text-xs font-bold uppercase tracking-[0.1em] text-white/35">
              Coming soon
            </span>
          )}

          <PlatformOpenHelp platformId={selected.id} />

          {changelogEntries.length > 0 ? (
            <div className="space-y-5 border-t border-[rgba(237,230,218,0.1)] pt-5">
              {changelogEntries.map((entry, i) => (
                <div
                  key={entry.key}
                  className={cn(
                    i > 0 && 'border-t border-[rgba(237,230,218,0.08)] pt-5',
                  )}
                >
                  <div className="mb-3 flex flex-wrap items-baseline justify-between gap-3">
                    <p className="font-mono-ui text-[11px] uppercase tracking-[0.16em] text-brand">
                      What&apos;s new
                      {versionsDiverge && entry.label
                        ? ` · ${entry.label}`
                        : ''}
                      {` · v${entry.version}`}
                    </p>
                    <Link
                      to="/changelog"
                      search={{ v: entry.version }}
                      className="font-mono-ui text-[11px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.42)] transition-colors hover:text-flame"
                    >
                      Full changelog →
                    </Link>
                  </div>
                  <p className="font-disp text-xl uppercase tracking-tight text-[#EDE6DA] sm:text-2xl">
                    {entry.title}
                  </p>
                </div>
              ))}
            </div>
          ) : null}
        </div>
      </div>
    </div>
  )
}

export function DownloadPage() {
  const { data, isLoading, isError, error } = useLatestRelease()
  const { data: archiveNotes } = useChangelogNotes()
  const [selectedId, setSelectedId] = useState<ShowcasePlatformId>('windows')
  const [preferredArch, setPreferredArch] = useState<ClientCpuArch | null>(null)

  useEffect(() => {
    setSelectedId(guessOsPlatform())
    void guessCpuArch().then(setPreferredArch)
  }, [])

  const assetsById = useMemo(() => {
    const map = {} as Record<ShowcasePlatformId, ReleaseAsset[]>
    for (const p of SHOWCASE_PLATFORMS) {
      map[p.id] = assetsForPlatform(data?.assets, p)
    }
    return map
  }, [data?.assets])

  const primaryById = useMemo(
    () => primaryDownloadsByPlatform(data?.assets, preferredArch),
    [data?.assets, preferredArch],
  )

  const versionById = useMemo(() => {
    const map = {} as Record<ShowcasePlatformId, string | null>
    for (const p of SHOWCASE_PLATFORMS) {
      map[p.id] = versionForPlatform(data, p.id, preferredArch)
    }
    return map
  }, [data, preferredArch])

  const resolveNotes = useMemo(
    () => (version: string | null) =>
      notesForVersion(version, data, archiveNotes),
    [data, archiveNotes],
  )

  return (
    <div className="film-grain relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="download" />
      <div className="relative z-10">
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
                  Nothing to grab yet - check back soon
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
              versionById={versionById}
              resolveNotes={resolveNotes}
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
      </main>
      <SiteFooter />
      </div>
    </div>
  )
}
