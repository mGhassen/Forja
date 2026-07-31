import { useQuery } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { ArrowRight } from 'lucide-react'
import {
  MetricChip,
  PageHeader,
  Panel,
  PanelLabel,
  StatCard,
  StatusBadge,
  tableClassName,
  tableWrapClassName,
  tdClassName,
  thClassName,
} from '@/components/admin-ui'
import { Button } from '@/components/ui/button'
import {
  OPS_OVERVIEW_KEY,
  fetchOpsOverview,
  runDurationLabel,
} from '@/lib/ops-overview'
import { humanizeScrapeCron } from '@/lib/scrape-cron'
import { cn } from '@/lib/utils'

export function AdminDashboardPage() {
  const stats = useQuery({
    queryKey: OPS_OVERVIEW_KEY,
    queryFn: fetchOpsOverview,
    refetchInterval: (q) =>
      (q.state.data?.runsRunning ?? 0) > 0 ? 2_000 : 15_000,
  })

  const d = stats.data
  const loading = stats.isLoading
  const latest = d?.latest

  return (
    <div className="space-y-8">
      <PageHeader
        title="Catalog ops"
        description="Pool health, scrape funnel, credits, and schedule — same numbers as the strip above, with more detail."
        actions={
          <>
            <Button asChild variant="secondary" size="sm">
              <Link to="/scrape">
                Scrape
                <ArrowRight className="size-3.5" />
              </Link>
            </Button>
            <Button asChild size="sm">
              <Link to="/pool">
                Pool
                <ArrowRight className="size-3.5" />
              </Link>
            </Button>
          </>
        }
      />

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Pool"
          value={loading ? '…' : (d?.pool ?? '—')}
          to="/pool"
          hint={`${d?.alive ?? 0} alive · ${d?.dead ?? 0} dead · ${d?.unchecked ?? 0} unchecked`}
        />
        <StatCard
          label="Alive"
          value={loading ? '…' : (d?.alive ?? '—')}
          to="/pool"
          accent="green"
          hint="Deal-ready portals"
        />
        <StatCard
          label="Accounts"
          value={loading ? '…' : (d?.accounts ?? '—')}
          to="/accounts"
          hint={`${d?.scrapeEnabledAccounts ?? 0} with iptvScrape · ${d?.creditsTotal ?? 0} credits`}
        />
        <StatCard
          label="Scrape runs"
          value={loading ? '…' : (d?.runsTotal ?? '—')}
          to="/scrape"
          hint={`${d?.runsOk ?? 0} ok · ${d?.runsError ?? 0} error · ${d?.runsRunning ?? 0} running`}
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Panel tone="accent">
          <PanelLabel>Latest run</PanelLabel>
          {latest ? (
            <div className="mt-3 space-y-3">
              <div className="flex flex-wrap items-center gap-2">
                <StatusBadge status={latest.status} />
                <span className="text-xs text-forja-muted">
                  {new Date(latest.started_at).toLocaleString()}
                  {latest.source ? ` · ${latest.source}` : ''} ·{' '}
                  {runDurationLabel(latest)}
                </span>
              </div>
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
                <MetricChip label="New posts" value={latest.posts_seen} />
                <MetricChip label="Portals" value={latest.l1_extract_count} />
                <MetricChip label="Deep refs" value={latest.deep_ref_count} />
                <MetricChip
                  label="L2 ok/fail"
                  value={`${latest.l2_fetch_ok}/${latest.l2_fetch_fail}`}
                />
                <MetricChip label="L2 portals" value={latest.l2_extract_count} />
                <MetricChip
                  label="Unparsed"
                  value={latest.unparsed_count ?? 0}
                />
                <MetricChip
                  label="Upserted"
                  value={latest.candidates_upserted}
                />
                <MetricChip label="Alive" value={latest.alive_count} />
              </div>
              {latest.error ? (
                <p className="text-sm text-red-400">{latest.error}</p>
              ) : null}
            </div>
          ) : (
            <p className="mt-3 text-sm text-forja-muted">
              {loading ? 'Loading…' : 'No runs yet.'}
            </p>
          )}
          <p className="mt-4 text-xs text-forja-muted">
            Schedule:{' '}
            <span
              className={
                d?.scheduleEnabled ? 'text-forja-green' : 'text-amber-300'
              }
            >
              {loading
                ? '…'
                : d?.scheduleEnabled
                  ? humanizeScrapeCron(d.scheduleCron)
                  : 'off'}
            </span>
            {d?.scheduleCron ? (
              <code className="ml-2 font-mono-ui text-[11px]">
                {d.scheduleCron}
              </code>
            ) : null}
          </p>
        </Panel>

        <Panel>
          <PanelLabel>Pool by region</PanelLabel>
          {(d?.regions.length ?? 0) === 0 ? (
            <p className="mt-3 text-sm text-forja-muted">
              {loading ? 'Loading…' : 'No pool rows yet.'}
            </p>
          ) : (
            <ul className="mt-3 space-y-2">
              {d!.regions.map((r) => (
                <li
                  key={r.region}
                  className="flex items-center justify-between gap-3 text-sm"
                >
                  <span className="font-mono-ui text-xs text-forja-muted">
                    {r.region}
                  </span>
                  <span className="tabular-nums font-semibold">{r.count}</span>
                </li>
              ))}
            </ul>
          )}
          <p className="mt-4 text-xs text-forja-muted">
            Recent 8 runs: {d?.postsSeenTotal ?? 0} posts ·{' '}
            {d?.upsertedTotal ?? 0} upserted
          </p>
        </Panel>
      </div>

      <div>
        <div className="mb-3 flex items-center justify-between gap-3">
          <PanelLabel>Recent runs</PanelLabel>
          <Link
            to="/scrape"
            className="text-sm text-forja-green hover:underline"
          >
            All runs
          </Link>
        </div>
        <div className={tableWrapClassName}>
          <div className="overflow-x-auto">
            <table className={tableClassName}>
              <thead>
                <tr>
                  <th className={thClassName}>Started</th>
                  <th className={thClassName}>Status</th>
                  <th className={thClassName}>Source</th>
                  <th className={thClassName}>Dur</th>
                  <th className={thClassName}>New</th>
                  <th className={thClassName}>Portals</th>
                  <th className={thClassName}>Deep</th>
                  <th className={thClassName}>L2</th>
                  <th className={thClassName}>Upserted</th>
                  <th className={thClassName}>Alive</th>
                </tr>
              </thead>
              <tbody>
                {(d?.recent ?? []).map((r) => (
                  <tr
                    key={r.id}
                    className="border-t border-forja-border/80 hover:bg-white/[0.02]"
                  >
                    <td className={cn(tdClassName, 'whitespace-nowrap text-xs')}>
                      {new Date(r.started_at).toLocaleString()}
                    </td>
                    <td className={tdClassName}>
                      <StatusBadge status={r.status} />
                    </td>
                    <td
                      className={cn(
                        tdClassName,
                        'font-mono-ui text-xs text-forja-muted',
                      )}
                    >
                      {r.source ?? '—'}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums text-xs')}>
                      {runDurationLabel(r)}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {r.posts_seen}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {r.l1_extract_count}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {r.deep_ref_count}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums text-xs')}>
                      {r.l2_fetch_ok}/{r.l2_fetch_fail} · {r.l2_extract_count}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {r.candidates_upserted}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {r.alive_count}
                    </td>
                  </tr>
                ))}
                {!loading && (d?.recent.length ?? 0) === 0 ? (
                  <tr>
                    <td
                      colSpan={10}
                      className={cn(tdClassName, 'text-forja-muted')}
                    >
                      No runs yet.
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  )
}
