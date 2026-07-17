import { useEffect, useMemo } from 'react'
import { Link, useNavigate } from '@tanstack/react-router'
import { SiteFooter } from '@/components/legal-shell'
import { PageAtmosphere } from '@/components/page-atmosphere'
import { ReleaseNotes } from '@/components/release-notes'
import { SiteHeader } from '@/components/site-header'
import {
  CHANGELOG_MENU_LIMIT,
  cleanReleaseBody,
  useAllReleases,
  type ReleaseWithAssets,
} from '@/hooks/use-releases'
import { cn } from '@/lib/utils'
import { Route as changelogRoute } from '@/routes/changelog'

function formatPublishedAt(iso: string): string {
  try {
    return new Intl.DateTimeFormat(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    }).format(new Date(iso))
  } catch {
    return ''
  }
}

function resolveSelected(
  releases: ReleaseWithAssets[],
  version: string | undefined,
): ReleaseWithAssets | null {
  if (!releases.length) return null
  if (!version) return releases[0] ?? null
  const needle = version.replace(/^v/i, '')
  return (
    releases.find((r) => r.version === needle || r.tag === version || r.tag === `v${needle}`) ??
    releases[0] ??
    null
  )
}

function VersionLink({
  release,
  active,
  variant,
}: {
  release: ReleaseWithAssets
  active: boolean
  variant: 'chip' | 'row'
}) {
  if (variant === 'chip') {
    return (
      <Link
        to="/changelog"
        search={{ v: release.version }}
        className={cn(
          'shrink-0 rounded-full border px-3.5 py-2 font-mono-ui text-[11px] uppercase tracking-[0.12em] transition-colors',
          active
            ? 'border-forja-green bg-forja-green text-[#0B0A0A]'
            : 'border-[rgba(237,230,218,0.16)] text-[rgba(237,230,218,0.55)] hover:border-forja-green/40 hover:text-forja-green',
        )}
      >
        v{release.version}
      </Link>
    )
  }

  return (
    <Link
      to="/changelog"
      search={{ v: release.version }}
      className={cn(
        'relative flex min-h-14 flex-col justify-center border-l-[3px] px-3 py-2.5 transition-colors',
        active
          ? 'border-forja-green bg-white/[0.035] text-[#EDE6DA]'
          : 'border-transparent text-[rgba(237,230,218,0.5)] hover:bg-white/2 hover:text-[#EDE6DA]',
      )}
    >
      <span
        className={cn(
          'font-mono-ui text-[12px] uppercase tracking-[0.1em]',
          active ? 'font-bold text-forja-green' : 'font-medium',
        )}
      >
        v{release.version}
      </span>
      <span className="mt-0.5 text-[11px] text-[rgba(237,230,218,0.38)]">
        {formatPublishedAt(release.published_at) || '—'}
      </span>
    </Link>
  )
}

export function ChangelogPage() {
  const navigate = useNavigate({ from: '/changelog' })
  const { v: versionParam } = changelogRoute.useSearch()
  const { data, isLoading, isError, error } = useAllReleases()

  const releases = useMemo(
    () => (data ?? []).slice(0, CHANGELOG_MENU_LIMIT),
    [data],
  )
  const selected = useMemo(
    () => resolveSelected(releases, versionParam),
    [releases, versionParam],
  )

  useEffect(() => {
    if (!selected) return
    if (versionParam === selected.version) return
    void navigate({
      search: { v: selected.version },
      replace: true,
    })
  }, [navigate, selected, versionParam])

  const notes = selected ? cleanReleaseBody(selected.body) : ''

  return (
    <div className="relative min-h-screen bg-forja-bg text-[#EDE6DA]">
      <PageAtmosphere recipe="quiet" />
      <div className="relative z-10">
      <SiteHeader solid />
      <main className="mx-auto max-w-6xl px-5 pb-20 pt-24 sm:px-6 sm:pt-28">
        <p className="font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green">
          Releases
        </p>
        <h1 className="mt-4 font-disp text-[clamp(36px,7vw,56px)] uppercase leading-[0.92] tracking-[-0.03em]">
          Changelog
        </h1>
        <p className="mt-4 max-w-xl text-base leading-relaxed text-[rgba(237,230,218,0.55)]">
          What changed in each Forja release — notes stay on this site.
        </p>

        {isLoading ? (
          <p className="mt-14 font-mono-ui text-xs uppercase tracking-[0.16em] text-[rgba(237,230,218,0.4)]">
            Loading releases…
          </p>
        ) : null}

        {isError ? (
          <p className="mt-14 text-sm text-flame">
            Could not load releases
            {error instanceof Error ? `: ${error.message}` : '.'}
          </p>
        ) : null}

        {!isLoading && !isError && releases.length === 0 ? (
          <p className="mt-14 text-sm text-[rgba(237,230,218,0.45)]">
            No releases published yet.
          </p>
        ) : null}

        {!isLoading && !isError && selected ? (
          <div className="mt-12 grid gap-10 lg:grid-cols-[minmax(0,240px)_minmax(0,1fr)] lg:gap-14 lg:items-start">
            <aside className="min-w-0">
              <p className="mb-3 font-mono-ui text-[10px] font-bold uppercase tracking-[0.16em] text-forja-green lg:px-3">
                Versions
              </p>

              {/* Mobile: horizontal chip row */}
              <nav
                aria-label="Release versions"
                className="-mx-5 flex gap-2 overflow-x-auto px-5 pb-2 lg:hidden"
              >
                {releases.map((release) => (
                  <VersionLink
                    key={release.id}
                    release={release}
                    active={release.id === selected.id}
                    variant="chip"
                  />
                ))}
              </nav>

              {/* Desktop: left menu — latest 20 only */}
              <nav
                aria-label="Release versions"
                className="hidden max-h-[min(70vh,36rem)] overflow-y-auto lg:block"
              >
                {releases.map((release) => (
                  <VersionLink
                    key={release.id}
                    release={release}
                    active={release.id === selected.id}
                    variant="row"
                  />
                ))}
              </nav>
            </aside>

            <article className="min-w-0 border-t border-[rgba(237,230,218,0.12)] pt-8 lg:border-t-0 lg:pt-0">
              <p className="font-mono-ui text-[11px] uppercase tracking-[0.18em] text-forja-green">
                What&apos;s new · v{selected.version}
              </p>
              <p className="mt-2 text-sm text-forja-muted">
                {formatPublishedAt(selected.published_at) || 'Release notes'}
              </p>
              <div className="mt-8">
                <ReleaseNotes
                  markdown={notes || selected.body || ''}
                  className="max-h-none overflow-visible text-base sm:text-[17px]"
                  emptyLabel="No detailed notes were published for this release."
                />
              </div>
              <div className="mt-12 flex flex-wrap gap-4 border-t border-[rgba(237,230,218,0.1)] pt-6">
                <Link
                  to="/download"
                  className="font-mono-ui text-[11px] uppercase tracking-[0.14em] text-flame transition-colors hover:text-brand"
                >
                  Download latest →
                </Link>
              </div>
            </article>
          </div>
        ) : null}
      </main>
      <SiteFooter />
      </div>
    </div>
  )
}
