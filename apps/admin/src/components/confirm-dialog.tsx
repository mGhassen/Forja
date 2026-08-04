import { useEffect, useState, type ReactNode } from 'react'
import { X } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

/** In-app confirm modal — never use window.confirm / alert. */
export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  danger,
  busy,
  onConfirm,
  onClose,
}: {
  open: boolean
  title: string
  description?: ReactNode
  confirmLabel?: string
  cancelLabel?: string
  danger?: boolean
  busy?: boolean
  onConfirm: () => void
  onClose: () => void
}) {
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !busy) onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, busy, onClose])

  if (!open) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
      role="presentation"
      onClick={() => {
        if (!busy) onClose()
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="confirm-dialog-title"
        className="w-full max-w-md border border-forja-border bg-forja-elevated p-5 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-3 flex items-start justify-between gap-2">
          <h2
            id="confirm-dialog-title"
            className="text-sm font-semibold text-forja-text"
          >
            {title}
          </h2>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="h-8 w-8 shrink-0 p-0"
            aria-label="Close"
            disabled={busy}
            onClick={onClose}
          >
            <X className="size-4" />
          </Button>
        </div>
        {description ? (
          <div className="mb-5 text-sm leading-relaxed text-forja-muted">
            {description}
          </div>
        ) : null}
        <div className="flex justify-end gap-2">
          <Button
            type="button"
            variant="ghost"
            size="sm"
            disabled={busy}
            onClick={onClose}
          >
            {cancelLabel}
          </Button>
          <Button
            type="button"
            variant={danger ? 'secondary' : 'default'}
            size="sm"
            disabled={busy}
            className={danger ? 'text-amber-300' : undefined}
            onClick={onConfirm}
          >
            {busy ? 'Working…' : confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  )
}

const PAGE_PRESETS = [1, 5, 10, 20, 50] as const
const POSTS_PER_PAGE = 10
const MAX_PAGE = 200

export type ScrapePageRange = { startPage: number; endPage: number }

/** `10` → pages 1–10; `5-10` → pages 5–10 inclusive. */
export function parseScrapePageRange(
  custom: string,
  presetEnd: number,
): ScrapePageRange | null {
  const t = custom.trim()
  if (!t) {
    const end = Math.min(MAX_PAGE, Math.max(1, presetEnd))
    return { startPage: 1, endPage: end }
  }
  const range = /^(\d+)\s*-\s*(\d+)$/.exec(t)
  if (range) {
    let a = Math.floor(Number(range[1]))
    let b = Math.floor(Number(range[2]))
    if (!Number.isFinite(a) || !Number.isFinite(b) || a < 1 || b < 1) return null
    if (a > b) [a, b] = [b, a]
    return {
      startPage: Math.min(MAX_PAGE, a),
      endPage: Math.min(MAX_PAGE, b),
    }
  }
  const n = Math.floor(Number(t))
  if (!Number.isFinite(n) || n < 1) return null
  const end = Math.min(MAX_PAGE, n)
  return { startPage: 1, endPage: end }
}

/** Full scrape: presets = pages 1..N; custom accepts `N` or `A-B` (e.g. 5-10). */
export function FullScrapeDialog({
  open,
  busy,
  onClose,
  onConfirm,
}: {
  open: boolean
  busy?: boolean
  onClose: () => void
  onConfirm: (range: ScrapePageRange) => void
}) {
  const [pages, setPages] = useState(10)
  const [custom, setCustom] = useState('')

  useEffect(() => {
    if (!open) return
    setPages(10)
    setCustom('')
  }, [open])

  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !busy) onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, busy, onClose])

  if (!open) return null

  const parsed = parseScrapePageRange(custom, pages)
  const startPage = parsed?.startPage ?? 1
  const endPage = parsed?.endPage ?? pages
  const pageCount = endPage - startPage + 1
  const approxPosts = pageCount * POSTS_PER_PAGE
  const rangeLabel =
    startPage === endPage
      ? `page ${startPage}`
      : startPage === 1
        ? `pages 1–${endPage}`
        : `pages ${startPage}–${endPage}`

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
      role="presentation"
      onClick={() => {
        if (!busy) onClose()
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="full-scrape-title"
        className="w-full max-w-md border border-forja-border bg-forja-elevated p-5 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-3 flex items-start justify-between gap-2">
          <h2
            id="full-scrape-title"
            className="text-sm font-semibold text-forja-text"
          >
            Run full scrape?
          </h2>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="h-8 w-8 shrink-0 p-0"
            aria-label="Close"
            disabled={busy}
            onClick={onClose}
          >
            <X className="size-4" />
          </Button>
        </div>
        <p className="mb-4 text-sm leading-relaxed text-forja-muted">
          Ignores known posts and re-walks{' '}
          <code className="font-mono-ui text-forja-text">
            /r/IPTV_ZONENEW/new
          </code>
          . Newest → older. Presets = pages <span className="text-forja-text">1–N</span>
          . Custom: <code className="font-mono-ui text-forja-text">5-10</code> =
          start at the 5th page through the 10th. Each page ≈ {POSTS_PER_PAGE}{' '}
          posts.
        </p>
        <div className="mb-2 text-[11px] font-medium uppercase tracking-wide text-forja-muted">
          Pages (from newest)
        </div>
        <div className="mb-3 flex flex-wrap gap-2">
          {PAGE_PRESETS.map((n) => (
            <button
              key={n}
              type="button"
              disabled={busy}
              onClick={() => {
                setPages(n)
                setCustom('')
              }}
              className={cn(
                'rounded-md border px-3 py-1.5 text-sm tabular-nums transition-colors',
                !custom.trim() && pages === n
                  ? 'border-forja-green bg-forja-green/15 text-forja-green'
                  : 'border-forja-border text-forja-muted hover:bg-white/5',
              )}
            >
              1–{n}
            </button>
          ))}
        </div>
        <label className="mb-1 block text-[11px] font-medium uppercase tracking-wide text-forja-muted">
          Custom range
        </label>
        <input
          type="text"
          inputMode="numeric"
          disabled={busy}
          placeholder="e.g. 5-10 or 10"
          value={custom}
          onChange={(e) => setCustom(e.target.value)}
          className="mb-3 w-full rounded-md border border-forja-border bg-black/30 px-3 py-2 font-mono-ui text-sm text-forja-text outline-none focus:border-forja-green"
        />
        {parsed ? (
          <p className="mb-5 text-sm text-forja-text">
            <span className="font-semibold text-forja-green">{rangeLabel}</span>
            {' · '}
            <span className="tabular-nums">{pageCount}</span> page
            {pageCount === 1 ? '' : 's'} ≈{' '}
            <span className="font-semibold tabular-nums">{approxPosts}</span>{' '}
            posts
            {startPage > 1 ? (
              <span className="text-forja-muted">
                {' '}
                (skip first {startPage - 1})
              </span>
            ) : null}
          </p>
        ) : (
          <p className="mb-5 text-sm text-red-400">
            Use a number (e.g. 10) or range (e.g. 5-10), max {MAX_PAGE}.
          </p>
        )}
        <div className="flex justify-end gap-2">
          <Button
            type="button"
            variant="ghost"
            size="sm"
            disabled={busy}
            onClick={onClose}
          >
            Cancel
          </Button>
          <Button
            type="button"
            variant="secondary"
            size="sm"
            disabled={busy || !parsed}
            className="text-amber-300"
            onClick={() => {
              if (parsed) onConfirm(parsed)
            }}
          >
            {busy ? 'Starting…' : `Run ${rangeLabel}`}
          </Button>
        </div>
      </div>
    </div>
  )
}
