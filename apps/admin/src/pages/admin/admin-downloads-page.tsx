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

const PLATFORM_FILL: Record<string, string> = {
  windows: 'bg-sky-400/80',
  macos: 'bg-violet-400/80',
  linux: 'bg-amber-400/80',
  android_tv: 'bg-forja-green/80',
  other: 'bg-white/25',
  ios: 'bg-rose-400/70',
}

export function AdminDownloadsPage() {
  const qc = useQueryClient()
  const [showAllObjects, setShowAllObjects] = useState(false)

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

  const platformMix = useMemo(() => {
    return DOWNLOAD_PLATFORMS.map((p) => ({
      id: p.id,
      label: p.label,
      count: d?.byPlatform[p.id] ?? 0,
    })).filter((p) => p.count > 0 || total === 0)
  }, [d?.byPlatform, total])

  const versions = d?.byVersion ?? []
  const maxVersion = Math.max(1, ...versions.map((v) => v.count))
  const objects = d?.byObject ?? []
  const objectSlice = showAllObjects ? objects : objects.slice(0, 12)

  return (
    <div className="space-y-5">
      <PageHeader
        title="Downloads"
        description="Installer GetObject lifetime rollup · R2 stats/downloads.json"
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
          <p className="mt-1 text-xs text-forja-muted">
            Needs S3 keys +{' '}
            <code className="text-forja-text">CLOUDFLARE_API_TOKEN</code>{' '}
            (Account Analytics Read).
          </p>
        </Panel>
      ) : null}

      {(backfill.isSuccess || rollup.isSuccess) && !actionErr ? (
        <p className="text-xs text-forja-green">
          {backfill.isSuccess
            ? `Backfill wrote ${backfill.data.daysWritten?.length ?? 0} day(s) · ${formatCount(backfill.data.total)} total`
            : `Rolled up yesterday · ${formatCount(rollup.data.total)} total`}
        </p>
      ) : null}

      <Panel tone="accent" className="space-y-5 p-4 sm:p-5">
        {/* Hero strip — total + platform mix, no cards */}
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div className="min-w-0">
            <p className="font-mono-ui text-[10px] font-bold uppercase tracking-[0.18em] text-forja-muted">
              Lifetime installs
            </p>
            <div className="mt-1 flex flex-wrap items-baseline gap-x-3 gap-y-1">
              <span className="font-disp text-4xl font-bold tabular-nums tracking-tight text-forja-green sm:text-5xl">
                {loading || busy ? '…' : formatCount(total)}
              </span>
              <span className="text-sm text-forja-muted">
                {loading
                  ? '…'
                  : d?.dayCount
                    ? `${d.dayCount} day${d.dayCount === 1 ? '' : 's'} rolled`
                    : 'empty — run backfill'}
                {d?.bucket ? ` · ${d.bucket}` : ''}
              </span>
            </div>
            {d?.updatedAt ? (
              <p className="mt-1 text-[11px] text-forja-muted">
                Updated {new Date(d.updatedAt).toLocaleString()}
              </p>
            ) : null}
          </div>

          <div className="flex min-w-0 flex-1 flex-col gap-2 lg:max-w-xl lg:items-end">
            <div className="flex h-2.5 w-full overflow-hidden rounded-full bg-white/[0.06]">
              {loading || busy || total === 0
                ? null
                : platformMix.map((p) => (
                    <div
                      key={p.id}
                      className={cn('h-full', PLATFORM_FILL[p.id] ?? PLATFORM_FILL.other)}
                      style={{ width: `${pct(p.count, total)}%` }}
                      title={`${p.label}: ${formatCount(p.count)}`}
                    />
                  ))}
            </div>
            <div className="flex flex-wrap gap-x-4 gap-y-1 lg:justify-end">
              {DOWNLOAD_PLATFORMS.map((p) => {
                const count = d?.byPlatform[p.id] ?? 0
                return (
                  <div key={p.id} className="flex items-baseline gap-1.5">
                    <span
                      className={cn(
                        'inline-block size-1.5 rounded-full',
                        PLATFORM_FILL[p.id],
                      )}
                      aria-hidden
                    />
                    <span className="text-[11px] text-forja-muted">{p.label}</span>
                    <span className="font-mono-ui text-xs tabular-nums text-forja-text">
                      {loading || busy ? '…' : formatCount(count)}
                    </span>
                    <span className="font-mono-ui text-[10px] tabular-nums text-forja-muted">
                      {loading || busy || total === 0
                        ? ''
                        : `${pct(count, total)}%`}
                    </span>
                  </div>
                )
              })}
            </div>
          </div>
        </div>

        {/* Version matrix — primary dense table */}
        <div>
          <div className="mb-2 flex items-baseline justify-between gap-2">
            <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-forja-muted">
              By release
            </p>
            <p className="text-[10px] text-forja-muted">
              {versions.length} version{versions.length === 1 ? '' : 's'}
            </p>
          </div>
          <div className={tableWrapClassName}>
            <table className={tableClassName}>
              <thead>
                <tr>
                  <th className={thClassName}>Version</th>
                  <th className={thClassName}>Share</th>
                  <th className={`${thClassName} text-right`}>Total</th>
                  {DOWNLOAD_PLATFORMS.map((p) => (
                    <th
                      key={p.id}
                      className={`${thClassName} hidden text-right sm:table-cell`}
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
                ) : versions.length === 0 ? (
                  <tr>
                    <td className={tdClassName} colSpan={6}>
                      No release data yet.
                    </td>
                  </tr>
                ) : (
                  versions.map((row) => (
                    <tr key={row.version} className="group">
                      <td className={`${tdClassName} font-mono text-sm`}>
                        {versionLabel(row.version)}
                      </td>
                      <td className={tdClassName}>
                        <div className="flex min-w-[88px] items-center gap-2 sm:min-w-[140px]">
                          <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-white/[0.06]">
                            <div
                              className="h-full rounded-full bg-forja-green/65"
                              style={{
                                width: `${Math.round((row.count / maxVersion) * 100)}%`,
                              }}
                            />
                          </div>
                          <span className="w-10 shrink-0 text-right font-mono-ui text-[10px] tabular-nums text-forja-muted">
                            {pct(row.count, total)}%
                          </span>
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
                          className={`${tdClassName} hidden text-right font-mono-ui text-xs tabular-nums text-forja-muted sm:table-cell`}
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
        </div>

        {/* Top objects — compact, secondary */}
        <div>
          <div className="mb-2 flex items-baseline justify-between gap-2">
            <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-forja-muted">
              Top objects
            </p>
            {objects.length > 12 ? (
              <button
                type="button"
                className="text-[11px] text-forja-green hover:underline"
                onClick={() => setShowAllObjects((v) => !v)}
              >
                {showAllObjects
                  ? 'Show less'
                  : `Show all ${objects.length}`}
              </button>
            ) : (
              <span className="text-[10px] text-forja-muted">
                {objects.length} file{objects.length === 1 ? '' : 's'}
              </span>
            )}
          </div>
          <div className={tableWrapClassName}>
            <table className={tableClassName}>
              <thead>
                <tr>
                  <th className={thClassName}>Object</th>
                  <th className={`${thClassName} hidden sm:table-cell`}>
                    Platform
                  </th>
                  <th className={`${thClassName} text-right`}>Gets</th>
                  <th className={`${thClassName} hidden text-right sm:table-cell`}>
                    Share
                  </th>
                </tr>
              </thead>
              <tbody>
                {loading || busy ? (
                  <tr>
                    <td className={tdClassName} colSpan={4}>
                      …
                    </td>
                  </tr>
                ) : objectSlice.length === 0 ? (
                  <tr>
                    <td className={tdClassName} colSpan={4}>
                      —
                    </td>
                  </tr>
                ) : (
                  objectSlice.map((row) => (
                    <tr key={row.object}>
                      <td
                        className={`${tdClassName} max-w-[280px] truncate font-mono text-[11px] sm:max-w-none`}
                        title={row.object}
                      >
                        {row.object}
                      </td>
                      <td
                        className={`${tdClassName} hidden text-xs text-forja-muted sm:table-cell`}
                      >
                        {DOWNLOAD_PLATFORMS.find((p) => p.id === row.platform)
                          ?.label ?? row.platform}
                      </td>
                      <td
                        className={`${tdClassName} text-right font-mono-ui text-xs tabular-nums`}
                      >
                        {formatCount(row.count)}
                      </td>
                      <td
                        className={`${tdClassName} hidden text-right font-mono-ui text-[10px] tabular-nums text-forja-muted sm:table-cell`}
                      >
                        {pct(row.count, total)}%
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </Panel>
    </div>
  )
}
