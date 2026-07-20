import { useMutation, useQueryClient } from '@tanstack/react-query'
import { X } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Button } from '@/components/ui/button'
import { adminDb } from '@/lib/admin-db'
import {
  ACCOUNT_FEATURES,
  type AccountFeatureKey,
  type AccountFeaturesMap,
  parseAccountFeatures,
} from '@/lib/account-features'
import { cn } from '@/lib/utils'

type Props = {
  accountId: string
  accountEmail: string | null
  features: Record<string, unknown> | null
  onClose: () => void
}

export function AccountFeaturesDialog({
  accountId,
  accountEmail,
  features,
  onClose,
}: Props) {
  const qc = useQueryClient()
  const [local, setLocal] = useState<AccountFeaturesMap>(() =>
    parseAccountFeatures(features),
  )
  const [error, setError] = useState<string | null>(null)
  const [busyKey, setBusyKey] = useState<AccountFeatureKey | null>(null)

  useEffect(() => {
    setLocal(parseAccountFeatures(features))
  }, [features, accountId])

  const setFlag = useMutation({
    mutationFn: async ({
      key,
      enabled,
    }: {
      key: AccountFeatureKey
      enabled: boolean
    }) => {
      const def = ACCOUNT_FEATURES.find((d) => d.key === key)
      if (!def) throw new Error(`Unknown feature ${key}`)
      setBusyKey(key)
      setError(null)
      const { data, error: rpcError } = await adminDb.rpc(def.rpc, {
        p_account_id: accountId,
        p_enabled: enabled,
      })
      if (rpcError) throw rpcError
      return { key, enabled, features: data as Record<string, unknown> | null }
    },
    onSuccess: ({ key, enabled }) => {
      setLocal((prev) => {
        const next = { ...prev }
        if (enabled) next[key] = true
        else delete next[key]
        return next
      })
      void qc.invalidateQueries({ queryKey: ['admin', 'accounts'] })
    },
    onError: (e) => {
      setError(e instanceof Error ? e.message : 'Failed to update feature')
    },
    onSettled: () => setBusyKey(null),
  })

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
      role="dialog"
      aria-modal
      aria-labelledby="account-features-title"
      onClick={onClose}
    >
      <div
        className="w-full max-w-md rounded-2xl border border-forja-border bg-[#121110] shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3 border-b border-forja-border/80 px-4 py-3.5">
          <div className="min-w-0">
            <h2
              id="account-features-title"
              className="font-disp text-lg font-bold tracking-tight text-forja-text"
            >
              Feature flags
            </h2>
            <p className="mt-0.5 truncate text-sm text-forja-muted">
              {accountEmail ?? accountId.slice(0, 8)}
            </p>
          </div>
          <button
            type="button"
            aria-label="Close"
            onClick={onClose}
            className="inline-flex size-8 shrink-0 items-center justify-center rounded-md text-forja-muted hover:bg-white/5 hover:text-forja-text"
          >
            <X className="size-4" />
          </button>
        </div>

        <ul className="max-h-[min(60vh,28rem)] space-y-1 overflow-y-auto p-3">
          {ACCOUNT_FEATURES.map((def) => {
            const on = local[def.key] === true
            const busy = busyKey === def.key
            return (
              <li
                key={def.key}
                className="flex items-start gap-3 rounded-xl px-3 py-3 hover:bg-white/2"
              >
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium text-forja-text">
                    {def.label}
                  </p>
                  <p className="mt-0.5 text-xs leading-relaxed text-forja-muted">
                    {def.description}
                  </p>
                  <p className="mt-1 font-mono text-[10px] text-forja-muted/80">
                    {def.key}
                  </p>
                </div>
                <button
                  type="button"
                  role="switch"
                  aria-checked={on}
                  aria-label={
                    on ? `Disable ${def.label}` : `Enable ${def.label}`
                  }
                  disabled={busy || setFlag.isPending}
                  onClick={() =>
                    setFlag.mutate({ key: def.key, enabled: !on })
                  }
                  className={cn(
                    'relative mt-0.5 h-7 w-12 shrink-0 rounded-full transition-colors',
                    on ? 'bg-forja-green' : 'bg-white/15',
                    (busy || setFlag.isPending) && 'opacity-60',
                  )}
                >
                  <span
                    className={cn(
                      'absolute top-0.5 size-6 rounded-full bg-[#0B0A0A] shadow transition-transform',
                      on ? 'left-5' : 'left-0.5',
                    )}
                  />
                </button>
              </li>
            )
          })}
        </ul>

        {error ? (
          <p className="px-4 pb-2 text-sm text-red-400">{error}</p>
        ) : null}

        <div className="flex justify-end border-t border-forja-border/80 px-4 py-3">
          <Button type="button" variant="secondary" size="sm" onClick={onClose}>
            Done
          </Button>
        </div>
      </div>
    </div>
  )
}
