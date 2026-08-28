import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useMemo, useState } from 'react'
import {
  PageHeader,
  Panel,
  tableClassName,
  tableWrapClassName,
  tdClassName,
  thClassName,
} from '@/components/admin-ui'
import { Button } from '@/components/ui/button'
import {
  DOWNLOAD_PLATFORMS,
  DOWNLOAD_STATS_KEY,
  fetchDownloadStats,
  triggerDownloadRollup,
  type DownloadStats,
} from '@/lib/download-stats'
import { cn } from '@/lib/utils'

const VERSION_PREVIEW = 8

function formatCount(n: number | undefined): string {
  if (n == null) return '—'
  return n.toLocaleString()
}

function pct(n: number, total: number): number {
  if (total <= 0) return 0
  return Math.round((n / total) * 1000) / 10
}

function versionLabel(v: string): string {
  if (v === 'latest' || v === 'unknown') return v
  return `v${v}`
}

function toStats(data: DownloadStats): DownloadStats {
  return {
    total: data.total,
    byPlatform: data.byPlatform,
    byObject: data.byObject,
    byVersion: data.byVersion ?? [],
    dayCount: data.dayCount,
    updatedAt: data.updatedAt,
    bucket: data.bucket,
    source: 'r2_rollup',
  }
}

const PLATFORM_ACCENT: Record<string, string> = {
  windows: 'text-sky-300',
  macos: 'text-violet-300',
  linux: 'text-amber-300',
  android_tv: 'text-forja-green',
}

const PLATFORM_BAR: Record<string, string> = {
  windows: 'bg-sky-400',
  macos: 'bg-violet-400',
  linux: 'bg-amber-400',
  android_tv: 'bg-forja-green',
}

