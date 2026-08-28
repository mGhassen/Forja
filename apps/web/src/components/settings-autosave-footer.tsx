import type { ReactNode } from 'react'

type SettingsAutosaveFooterProps = {
  isSaving: boolean
  savedFlash: boolean
  error?: Error | string | null
  extra?: ReactNode
}

/** Status-only footer — edits save immediately, no Save button. */
export function SettingsAutosaveFooter({
  isSaving,
  savedFlash,
  error,
  extra,
}: SettingsAutosaveFooterProps) {
  const err =
    error == null
      ? null
      : typeof error === 'string'
        ? error
        : error.message || 'Save failed'

  if (!isSaving && !savedFlash && !err && !extra) return null

  return (
    <div className="flex flex-wrap items-center gap-3 text-sm">
      {isSaving ? (
        <span className="text-forja-muted">Saving…</span>
      ) : savedFlash ? (
        <span className="text-forja-green">Saved</span>
      ) : null}
      {err ? <span className="text-red-300">{err}</span> : null}
      {extra}
    </div>
  )
}
