import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { ExternalLink, RefreshCw } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import {
  EmptyState,
  MetricChip,
  PageHeader,
  Panel,
  PanelLabel,
  StatusBadge,
  TablePagination,
  tableClassName,
  tableWrapClassName,
  tdClassName,
  thClassName,
} from '@/components/admin-ui'
import { FullScrapeDialog } from '@/components/confirm-dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { adminDb } from '@/lib/admin-db'
import { INNGEST_UI_URL, isInngestLocalUi } from '@/lib/inngest-ui'
import {
  DEFAULT_SCRAPE_CRON,
  SCRAPE_CRON_PRESETS,
  dailyCronFromUtc,
  humanizeScrapeCron,
  isValidScrapeCron,
  parseDailyUtc,
} from '@/lib/scrape-cron'
import { scrapeControl } from '@/lib/scrape-control'
import { runDurationLabel } from '@/lib/ops-overview'
import {
  SCRAPE_RUNS_KEY,
  fetchScrapeRuns,
  isOpsBackfillRun,
  isPromoteBackfillRun,
  markRunsStoppedInCache,
  prependOptimisticRun,
  refreshScrapeRuns,
  scrapeRunMetricChips,
  scrapeSourceLabel,
  subscribeScrapeRuns,
} from '@/lib/scrape-runs'
import { formatAdminDateTime } from '@/lib/iptv-portal-expiry'
import { cn } from '@/lib/utils'
import { useTablePagination } from '@/lib/use-table-pagination'

