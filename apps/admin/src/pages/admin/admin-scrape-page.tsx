import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { useEffect, useMemo, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
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
import {
  SCRAPE_RUNS_KEY,
  fetchScrapeRuns,
  markRunsStoppedInCache,
  prependOptimisticRun,
  refreshScrapeRuns,
  subscribeScrapeRuns,
  type ScrapeRunRow,
} from '@/lib/scrape-runs'
import { cn } from '@/lib/utils'

type Run = ScrapeRunRow

export function AdminScrapePage() {
  const qc = useQueryClient()
  const list = useQuery({
    queryKey: SCRAPE_RUNS_KEY,
    queryFn: () => fetchScrapeRuns(50),
    refetchInterval: (q) =>
      q.state.data?.some((r) => r.status === 'running') ? 1_500 : 8_000,
    refetchOnWindowFocus: true,
  })

  useEffect(() => {
    return subscribeScrapeRuns(() => {
      void refreshScrapeRuns(qc)
    })
  }, [qc])

  const latest = list.data?.[0] ?? null
  const running = latest?.status === 'running'

  const start = useMutation({
    mutationFn: () => scrapeControl('start'),
    onSuccess: async (res) => {
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
    <div className="space-y-6">
      <div>
        <h1 className="font-disp text-xl font-bold tracking-tight">
          Scrape control
        </h1>
        <p className="mt-1 text-sm text-forja-muted">
          Manual run, stop stuck jobs, cron, and Inngest logs. Pool is for the
          candidate inventory — this tab is ops.
        </p>
      </div>

      <div className="rounded-xl border border-forja-border bg-forja-elevated/40 px-5 py-4">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div className="min-w-0 space-y-1">
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted">
              Current
            </p>
            {latest ? (
              <>
                <p
                  className={cn(
                    'text-base font-semibold capitalize',
                    latest.status === 'running' && 'text-amber-400',
                    latest.status === 'ok' && 'text-forja-green',
                    latest.status === 'error' && 'text-red-400',
                  )}
                >
                  {latest.status}
                </p>
                <p className="text-sm text-forja-muted">
                  {latest.posts_seen} posts · L1 {latest.l1_extract_count} ·
                  upserted {latest.candidates_upserted} · alive{' '}
                  {latest.alive_count}
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
              disabled={list.isFetching}
              onClick={() => void refreshScrapeRuns(qc)}
            >
              {list.isFetching ? 'Refreshing…' : 'Refresh'}
            </Button>
            <Button
              type="button"
              variant="secondary"
              disabled={busy || running}
              onClick={() => start.mutate()}
            >
              {start.isPending ? 'Starting…' : 'Run manual scrape'}
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
              Mark stuck failed
            </Button>
          </div>
        </div>
        {err ? <p className="mt-3 text-sm text-red-400">{err}</p> : null}
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="rounded-xl border border-forja-border px-5 py-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted">
            Logs
          </p>
          <p className="mt-2 text-sm text-forja-muted">
            {isInngestLocalUi ? (
              <>
                Step logs live in Inngest Dev UI (not in this table). Open while{' '}
                <code className="font-mono-ui text-xs">pnpm dev</code> + Inngest
                CLI are running.
              </>
            ) : (
              <>
                Step logs live in Inngest Cloud (not in this table). Open the
                dashboard for function runs and cancel.
              </>
            )}
          </p>
          <a
            href={INNGEST_UI_URL}
            target="_blank"
            rel="noreferrer"
            className="mt-3 inline-block text-sm text-forja-green underline-offset-2 hover:underline"
          >
            Open Inngest → {INNGEST_UI_URL}
          </a>
          <p className="mt-2 font-mono-ui text-xs text-forja-muted">
            Function: iptv-catalog-scrape · steps: scrape-reddit-page-* ·
            upsert-candidates-unverified (player_api verify off — flip
            VERIFY_PORTAL_STATUS to re-enable verify-portal-status-*)
          </p>
        </div>

        <div className="rounded-xl border border-forja-border px-5 py-4">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="min-w-0">
              <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted">
                Automation
              </p>
              <p className="mt-2 text-sm text-forja-muted">
                Change the schedule below (UTC). When off, ticks no-op;{' '}
                <span className="text-forja-text">Run manual scrape</span>{' '}
                still works.
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
              title={
                cronEnabled
                  ? 'Schedule enabled — click to disable'
                  : 'Schedule disabled — click to enable'
              }
            >
              <span
                className={cn(
                  'absolute top-0.5 size-6 rounded-full bg-[#0B0A0A] shadow transition-transform',
                  cronEnabled ? 'left-5' : 'left-0.5',
                )}
              />
            </button>
          </div>
          <p
            className={cn(
              'mt-2 text-sm font-semibold',
              cronEnabled ? 'text-forja-green' : 'text-amber-400',
            )}
          >
            {settings.isLoading
              ? 'Loading…'
              : cronEnabled
                ? 'Scheduled scrape on'
                : 'Scheduled scrape off'}
          </p>

          <div className="mt-4 space-y-3 border-t border-forja-border pt-4">
            <div className="space-y-1.5">
              <Label htmlFor="scrape-preset">Preset</Label>
              <select
                id="scrape-preset"
                className="flex h-9 w-full rounded-md border border-forja-border bg-forja-elevated px-3 text-sm text-forja-text"
                value={presetId}
                disabled={settings.isLoading || saveSchedule.isPending}
                onChange={(e) => {
                  const id = e.target.value
                  if (id === 'custom' || id === 'daily-custom') return
                  const preset = SCRAPE_CRON_PRESETS.find((p) => p.id === id)
                  if (preset) setDraftCron(preset.cron)
                }}
              >
                {SCRAPE_CRON_PRESETS.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.label}
                  </option>
                ))}
                {daily &&
                !SCRAPE_CRON_PRESETS.some((p) => p.cron === draftCron) ? (
                  <option value="daily-custom">
                    Every day at{' '}
                    {String(daily.hour).padStart(2, '0')}:
                    {String(daily.minute).padStart(2, '0')} UTC
                  </option>
                ) : null}
                {!daily ? (
                  <option value="custom">Custom cron</option>
                ) : null}
              </select>
            </div>

            {daily || presetId === 'daily-custom' ? (
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1.5">
                  <Label htmlFor="scrape-hour">Hour (UTC)</Label>
                  <select
                    id="scrape-hour"
                    className="flex h-9 w-full rounded-md border border-forja-border bg-forja-elevated px-3 text-sm text-forja-text"
                    value={hour}
                    disabled={settings.isLoading || saveSchedule.isPending}
                    onChange={(e) => {
                      const h = Number(e.target.value)
                      setHour(h)
                      setDraftCron(dailyCronFromUtc(h, minute))
                    }}
                  >
                    {Array.from({ length: 24 }, (_, i) => (
                      <option key={i} value={i}>
                        {String(i).padStart(2, '0')}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="scrape-minute">Minute</Label>
                  <select
                    id="scrape-minute"
                    className="flex h-9 w-full rounded-md border border-forja-border bg-forja-elevated px-3 text-sm text-forja-text"
                    value={minute}
                    disabled={settings.isLoading || saveSchedule.isPending}
                    onChange={(e) => {
                      const m = Number(e.target.value)
                      setMinute(m)
                      setDraftCron(dailyCronFromUtc(hour, m))
                    }}
                  >
                    {Array.from({ length: 60 }, (_, i) => (
                      <option key={i} value={i}>
                        {String(i).padStart(2, '0')}
                      </option>
                    ))}
                  </select>
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

          {isInngestLocalUi ? (
            <p className="mt-3 text-sm text-forja-muted">
              Local: <code className="font-mono-ui text-xs">INNGEST_DEV=1</code>{' '}
              + CLI →{' '}
              <code className="font-mono-ui text-xs">
                http://127.0.0.1:4000/api/inngest
              </code>
              .
            </p>
          ) : (
            <p className="mt-3 text-sm text-forja-muted">
              Prod (
              <code className="font-mono-ui text-xs">admin.forjahq.xyz</code>
              ): sync Inngest to{' '}
              <code className="font-mono-ui text-xs">/api/inngest</code>.
            </p>
          )}
          <Link
            to="/pool"
            className="mt-3 inline-block text-sm text-forja-green underline-offset-2 hover:underline"
          >
            → Catalog pool
          </Link>
        </div>
      </div>

      {isInngestLocalUi ? (
        <pre className="overflow-x-auto rounded-xl border border-forja-border bg-forja-elevated p-3 font-mono-ui text-xs text-forja-muted">
          {`# Terminal A — admin app
cd apps/admin && pnpm dev

# Terminal B — Inngest (logs + cron + cancel)
npx inngest-cli@latest dev -u http://127.0.0.1:4000/api/inngest

# Then: Scrape → Run manual scrape  (or Pool → Start scrape)`}
        </pre>
      ) : null}

      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
      ) : null}

      <div className="overflow-x-auto rounded-xl border border-forja-border">
        <table className="w-full text-left text-sm">
          <thead className="bg-forja-elevated text-forja-muted">
            <tr>
              <th className="px-3 py-2">Started</th>
              <th className="px-3 py-2">Source</th>
              <th className="px-3 py-2">Status</th>
              <th className="px-3 py-2">Posts</th>
              <th className="px-3 py-2">L1</th>
              <th className="px-3 py-2">Upserted</th>
              <th className="px-3 py-2">Alive</th>
              <th className="px-3 py-2">Error</th>
            </tr>
          </thead>
          <tbody>
            {(list.data ?? []).map((r) => (
              <tr
                key={r.id}
                className={cn(
                  'border-t border-forja-border transition-colors',
                  r.status === 'running' && 'bg-amber-400/5',
                  r.id === latest?.id && 'bg-white/[0.03]',
                )}
              >
                <td className="px-3 py-2 text-xs">
                  {new Date(r.started_at).toLocaleString()}
                </td>
                <td className="px-3 py-2 font-mono-ui text-xs">
                  {r.source ?? '—'}
                </td>
                <td
                  className={cn(
                    'px-3 py-2 capitalize',
                    r.status === 'running' && 'font-semibold text-amber-400',
                    r.status === 'ok' && 'text-forja-green',
                    r.status === 'error' && 'text-red-400',
                  )}
                >
                  {r.status}
                  {r.status === 'running' ? (
                    <span className="ml-1 inline-block size-1.5 animate-pulse rounded-full bg-amber-400 align-middle" />
                  ) : null}
                </td>
                <td className="px-3 py-2 tabular-nums">{r.posts_seen}</td>
                <td className="px-3 py-2 tabular-nums">{r.l1_extract_count}</td>
                <td className="px-3 py-2 tabular-nums">
                  {r.candidates_upserted}
                </td>
                <td className="px-3 py-2 tabular-nums">{r.alive_count}</td>
                <td className="max-w-[220px] truncate px-3 py-2 text-xs text-red-400">
                  {r.error ?? '—'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
