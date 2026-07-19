import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from '@tanstack/react-router'
import { Button } from '@/components/ui/button'
import { adminDb } from '@/lib/admin-db'
import { INNGEST_UI_URL, isInngestLocalUi } from '@/lib/inngest-ui'
import { scrapeControl } from '@/lib/scrape-control'
import { cn } from '@/lib/utils'

type Run = {
  id: string
  started_at: string
  finished_at: string | null
  status: string
  posts_seen: number
  l1_extract_count: number
  candidates_upserted: number
  alive_count: number
  source?: string | null
  error?: string | null
}

export function AdminScrapePage() {
  const qc = useQueryClient()
  const list = useQuery({
    queryKey: ['admin', 'scrape_runs'],
    queryFn: async () => {
      const { data, error } = await adminDb
        .from('iptv_scrape_runs')
        .select(
          'id, started_at, finished_at, status, posts_seen, l1_extract_count, candidates_upserted, alive_count, source, error',
        )
        .order('started_at', { ascending: false })
        .limit(50)
      if (error) throw error
      return (data ?? []) as Run[]
    },
    refetchInterval: (q) =>
      q.state.data?.some((r) => r.status === 'running') ? 4_000 : 15_000,
  })

  const latest = list.data?.[0] ?? null
  const running = latest?.status === 'running'

  const start = useMutation({
    mutationFn: () => scrapeControl('start'),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ['admin', 'scrape_runs'] }),
  })
  const stop = useMutation({
    mutationFn: () =>
      scrapeControl('stop', { runId: latest?.id }),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ['admin', 'scrape_runs'] }),
  })
  const markStuck = useMutation({
    mutationFn: () => scrapeControl('mark_stuck'),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ['admin', 'scrape_runs'] }),
  })

  const settings = useQuery({
    queryKey: ['admin', 'iptv_ops_settings'],
    queryFn: async () => {
      const { data, error } = await adminDb
        .from('iptv_ops_settings')
        .select('scrape_cron_enabled, updated_at')
        .eq('id', 1)
        .maybeSingle()
      if (error) throw error
      return (
        data ?? {
          scrape_cron_enabled: true,
          updated_at: null as string | null,
        }
      )
    },
  })

  const setCron = useMutation({
    mutationFn: async (enabled: boolean) => {
      const { error } = await adminDb
        .from('iptv_ops_settings')
        .update({ scrape_cron_enabled: enabled })
        .eq('id', 1)
      if (error) throw error
    },
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ['admin', 'iptv_ops_settings'] }),
  })

  const cronEnabled = settings.data?.scrape_cron_enabled !== false

  const busy =
    start.isPending ||
    stop.isPending ||
    markStuck.isPending ||
    setCron.isPending
  const err =
    (start.error as Error | null)?.message ||
    (stop.error as Error | null)?.message ||
    (markStuck.error as Error | null)?.message ||
    (setCron.error as Error | null)?.message ||
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
                Cron:{' '}
                <code className="font-mono-ui text-xs">0 6 * * *</code> UTC
                daily. When off, scheduled runs no-op;{' '}
                <span className="text-forja-text">Run manual scrape</span>{' '}
                still works.
              </p>
            </div>
            <button
              type="button"
              role="switch"
              aria-checked={cronEnabled}
              disabled={setCron.isPending || settings.isLoading}
              onClick={() => setCron.mutate(!cronEnabled)}
              className={cn(
                'relative h-7 w-12 shrink-0 rounded-full transition-colors',
                cronEnabled ? 'bg-forja-green' : 'bg-white/15',
                (setCron.isPending || settings.isLoading) && 'opacity-60',
              )}
              title={
                cronEnabled
                  ? 'Daily cron enabled — click to disable'
                  : 'Daily cron disabled — click to enable'
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
                ? 'Daily scrape on'
                : 'Daily scrape off'}
          </p>
          {isInngestLocalUi ? (
            <p className="mt-2 text-sm text-forja-muted">
              Local: <code className="font-mono-ui text-xs">INNGEST_DEV=1</code>{' '}
              + CLI →{' '}
              <code className="font-mono-ui text-xs">
                http://127.0.0.1:4000/api/inngest
              </code>
              .
            </p>
          ) : (
            <p className="mt-2 text-sm text-forja-muted">
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
              <tr key={r.id} className="border-t border-forja-border">
                <td className="px-3 py-2 text-xs">
                  {new Date(r.started_at).toLocaleString()}
                </td>
                <td className="px-3 py-2 font-mono-ui text-xs">
                  {r.source ?? '—'}
                </td>
                <td className="px-3 py-2">{r.status}</td>
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