export function AdminScrapePage() {
  const qc = useQueryClient()
  const list = useQuery({
    queryKey: SCRAPE_RUNS_KEY,
    queryFn: () => fetchScrapeRuns(),
    refetchInterval: (q) =>
      q.state.data?.some((r) => r.status === 'running') ? 1_500 : 8_000,
    refetchOnWindowFocus: true,
  })

  const paging = useTablePagination(list.data ?? [], { initialPageSize: 50 })

  useEffect(() => {
    return subscribeScrapeRuns(() => {
      void refreshScrapeRuns(qc)
    })
  }, [qc])

  const latest = list.data?.[0] ?? null
  const running = latest?.status === 'running'
  const [confirmFull, setConfirmFull] = useState(false)

  const start = useMutation({
    mutationFn: (opts: {
      forceFull: boolean
      maxPages?: number
      startPage?: number
      endPage?: number
    }) =>
      scrapeControl('start', {
        forceFull: opts.forceFull,
        maxPages: opts.maxPages,
        startPage: opts.startPage,
        endPage: opts.endPage,
      }),
    onSuccess: async (res) => {
      setConfirmFull(false)
      if (res.run) {
        prependOptimisticRun(qc, res.run)
      } else if (res.runId) {
        prependOptimisticRun(qc, {
          id: res.runId,
          started_at: new Date().toISOString(),
          status: 'running',
          source: 'manual-admin',
        })
      }
      await refreshScrapeRuns(qc)
    },
  })
  const stop = useMutation({
    mutationFn: () => scrapeControl('stop', { runId: latest?.id }),
    onMutate: async () => {
      await qc.cancelQueries({ queryKey: ['admin', 'scrape_runs'] })
      markRunsStoppedInCache(qc, {
        runId: latest?.id,
        error: 'Stop requested from admin',
      })
    },
    onSuccess: async () => {
      await refreshScrapeRuns(qc)
    },
    onError: async () => {
      await refreshScrapeRuns(qc)
    },
  })
  const markStuck = useMutation({
    mutationFn: () => scrapeControl('mark_stuck'),
    onMutate: async () => {
      await qc.cancelQueries({ queryKey: ['admin', 'scrape_runs'] })
      markRunsStoppedInCache(qc, {
        error: 'Marked stuck from admin (Inngest may have died)',
      })
    },
    onSuccess: async () => {
      await refreshScrapeRuns(qc)
    },
    onError: async () => {
      await refreshScrapeRuns(qc)
    },
  })

  const settings = useQuery({
    queryKey: ['admin', 'iptv_ops_settings'],
    queryFn: async () => {
      const { data, error } = await adminDb
        .from('iptv_ops_settings')
        .select('scrape_cron_enabled, scrape_cron, updated_at')
        .eq('id', 1)
        .maybeSingle()
      if (error) throw error
      return (
        data ?? {
          scrape_cron_enabled: true,
          scrape_cron: DEFAULT_SCRAPE_CRON,
          updated_at: null as string | null,
        }
      )
    },
  })

  const savedCron =
    typeof settings.data?.scrape_cron === 'string' &&
    settings.data.scrape_cron.trim()
      ? settings.data.scrape_cron.trim()
      : DEFAULT_SCRAPE_CRON

  const [draftCron, setDraftCron] = useState(DEFAULT_SCRAPE_CRON)
  useEffect(() => {
    if (settings.isSuccess) setDraftCron(savedCron)
  }, [settings.isSuccess, savedCron])

  const daily = parseDailyUtc(draftCron)
  const [hour, setHour] = useState(6)
  const [minute, setMinute] = useState(0)
  useEffect(() => {
    if (daily) {
      setHour(daily.hour)
      setMinute(daily.minute)
    }
  }, [daily?.hour, daily?.minute])

  const presetId = useMemo(() => {
    const hit = SCRAPE_CRON_PRESETS.find((p) => p.cron === draftCron)
    return hit?.id ?? (daily ? 'daily-custom' : 'custom')
  }, [draftCron, daily])

  const cronValid = isValidScrapeCron(draftCron)
  const humanCron = humanizeScrapeCron(draftCron)
  const scheduleDirty = draftCron.trim() !== savedCron

  const setCronEnabled = useMutation({
    mutationFn: async (enabled: boolean) => {
      const { error } = await adminDb
        .from('iptv_ops_settings')
        .update({ scrape_cron_enabled: enabled })
        .eq('id', 1)
      if (error) throw error
    },
    onMutate: async (enabled) => {
      await qc.cancelQueries({ queryKey: ['admin', 'iptv_ops_settings'] })
      const prev = qc.getQueryData(['admin', 'iptv_ops_settings'])
      qc.setQueryData(['admin', 'iptv_ops_settings'], (old: unknown) => ({
        ...(old && typeof old === 'object' ? old : {}),
        scrape_cron_enabled: enabled,
        scrape_cron: savedCron,
      }))
      return { prev }
    },
    onError: (_e, _v, ctx) => {
      if (ctx?.prev) qc.setQueryData(['admin', 'iptv_ops_settings'], ctx.prev)
    },
    onSettled: async () => {
      await qc.invalidateQueries({ queryKey: ['admin', 'iptv_ops_settings'] })
      await qc.refetchQueries({ queryKey: ['admin', 'iptv_ops_settings'] })
    },
  })

  const saveSchedule = useMutation({
    mutationFn: async (cron: string) => {
      const next = cron.trim()
      if (!isValidScrapeCron(next)) {
        throw new Error('Invalid cron (need 5 UTC fields: min hour dom month dow)')
      }
      const { error } = await adminDb
        .from('iptv_ops_settings')
        .update({ scrape_cron: next })
        .eq('id', 1)
      if (error) throw error
      return next
    },
    onSuccess: async (next) => {
      qc.setQueryData(['admin', 'iptv_ops_settings'], (old: unknown) => ({
        ...(old && typeof old === 'object' ? old : {}),
        scrape_cron: next,
        scrape_cron_enabled: cronEnabled,
      }))
      await qc.invalidateQueries({ queryKey: ['admin', 'iptv_ops_settings'] })
      await qc.refetchQueries({ queryKey: ['admin', 'iptv_ops_settings'] })
    },
  })

  const cronEnabled = settings.data?.scrape_cron_enabled !== false

  const busy =
    start.isPending ||
    stop.isPending ||
    markStuck.isPending ||
    setCronEnabled.isPending ||
    saveSchedule.isPending
  const err =
    (start.error as Error | null)?.message ||
    (stop.error as Error | null)?.message ||
    (markStuck.error as Error | null)?.message ||
    (setCronEnabled.error as Error | null)?.message ||
    (saveSchedule.error as Error | null)?.message ||
    (settings.error as Error | null)?.message

  return (
    <div className="space-y-8">
      <PageHeader
        title="Scrape"
        description="Run jobs, watch live metrics, and set the UTC schedule. Inventory lives in Pool."
        actions={
          <>
            <Button asChild variant="ghost" size="sm">
              <Link to="/pool">Pool</Link>
            </Button>
            <Button asChild variant="ghost" size="sm">
              <Link to="/deep-refs">Deep refs</Link>
            </Button>
            <Button asChild variant="secondary" size="sm">
              <a href={INNGEST_UI_URL} target="_blank" rel="noreferrer">
                Inngest
                <ExternalLink className="size-3.5" />
              </a>
            </Button>
          </>
        }
      />

      <Panel tone="accent">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="min-w-0 space-y-3">
            <PanelLabel>
              {latest && isOpsBackfillRun(latest)
                ? 'Current backfill'
                : 'Current run'}
            </PanelLabel>
            {latest ? (
              <>
                <div className="flex flex-wrap items-center gap-2">
                  <StatusBadge status={latest.status} />
                  <span className="text-xs text-forja-muted">
                    {formatAdminDateTime(latest.started_at)}
                    {latest.source
                      ? ` · ${scrapeSourceLabel(latest.source)}`
                      : ''}
                  </span>
                </div>
                <div
                  className={cn(
                    'grid grid-cols-2 gap-2 sm:grid-cols-3',
                    isPromoteBackfillRun(latest)
                      ? 'lg:grid-cols-4'
                      : isOpsBackfillRun(latest)
                        ? 'lg:grid-cols-5'
                        : 'lg:grid-cols-9',
                  )}
                >
                  {scrapeRunMetricChips(latest).map((c) => (
                    <MetricChip key={c.label} label={c.label} value={c.value} />
                  ))}
                </div>
                <p className="text-xs text-forja-muted">
                  Duration {runDurationLabel(latest)}
                  {latest.finished_at
                    ? ` · finished ${formatAdminDateTime(latest.finished_at)}`
                    : ' · in progress'}
                </p>
                {latest.error ? (
                  <p className="text-sm text-red-400">{latest.error}</p>
                ) : null}
              </>
            ) : (
              <p className="text-sm text-forja-muted">No runs yet.</p>
            )}
          </div>
          <div className="flex flex-wrap gap-2">
            <Button
              type="button"
              variant="ghost"
              size="sm"
              disabled={list.isFetching}
              onClick={() => void refreshScrapeRuns(qc)}
            >
              <RefreshCw
                className={cn('size-3.5', list.isFetching && 'animate-spin')}
              />
              Refresh
            </Button>
            <Button
              type="button"
              disabled={busy || running}
              onClick={() => start.mutate({ forceFull: false })}
            >
              {start.isPending ? 'Starting…' : 'Run normal'}
            </Button>
            <Button
              type="button"
              variant="secondary"
              disabled={busy || running}
              onClick={() => setConfirmFull(true)}
            >
              {start.isPending ? 'Starting…' : 'Run full'}
            </Button>
            <Button
              type="button"
              variant="secondary"
              disabled={busy || !running}
              onClick={() => stop.mutate()}
            >
              {stop.isPending ? 'Stopping…' : 'Stop'}
            </Button>
            <Button
              type="button"
              variant="ghost"
              disabled={busy || !running}
              onClick={() => markStuck.mutate()}
            >
              Mark stuck
            </Button>
          </div>
        </div>
        {err ? <p className="mt-4 text-sm text-red-400">{err}</p> : null}
      </Panel>

      <FullScrapeDialog
        open={confirmFull}
        busy={start.isPending}
        onClose={() => {
          if (!start.isPending) setConfirmFull(false)
        }}
        onConfirm={(range) =>
          start.mutate({
            forceFull: true,
            startPage: range.startPage,
            endPage: range.endPage,
          })
        }
      />

      <div className="grid gap-4 lg:grid-cols-2">
        <Panel>
          <PanelLabel>Automation</PanelLabel>
          <div className="mt-3 flex flex-wrap items-center justify-between gap-3">
            <div>
              <p
                className={cn(
                  'text-sm font-semibold',
                  cronEnabled ? 'text-forja-green' : 'text-amber-400',
                )}
              >
                {settings.isLoading
                  ? 'Loading…'
                  : cronEnabled
                    ? 'Schedule on'
                    : 'Schedule off'}
              </p>
              <p className="mt-0.5 text-xs text-forja-muted">
                Off = ticks no-op; manual run still works
              </p>
            </div>
            <button
              type="button"
              role="switch"
              aria-checked={cronEnabled}
              disabled={setCronEnabled.isPending || settings.isLoading}
              onClick={() => setCronEnabled.mutate(!cronEnabled)}
              className={cn(
                'relative h-7 w-12 shrink-0 rounded-full transition-colors',
                cronEnabled ? 'bg-forja-green' : 'bg-white/15',
                (setCronEnabled.isPending || settings.isLoading) &&
                  'opacity-60',
              )}
            >
              <span
                className={cn(
                  'absolute top-0.5 size-6 rounded-full bg-[#0B0A0A] shadow transition-transform',
                  cronEnabled ? 'left-5' : 'left-0.5',
                )}
              />
            </button>
          </div>

          <div className="mt-5 space-y-3 border-t border-forja-border pt-4">
            <div className="space-y-1.5">
              <Label htmlFor="scrape-preset">Preset</Label>
              <Select
                value={presetId}
                disabled={settings.isLoading || saveSchedule.isPending}
                onValueChange={(id) => {
                  if (id === 'custom' || id === 'daily-custom') return
                  const preset = SCRAPE_CRON_PRESETS.find((p) => p.id === id)
                  if (preset) setDraftCron(preset.cron)
                }}
              >
                <SelectTrigger id="scrape-preset">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {SCRAPE_CRON_PRESETS.map((p) => (
                    <SelectItem key={p.id} value={p.id}>
                      {p.label}
                    </SelectItem>
                  ))}
                  {daily &&
                  !SCRAPE_CRON_PRESETS.some((p) => p.cron === draftCron) ? (
                    <SelectItem value="daily-custom">
                      Every day at {String(daily.hour).padStart(2, '0')}:
                      {String(daily.minute).padStart(2, '0')} UTC
                    </SelectItem>
                  ) : null}
                  {!daily ? (
                    <SelectItem value="custom">Custom cron</SelectItem>
                  ) : null}
                </SelectContent>
              </Select>
            </div>

            {daily || presetId === 'daily-custom' ? (
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1.5">
                  <Label htmlFor="scrape-hour">Hour (UTC)</Label>
                  <Select
                    value={String(hour)}
                    disabled={settings.isLoading || saveSchedule.isPending}
                    onValueChange={(v) => {
                      const h = Number(v)
                      setHour(h)
                      setDraftCron(dailyCronFromUtc(h, minute))
                    }}
                  >
                    <SelectTrigger id="scrape-hour">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {Array.from({ length: 24 }, (_, i) => (
                        <SelectItem key={i} value={String(i)}>
                          {String(i).padStart(2, '0')}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="scrape-minute">Minute</Label>
                  <Select
                    value={String(minute)}
                    disabled={settings.isLoading || saveSchedule.isPending}
                    onValueChange={(v) => {
                      const m = Number(v)
                      setMinute(m)
                      setDraftCron(dailyCronFromUtc(hour, m))
                    }}
                  >
                    <SelectTrigger id="scrape-minute">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {Array.from({ length: 60 }, (_, i) => (
                        <SelectItem key={i} value={String(i)}>
                          {String(i).padStart(2, '0')}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
            ) : (
              <p className="text-xs text-forja-muted">
                Pick a daily preset (or edit cron) to set hour/minute.
              </p>
            )}

            <div className="space-y-1.5">
              <Label htmlFor="scrape-cron">Cron (UTC)</Label>
              <Input
                id="scrape-cron"
                className="font-mono-ui text-xs"
                value={draftCron}
                spellCheck={false}
                disabled={settings.isLoading || saveSchedule.isPending}
                onChange={(e) => setDraftCron(e.target.value)}
                placeholder="0 6 * * *"
              />
              <p
                className={cn(
                  'text-sm',
                  cronValid ? 'text-forja-muted' : 'text-amber-400',
                )}
              >
                {humanCron}
                {scheduleDirty && cronValid ? ' · unsaved' : null}
              </p>
            </div>

            <Button
              type="button"
              size="sm"
              disabled={
                !scheduleDirty ||
                !cronValid ||
                saveSchedule.isPending ||
                settings.isLoading
              }
              onClick={() => saveSchedule.mutate(draftCron)}
            >
              {saveSchedule.isPending ? 'Saving…' : 'Save schedule'}
            </Button>
          </div>
        </Panel>

        <Panel>
          <PanelLabel>Step logs</PanelLabel>
          <p className="mt-3 text-sm leading-relaxed text-forja-muted">
            {isInngestLocalUi
              ? 'Per-step logs live in Inngest Dev UI (not this table). Keep pnpm dev + Inngest CLI running.'
              : 'Per-step logs live in Inngest Cloud. Open the dashboard for function runs and cancel.'}
          </p>
          <a
            href={INNGEST_UI_URL}
            target="_blank"
            rel="noreferrer"
            className="mt-3 inline-flex items-center gap-1.5 text-sm text-forja-green hover:underline"
          >
            Open Inngest
            <ExternalLink className="size-3.5" />
          </a>
          <p className="mt-3 font-mono-ui text-[11px] leading-relaxed text-forja-muted">
            iptv-catalog-scrape · iptv-promote-backfill · iptv-stalker-note-backfill ·
            scrape-reddit-page-* · fetch-paste-* · upsert-candidates-* ·
            promote-backfill-* · stalker-note-backfill-*
          </p>
          {isInngestLocalUi ? (
            <pre className="mt-4 overflow-x-auto rounded-xl border border-forja-border bg-black/25 p-3 font-mono-ui text-[11px] text-forja-muted">
              {`npx inngest-cli@latest dev -u http://127.0.0.1:4000/api/inngest`}
            </pre>
          ) : (
            <p className="mt-3 text-xs text-forja-muted">
              Sync Inngest to{' '}
              <code className="font-mono-ui">admin.forjahq.xyz/api/inngest</code>
            </p>
          )}
        </Panel>
      </div>

      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
      ) : null}

      {!list.isLoading && (list.data?.length ?? 0) === 0 ? (
        <EmptyState
          title="No scrape history"
          description="Hit Run scrape to create the first run."
        />
      ) : (
        <div className={tableWrapClassName}>
          <div className="overflow-x-auto">
            <table className={tableClassName}>
              <thead>
                <tr>
                  <th className={thClassName}>Started</th>
                  <th className={thClassName}>Source</th>
                  <th className={thClassName}>Status</th>
                  <th className={thClassName}>Dur</th>
                  <th className={thClassName} title="New posts processed (stops at known post_id)">
                    New
                  </th>
                  <th className={thClassName} title="Unique portals extracted this run">
                    Portals
                  </th>
                  <th className={thClassName} title="Base64 + paste refs found">
                    Deep
                  </th>
                  <th className={thClassName}>L2 ok</th>
                  <th className={thClassName}>L2 fail</th>
                  <th className={thClassName} title="Portals added from paste bodies">
                    L2 portals
                  </th>
                  <th className={thClassName} title="Refs kept for later re-extract">
                    Unparsed
                  </th>
                  <th className={thClassName} title="Rows upserted into catalog pool">
                    Upserted
                  </th>
                  <th className={thClassName}>Alive</th>
                  <th className={thClassName}>Error</th>
                </tr>
              </thead>
              <tbody>
                {paging.pageRows.map((r) => (
                  <tr
                    key={r.id}
                    className={cn(
                      'border-t border-forja-border/80 transition-colors hover:bg-white/[0.02]',
                      r.status === 'running' && 'bg-amber-400/[0.04]',
                    )}
                  >
                    <td className={cn(tdClassName, 'whitespace-nowrap text-xs')}>
                      {formatAdminDateTime(r.started_at)}
                    </td>
                    <td
                      className={cn(
                        tdClassName,
                        'font-mono-ui text-xs text-forja-muted',
                      )}
                    >
                      {scrapeSourceLabel(r.source)}
                    </td>
                    <td className={tdClassName}>
                      <StatusBadge status={r.status} />
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums text-xs')}>
                      {runDurationLabel(r)}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {isPromoteBackfillRun(r) ? '—' : r.posts_seen}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {r.l1_extract_count}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {isPromoteBackfillRun(r) ? '—' : r.deep_ref_count}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {isPromoteBackfillRun(r)
                        ? '—'
                        : r.l2_fetch_ok}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {isPromoteBackfillRun(r)
                        ? '—'
                        : r.l2_fetch_fail}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {isPromoteBackfillRun(r) ? '—' : r.l2_extract_count}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {r.unparsed_count ?? 0}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {r.candidates_upserted}
                    </td>
                    <td className={cn(tdClassName, 'tabular-nums')}>
                      {isPromoteBackfillRun(r) ? '—' : r.alive_count}
                    </td>
                    <td
                      className={cn(
                        tdClassName,
                        'max-w-[180px] truncate text-xs text-red-400',
                      )}
                      title={r.error ?? undefined}
                    >
                      {r.error ?? '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <TablePagination
            page={paging.page}
            pageSize={paging.pageSize}
            total={paging.total}
            onPageChange={paging.setPage}
            onPageSizeChange={paging.setPageSize}
          />
        </div>
      )}
    </div>
  )
}
