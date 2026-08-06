import type { ReactNode } from 'react'
import { Link } from '@tanstack/react-router'
import { cn } from '@/lib/utils'

export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string
  description?: ReactNode
  actions?: ReactNode
}) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-4">
      <div className="min-w-0 space-y-1.5">
        <h1 className="font-disp text-2xl font-bold tracking-tight text-forja-text sm:text-[1.75rem]">
          {title}
        </h1>
        {description ? (
          <p className="max-w-2xl text-sm leading-relaxed text-forja-muted">
            {description}
          </p>
        ) : null}
      </div>
      {actions ? (
        <div className="flex flex-wrap items-center gap-2">{actions}</div>
      ) : null}
    </div>
  )
}

export function Panel({
  children,
  className,
  tone = 'default',
}: {
  children: ReactNode
  className?: string
  tone?: 'default' | 'elevated' | 'accent'
}) {
  return (
    <div
      className={cn(
        'rounded-2xl border border-forja-border p-5',
        tone === 'default' && 'bg-forja-elevated/30',
        tone === 'elevated' && 'bg-forja-elevated/55',
        tone === 'accent' &&
          'bg-gradient-to-br from-forja-green/[0.07] via-forja-elevated/40 to-forja-elevated/20',
        className,
      )}
    >
      {children}
    </div>
  )
}

export function PanelLabel({ children }: { children: ReactNode }) {
  return (
    <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-forja-muted">
      {children}
    </p>
  )
}

export function StatCard({
  label,
  value,
  hint,
  to,
  accent,
}: {
  label: string
  value: ReactNode
  hint?: string
  to?: string
  accent?: 'green' | 'amber' | 'muted'
}) {
  const body = (
    <>
      <div className="font-mono-ui text-[10px] font-bold uppercase tracking-[0.16em] text-forja-muted">
        {label}
      </div>
      <div
        className={cn(
          'mt-2 font-disp text-3xl font-bold tabular-nums tracking-tight',
          accent === 'green' && 'text-forja-green',
          accent === 'amber' && 'text-amber-400',
          !accent && 'text-forja-text',
        )}
      >
        {value}
      </div>
      {hint ? (
        <p className="mt-1.5 text-xs text-forja-muted">{hint}</p>
      ) : null}
    </>
  )

  const cls = cn(
    'rounded-2xl border border-forja-border bg-forja-elevated/45 p-4 transition-colors',
    to &&
      'hover:border-forja-green/35 hover:bg-forja-elevated/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forja-green/50',
  )

  if (to) {
    return (
      <Link to={to} className={cls}>
        {body}
      </Link>
    )
  }
  return <div className={cls}>{body}</div>
}

export function StatusBadge({
  status,
}: {
  status: string
}) {
  const s = status.toLowerCase()
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold capitalize',
        s === 'running' && 'bg-amber-400/15 text-amber-300',
        s === 'ok' && 'bg-forja-green/15 text-forja-green',
        s === 'error' && 'bg-red-500/15 text-red-300',
        s !== 'running' &&
          s !== 'ok' &&
          s !== 'error' &&
          'bg-white/5 text-forja-muted',
      )}
    >
      {s === 'running' ? (
        <span className="size-1.5 animate-pulse rounded-full bg-amber-400" />
      ) : (
        <span
          className={cn(
            'size-1.5 rounded-full',
            s === 'ok' && 'bg-forja-green',
            s === 'error' && 'bg-red-400',
            s !== 'ok' && s !== 'error' && 'bg-forja-muted',
          )}
        />
      )}
      {status}
    </span>
  )
}

export function MetricChip({
  label,
  value,
}: {
  label: string
  value: ReactNode
}) {
  return (
    <div className="rounded-xl border border-forja-border/80 bg-black/20 px-3 py-2">
      <div className="text-[10px] font-semibold uppercase tracking-[0.14em] text-forja-muted">
        {label}
      </div>
      <div className="mt-0.5 text-sm font-semibold tabular-nums text-forja-text">
        {value}
      </div>
    </div>
  )
}

export function EmptyState({
  title,
  description,
}: {
  title: string
  description?: string
}) {
  return (
    <div className="rounded-2xl border border-dashed border-forja-border px-6 py-10 text-center">
      <p className="text-sm font-medium text-forja-text">{title}</p>
      {description ? (
        <p className="mt-1 text-sm text-forja-muted">{description}</p>
      ) : null}
    </div>
  )
}

export const tableWrapClassName =
  'overflow-hidden rounded-2xl border border-forja-border'

export const tableClassName = 'w-full text-left text-sm'

export const thClassName =
  'bg-forja-elevated/80 px-3 py-2.5 text-[11px] font-semibold uppercase tracking-[0.12em] text-forja-muted'

export const tdClassName = 'px-3 py-2.5 align-middle'

export function TablePagination({
  page,
  pageSize,
  total,
  onPageChange,
  onPageSizeChange,
  pageSizeOptions = [25, 50, 100],
}: {
  page: number
  pageSize: number
  total: number
  onPageChange: (page: number) => void
  onPageSizeChange?: (size: number) => void
  pageSizeOptions?: number[]
}) {
  const pageCount = Math.max(1, Math.ceil(total / pageSize) || 1)
  const safePage = Math.min(Math.max(0, page), pageCount - 1)
  const from = total === 0 ? 0 : safePage * pageSize + 1
  const to = Math.min(total, (safePage + 1) * pageSize)

  return (
    <div className="flex flex-wrap items-center justify-between gap-3 border-t border-forja-border px-3 py-2.5">
      <p className="text-xs text-forja-muted">
        {total === 0 ? (
          '0 rows'
        ) : (
          <>
            <span className="tabular-nums text-forja-text">
              {from}–{to}
            </span>{' '}
            of <span className="tabular-nums">{total}</span>
          </>
        )}
      </p>
      <div className="flex flex-wrap items-center gap-2">
        {onPageSizeChange ? (
          <label className="flex items-center gap-1.5 text-xs text-forja-muted">
            Rows
            <select
              className="h-8 rounded-md border border-forja-border bg-forja-elevated/40 px-2 text-xs text-forja-text"
              value={pageSize}
              onChange={(e) => onPageSizeChange(Number(e.target.value))}
            >
              {pageSizeOptions.map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          </label>
        ) : null}
        <div className="flex items-center gap-1">
          <button
            type="button"
            disabled={safePage <= 0}
            className="inline-flex h-8 items-center rounded-md border border-forja-border px-2.5 text-xs text-forja-muted transition-colors hover:bg-white/[0.04] hover:text-forja-text disabled:pointer-events-none disabled:opacity-40"
            onClick={() => onPageChange(safePage - 1)}
          >
            Prev
          </button>
          <span className="min-w-16 text-center text-xs tabular-nums text-forja-muted">
            {safePage + 1} / {pageCount}
          </span>
          <button
            type="button"
            disabled={safePage >= pageCount - 1}
            className="inline-flex h-8 items-center rounded-md border border-forja-border px-2.5 text-xs text-forja-muted transition-colors hover:bg-white/[0.04] hover:text-forja-text disabled:pointer-events-none disabled:opacity-40"
            onClick={() => onPageChange(safePage + 1)}
          >
            Next
          </button>
        </div>
      </div>
    </div>
  )
}