export function AdminDownloadsPage() {
  const qc = useQueryClient()
  const [showAllVersions, setShowAllVersions] = useState(false)

  const stats = useQuery({
    queryKey: DOWNLOAD_STATS_KEY,
    queryFn: fetchDownloadStats,
    refetchInterval: 60_000,
  })

  const rollup = useMutation({
    mutationFn: () => triggerDownloadRollup('rollup'),
    onSuccess: (data) => qc.setQueryData(DOWNLOAD_STATS_KEY, toStats(data)),
  })
  const backfill = useMutation({
    mutationFn: () => triggerDownloadRollup('backfill', 30),
    onSuccess: (data) => qc.setQueryData(DOWNLOAD_STATS_KEY, toStats(data)),
  })

  const d = stats.data
  const loading = stats.isLoading
  const loadErr = stats.error instanceof Error ? stats.error.message : null
  const actionErr =
    (rollup.error instanceof Error ? rollup.error.message : null) ||
    (backfill.error instanceof Error ? backfill.error.message : null)
  const busy = rollup.isPending || backfill.isPending
  const total = d?.total ?? 0

  const { semverVersions, otherVersions } = useMemo(() => {
    const all = d?.byVersion ?? []
    const semver: typeof all = []
    const other: typeof all = []
    for (const row of all) {
      if (/^\d+\.\d+\.\d+$/.test(row.version)) semver.push(row)
      else other.push(row)
    }
    return { semverVersions: semver, otherVersions: other }
  }, [d?.byVersion])

  const versionRows = showAllVersions
    ? [...semverVersions, ...otherVersions]
    : semverVersions.slice(0, VERSION_PREVIEW)
  const hiddenCount = Math.max(0, semverVersions.length - VERSION_PREVIEW)
  const maxVersion = Math.max(1, ...versionRows.map((v) => v.count), 1)

  const topObjects = (d?.byObject ?? []).slice(0, 8)

  return (
    <div className="space-y-5">
      <PageHeader
        title="Downloads"
        description="Installer GetObject lifetime · R2 stats/downloads.json"
        actions={
          <>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={busy}
              onClick={() => rollup.mutate()}
            >
              {rollup.isPending ? 'Running…' : 'Roll up yesterday'}
            </Button>
            <Button
              type="button"
              size="sm"
              disabled={busy}
              onClick={() => backfill.mutate()}
            >
              {backfill.isPending ? 'Backfilling…' : 'Backfill 30d'}
            </Button>
          </>
        }
      />

      {loadErr || actionErr ? (
        <Panel tone="accent" className="py-3">
          <p className="text-sm text-amber-300">
            {actionErr
              ? `Backfill/rollup failed: ${actionErr}`
              : `Could not load stats: ${loadErr}`}
          </p>
        </Panel>
      ) : null}

      {(backfill.isSuccess || rollup.isSuccess) && !actionErr ? (
        <p className="text-xs text-forja-green">
          {backfill.isSuccess
            ? `Backfill wrote ${backfill.data.daysWritten?.length ?? 0} day(s) · ${formatCount(backfill.data.total)} total`
            : `Rolled up yesterday · ${formatCount(rollup.data?.total ?? 0)} total`}
        </p>
      ) : null}

      <Panel className="space-y-6 p-4 sm:p-5">
        {/* Total + platforms as equal columns — readable numbers */}
        <div className="grid gap-4 sm:grid-cols-[minmax(0,0.9fr)_minmax(0,1.4fr)] sm:items-stretch">
          <div className="flex flex-col justify-center rounded-xl border border-forja-border/80 bg-black/20 px-4 py-4">
            <p className="font-mono-ui text-[10px] font-bold uppercase tracking-[0.16em] text-forja-muted">
              Lifetime
            </p>
            <p className="mt-1 font-disp text-4xl font-bold tabular-nums tracking-tight text-forja-green sm:text-[2.75rem]">
              {loading || busy ? '…' : formatCount(total)}
            </p>
            <p className="mt-2 text-xs text-forja-muted">
              {loading
                ? '…'
                : d?.dayCount
                  ? `${d.dayCount} days in rollup`
                  : 'No days — backfill'}
              {d?.updatedAt
                ? ` · ${new Date(d.updatedAt).toLocaleString()}`
                : ''}
            </p>
          </div>

          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            {DOWNLOAD_PLATFORMS.map((p) => {
              const count = d?.byPlatform[p.id] ?? 0
              const share = pct(count, total)
              return (
                <div
                  key={p.id}
                  className="flex flex-col justify-between rounded-xl border border-forja-border/80 bg-black/20 px-3 py-3"
                >
                  <p className="text-[10px] font-semibold uppercase tracking-[0.12em] text-forja-muted">
                    {p.label}
                  </p>
                  <p
                    className={cn(
                      'mt-2 font-disp text-2xl font-bold tabular-nums tracking-tight',
                      PLATFORM_ACCENT[p.id],
                    )}
                  >
                    {loading || busy ? '…' : formatCount(count)}
                  </p>
                  <div className="mt-2">
                    <div className="h-1 overflow-hidden rounded-full bg-white/[0.08]">
                      <div
                        className={cn('h-full rounded-full', PLATFORM_BAR[p.id])}
                        style={{ width: `${share}%` }}
                      />
                    </div>
                    <p className="mt-1 font-mono-ui text-[10px] tabular-nums text-forja-muted">
                      {loading || busy || total === 0 ? '—' : `${share}%`}
                    </p>
                  </div>
                </div>
              )
            })}
          </div>
        </div>

        {/* Recent releases only */}
        <div>
          <div className="mb-2 flex flex-wrap items-baseline justify-between gap-2">
            <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-forja-muted">
              Recent releases
            </p>
            <p className="text-[10px] text-forja-muted">
              {showAllVersions
                ? `${semverVersions.length + otherVersions.length} shown`
                : `Newest ${Math.min(VERSION_PREVIEW, semverVersions.length)} of ${semverVersions.length}`}
            </p>
          </div>
          <div className={tableWrapClassName}>
            <table className={tableClassName}>
              <thead>
                <tr>
                  <th className={thClassName}>Version</th>
                  <th className={`${thClassName} text-right`}>Total</th>
                  {DOWNLOAD_PLATFORMS.map((p) => (
                    <th
                      key={p.id}
                      className={`${thClassName} text-right`}
                    >
                      {p.label}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {loading || busy ? (
                  <tr>
                    <td className={tdClassName} colSpan={6}>
                      {busy ? 'Running CF rollup…' : 'Loading…'}
                    </td>
                  </tr>
                ) : versionRows.length === 0 ? (
                  <tr>
                    <td className={tdClassName} colSpan={6}>
                      No release data yet.
                    </td>
                  </tr>
                ) : (
                  versionRows.map((row) => (
                    <tr key={row.version}>
                      <td className={tdClassName}>
                        <div className="flex items-center gap-2.5">
                          <span className="font-mono text-sm text-forja-text">
                            {versionLabel(row.version)}
                          </span>
                          <div className="hidden h-1 max-w-[72px] flex-1 overflow-hidden rounded-full bg-white/[0.06] md:block">
                            <div
                              className="h-full rounded-full bg-forja-green/60"
                              style={{
                                width: `${Math.round((row.count / maxVersion) * 100)}%`,
                              }}
                            />
                          </div>
                        </div>
                      </td>
                      <td
                        className={`${tdClassName} text-right font-mono-ui text-sm tabular-nums font-semibold`}
                      >
                        {formatCount(row.count)}
                      </td>
                      {DOWNLOAD_PLATFORMS.map((p) => (
                        <td
                          key={p.id}
                          className={cn(
                            `${tdClassName} text-right font-mono-ui text-xs tabular-nums`,
                            (row.byPlatform[p.id] ?? 0) > 0
                              ? 'text-forja-text'
                              : 'text-forja-muted/50',
                          )}
                        >
                          {formatCount(row.byPlatform[p.id] ?? 0)}
                        </td>
                      ))}
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          {(hiddenCount > 0 || otherVersions.length > 0) && (
            <button
              type="button"
              className="mt-2 text-[11px] text-forja-green hover:underline"
              onClick={() => setShowAllVersions((v) => !v)}
            >
              {showAllVersions
                ? 'Show recent only'
                : `Show ${hiddenCount + otherVersions.length} more`}
            </button>
          )}
        </div>

        {/* Compact top files */}
        {topObjects.length > 0 ? (
          <div>
            <p className="mb-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-forja-muted">
              Top files
            </p>
            <ul className="divide-y divide-forja-border/60 rounded-xl border border-forja-border/80 bg-black/15">
              {topObjects.map((row) => (
                <li
                  key={row.object}
                  className="flex items-center justify-between gap-3 px-3 py-2"
                >
                  <span
                    className="min-w-0 truncate font-mono text-[11px] text-forja-muted"
                    title={row.object}
                  >
                    {row.object}
                  </span>
                  <span className="shrink-0 font-mono-ui text-xs tabular-nums text-forja-text">
                    {formatCount(row.count)}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        ) : null}
      </Panel>
    </div>
  )
}
