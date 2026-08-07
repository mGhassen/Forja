import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  PageHeader,
  Panel,
  PanelLabel,
  StatCard,
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
} from '@/lib/download-stats'

function formatCount(n: number | undefined): string {
  if (n == null) return '—'
  return n.toLocaleString()
}

export function AdminDownloadsPage() {
  const qc = useQueryClient()
  const stats = useQuery({
    queryKey: DOWNLOAD_STATS_KEY,
    queryFn: fetchDownloadStats,
    refetchInterval: 60_000,
  })

  const rollup = useMutation({
    mutationFn: () => triggerDownloadRollup('rollup'),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: DOWNLOAD_STATS_KEY })
    },
  })
  const backfill = useMutation({
    mutationFn: () => triggerDownloadRollup('backfill', 30),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: DOWNLOAD_STATS_KEY })
    },
  })

  const d = stats.data
  const loading = stats.isLoading
  const err = stats.error instanceof Error ? stats.error.message : null

  const platformRows = [
    ...DOWNLOAD_PLATFORMS.map((p) => ({
      id: p.id,
      label: p.label,
      count: d?.byPlatform[p.id] ?? 0,
    })),
    ...Object.entries(d?.byPlatform ?? {})
      .filter(
        ([id, count]) =>
          count > 0 && !DOWNLOAD_PLATFORMS.some((p) => p.id === id),
      )
      .map(([id, count]) => ({ id, label: id, count })),
  ].sort((a, b) => b.count - a.count || a.label.localeCompare(b.label))

  const maxPlatform = Math.max(1, ...platformRows.map((r) => r.count))

  return (
    <div className="space-y-8">
      <PageHeader
        title="Downloads"
        description="Lifetime installer GetObject totals from R2 stats/downloads.json (Inngest rolls up Cloudflare Analytics daily)."
        actions={
          <>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={rollup.isPending || backfill.isPending}
              onClick={() => rollup.mutate()}
            >
              {rollup.isPending ? 'Queuing…' : 'Roll up yesterday'}
            </Button>
            <Button
              type="button"
              size="sm"
              disabled={rollup.isPending || backfill.isPending}
              onClick={() => backfill.mutate()}
            >
              {backfill.isPending ? 'Queuing…' : 'Backfill 30d'}
            </Button>
          </>
        }
      />

      {err ? (
        <Panel tone="accent">
          <p className="text-sm text-amber-300">Could not load stats: {err}</p>
          <p className="mt-2 text-xs text-forja-muted">
            Reads via <code className="text-forja-text">RELEASE_CDN_URL</code>
            /stats/downloads.json (or R2 S3 keys). Writes need S3 keys +{' '}
            <code className="text-forja-text">CLOUDFLARE_API_TOKEN</code> —
            set those on Vercel, then run <strong>Backfill 30d</strong>.
          </p>
        </Panel>
      ) : null}

      {(rollup.isSuccess || backfill.isSuccess) && (
        <p className="text-xs text-forja-muted">
          Inngest job queued — refresh in a minute.
        </p>
      )}

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Total"
          value={loading ? '…' : formatCount(d?.total)}
          accent="green"
          hint={
            d?.dayCount
              ? `${d.dayCount} day(s) in rollup · ${d.bucket}`
              : 'No days yet — backfill'
          }
        />
        {DOWNLOAD_PLATFORMS.map((p) => (
          <StatCard
            key={p.id}
            label={p.label}
            value={loading ? '…' : formatCount(d?.byPlatform[p.id])}
          />
        ))}
      </div>

      {d?.updatedAt ? (
        <p className="text-xs text-forja-muted">
          Rollup updated {new Date(d.updatedAt).toLocaleString()} · object{' '}
          <code className="text-forja-text">stats/downloads.json</code>
        </p>
      ) : null}

      <Panel>
        <PanelLabel>By platform</PanelLabel>
        <div className={`${tableWrapClassName} mt-4`}>
          <table className={tableClassName}>
            <thead>
              <tr>
                <th className={thClassName}>Platform</th>
                <th className={thClassName}>Downloads</th>
                <th className={`${thClassName} hidden sm:table-cell`}>Share</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td className={tdClassName} colSpan={3}>
                    Loading…
                  </td>
                </tr>
              ) : platformRows.every((r) => r.count === 0) ? (
                <tr>
                  <td className={tdClassName} colSpan={3}>
                    Empty rollup — click Backfill 30d.
                  </td>
                </tr>
              ) : (
                platformRows.map((row) => {
                  const pct =
                    (d?.total ?? 0) > 0
                      ? Math.round((row.count / (d?.total ?? 1)) * 1000) / 10
                      : 0
                  const bar = Math.round((row.count / maxPlatform) * 100)
                  return (
                    <tr key={row.id}>
                      <td className={tdClassName}>
                        <div className="font-medium text-forja-text">
                          {row.label}
                        </div>
                        <div className="mt-1.5 h-1.5 max-w-[220px] overflow-hidden rounded-full bg-white/[0.06]">
                          <div
                            className="h-full rounded-full bg-forja-green/70"
                            style={{ width: `${bar}%` }}
                          />
                        </div>
                      </td>
                      <td className={`${tdClassName} tabular-nums`}>
                        {formatCount(row.count)}
                      </td>
                      <td
                        className={`${tdClassName} hidden tabular-nums text-forja-muted sm:table-cell`}
                      >
                        {pct}%
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
      </Panel>

      <Panel>
        <PanelLabel>Top objects (lifetime)</PanelLabel>
        <div className={`${tableWrapClassName} mt-4`}>
          <table className={tableClassName}>
            <thead>
              <tr>
                <th className={thClassName}>Object</th>
                <th className={thClassName}>Platform</th>
                <th className={thClassName}>Gets</th>
              </tr>
            </thead>
            <tbody>
              {(d?.byObject ?? []).slice(0, 25).map((row) => (
                <tr key={row.object}>
                  <td className={`${tdClassName} font-mono text-xs`}>
                    {row.object}
                  </td>
                  <td className={tdClassName}>{row.platform}</td>
                  <td className={`${tdClassName} tabular-nums`}>
                    {formatCount(row.count)}
                  </td>
                </tr>
              ))}
              {!loading && !(d?.byObject?.length) ? (
                <tr>
                  <td className={tdClassName} colSpan={3}>
                    —
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </Panel>
    </div>
  )
}
