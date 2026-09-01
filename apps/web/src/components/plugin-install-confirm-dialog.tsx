import { useEffect, useRef } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { Loader2, Puzzle, X } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { LiquidGlass } from '@/components/liquid-glass'
import type { ForjaPackRow } from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

export type PluginInstallConfirmPayload = {
  manifestUrl: string
  name?: string
  version?: string
}

type PluginInstallConfirmDialogProps = {
  open: boolean
  payload: PluginInstallConfirmPayload | null
  alreadyInstalled: boolean
  busy?: boolean
  onConfirm: () => void
  onCancel: () => void
}

function displayName(payload: PluginInstallConfirmPayload): string {
  const name = payload.name?.trim()
  if (name && name !== payload.manifestUrl) return name
  try {
    const path = new URL(payload.manifestUrl).pathname
    const segment = path.split('/').filter(Boolean).slice(-2, -1)[0]
    if (segment) return segment.replace(/_/g, ' ')
  } catch {
    // ignore
  }
  return 'Plugin pack'
}

export function PluginInstallConfirmDialog({
  open,
  payload,
  alreadyInstalled,
  busy,
  onConfirm,
  onCancel,
}: PluginInstallConfirmDialogProps) {
  const panelRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onCancel()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onCancel])

  useEffect(() => {
    if (!open) return
    panelRef.current?.focus()
  }, [open])

  if (!open || !payload) return null

  const title = displayName(payload)

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center p-4 sm:items-center"
      role="presentation"
    >
      <button
        type="button"
        className="absolute inset-0 bg-black/65 backdrop-blur-sm"
        aria-label="Dismiss"
        onClick={onCancel}
      />
      <div
        ref={panelRef}
        tabIndex={-1}
        role="dialog"
        aria-modal="true"
        aria-labelledby="plugin-install-title"
        className="relative w-full max-w-md outline-none"
      >
        <LiquidGlass className="border-white/15 p-0 shadow-2xl">
        <div className="flex items-start justify-between gap-3 border-b border-white/10 px-5 py-4">
          <div className="flex min-w-0 items-start gap-3">
            <div className="flex size-9 shrink-0 items-center justify-center rounded-lg border border-forja-green/25 bg-forja-green/10 text-forja-green">
              <Puzzle className="size-4" aria-hidden />
            </div>
            <div className="min-w-0">
              <p className="font-mono-ui text-[10px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.45)]">
                {alreadyInstalled ? 'Already added' : 'Install plugin pack'}
              </p>
              <h2
                id="plugin-install-title"
                className="truncate font-medium text-[#EDE6DA]"
              >
                {title}
              </h2>
            </div>
          </div>
          <button
            type="button"
            onClick={onCancel}
            className="flex size-8 shrink-0 items-center justify-center rounded-lg text-[rgba(237,230,218,0.5)] hover:bg-white/8 hover:text-[#EDE6DA]"
            aria-label="Close"
          >
            <X className="size-4" />
          </button>
        </div>

        <div className="space-y-4 px-5 py-4">
          {alreadyInstalled ? (
            <p className="text-sm leading-relaxed text-[rgba(237,230,218,0.62)]">
              This pack is already on your profile. Open Forja on any device —
              it syncs and installs automatically.
            </p>
          ) : (
            <p className="text-sm leading-relaxed text-[rgba(237,230,218,0.62)]">
              Add this pack to your Forja profile? The app will download and
              validate the manifest on your next sync.
            </p>
          )}

          <div className="rounded-lg border border-white/8 bg-black/20 px-3 py-2.5">
            <p className="font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.4)]">
              Manifest
            </p>
            <p className="mt-1 break-all font-mono text-[11px] leading-snug text-[rgba(237,230,218,0.55)]">
              {payload.manifestUrl}
            </p>
            {payload.version?.trim() ? (
              <p className="mt-2 font-mono-ui text-[10px] text-[rgba(237,230,218,0.4)]">
                Version {payload.version.trim()}
              </p>
            ) : null}
          </div>
        </div>

        <div className="flex flex-col-reverse gap-2 border-t border-white/10 px-5 py-4 sm:flex-row sm:justify-end">
          <Button
            type="button"
            variant="ghost"
            className="text-[rgba(237,230,218,0.65)]"
            onClick={onCancel}
            disabled={busy}
          >
            {alreadyInstalled ? 'Close' : 'Cancel'}
          </Button>
          {!alreadyInstalled ? (
            <Button
              type="button"
              className={cn(
                'bg-forja-green text-[#0B0A0A] hover:bg-forja-green/90',
              )}
              onClick={onConfirm}
              disabled={busy}
            >
              {busy ? (
                <>
                  <Loader2 className="size-4 animate-spin" />
                  Adding…
                </>
              ) : (
                'Add to profile'
              )}
            </Button>
          ) : null}
        </div>
      </LiquidGlass>
      </div>
    </div>
  )
}

export function packRowFromInstallPayload(
  payload: PluginInstallConfirmPayload,
): ForjaPackRow {
  const manifestUrl = payload.manifestUrl.trim()
  const row: ForjaPackRow = { manifestUrl }
  const name = payload.name?.trim()
  if (name && name !== manifestUrl) row.name = name
  const version = payload.version?.trim()
  if (version) row.version = version
  return row
}

/** Navigate to profile Forja plugins with install prompt (no app deep link). */
export function useGoToPluginInstall() {
  const navigate = useNavigate()
  return (payload: PluginInstallConfirmPayload) => {
    void navigate({
      to: '/account/settings/forja',
      search: {
        manifest: payload.manifestUrl,
        ...(payload.name ? { name: payload.name } : {}),
        ...(payload.version ? { version: payload.version } : {}),
      },
    })
  }
}
