import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { useEffect, type ReactNode } from 'react'
import { StatusBadge } from '@/components/admin-ui'
import { humanizeScrapeCron } from '@/lib/scrape-cron'
import {
  OPS_OVERVIEW_KEY,
  fetchOpsOverview,
  runDurationLabel,
} from '@/lib/ops-overview'
import { refreshScrapeRuns, subscribeScrapeRuns } from '@/lib/scrape-runs'
import { cn } from '@/lib/utils'

function Cell({
  label,
  value,
  tone,
}: {
  label: string
  value: ReactNode
  tone?: 'green' | 'amber' | 'red' | 'muted'
}) {
  return (
    <div className="min-w-[4.5rem]">
      <div className="text-[10px] font-semibold uppercase tracking-[0.12em] text-forja-muted">
        {label}
      </div>
      <div
        className={cn(
          'mt-0.5 text-sm font-semibold tabular-nums',
          tone === 'green' && 'text-forja-green',
          tone === 'amber' && 'text-amber-300',
          tone === 'red' && 'text-red-300',
          tone === 'muted' && 'text-forja-muted',
          !tone && 'text-forja-text',
        )}
      >
        {value}
      </div>
    </div>
  )
}

export function OpsOverviewStrip() {
  const qc = useQueryClient()
  const overview = useQuery({
    queryKey: OPS_OVERVIEW_KEY,
    queryFn: fetchOpsOverview,
    refetchInterval: (q) =>
      (q.state.data?.runsRunning ?? 0) > 0 ||
      q.state.data?.latest?.status === 'running'
        ? 2_000
        : 20_000,
    refetchOnWindowFocus: true,
  })

  useEffect(() => {
    return subscribeScrapeRuns(() => {
      void refreshScrapeRuns(qc)
    })
  }, [qc])

  const d = overview.data
  const latest = d?.latest

  return (
    <div className="border-b border-forja-border/70 bg-forja-elevated/35">
      <div className="mx-auto flex max-w-7xl flex-col gap-3 px-4 py-3 sm:px-6 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
          <Cell label="All" value={overview.isLoading ? '…' : (d?.all ?? '—')} />
          <Cell label="Pool" value={overview.isLoading ? '…' : (d?.pool ?? '—')} />
          <Cell
            label="Alive"
            value={overview.isLoading ? '…' : (d?.alive ?? '—')}
            tone="green"
          />
          <Cell
            label="Dead"
            value={overview.isLoading ? '…' : (d?.dead ?? '—')}
            tone="red"
          />
          <Cell
            label="Unchecked"
            value={overview.isLoading ? '…' : (d?.unchecked ?? '—')}
            tone="amber"
          />
          <Cell
            label="Credits"
            value={overview.isLoading ? '…' : (d?.creditsTotal ?? '—')}
          />
          <Cell
            label="Runs"
            value={
              overview.isLoading
                ? '…'
                : `${d?.runsOk ?? 0}/${d?.runsTotal ?? 0}`
            }
          />
          {(d?.runsRunning ?? 0) > 0 ? (
            <Cell label="Running" value={d!.runsRunning} tone="amber" />
          ) : null}
        </div>

        <div className="flex min-w-0 flex-wrap items-center gap-3 text-xs">
          {latest ? (
            <>
              <StatusBadge status={latest.status} />
              <span className="text-forja-muted">
                new {latest.posts_seen} · portals {latest.l1_extract_count} · deep{' '}
                {latest.deep_ref_count} · L2 {latest.l2_fetch_ok}/
                {latest.l2_fetch_fail} · unparsed {latest.unparsed_count ?? 0} ·
                upserted {latest.candidates_upserted} ·{' '}
                {runDurationLabel(latest)}
              </span>
            </>
          ) : (
            <span className="text-forja-muted">
              {overview.isLoading ? 'Loading stats…' : 'No scrape runs yet'}
            </span>
          )}
          <span className="hidden text-forja-muted sm:inline">·</span>
          <span
            className={cn(
              'hidden sm:inline',
              d?.scheduleEnabled ? 'text-forja-green' : 'text-amber-300',
            )}
            title={d?.scheduleCron}
          >
            {overview.isLoading
              ? '…'
              : d?.scheduleEnabled
                ? humanizeScrapeCron(d.scheduleCron)
                : 'Schedule off'}
          </span>
          <Link
            to="/scrape"
            className="text-forja-green hover:underline"
          >
            Details
          </Link>
        </div>
      </div>
    </div>
  )
}
