import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { Button } from '@/components/ui/button'
import { adminDb } from '@/lib/admin-db'

const SUPPORTED_SCHEMA = 1

function validateConfig(raw: string): { ok: true; value: unknown } | { ok: false; error: string } {
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : 'Invalid JSON' }
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    return { ok: false, error: 'Config must be a JSON object' }
  }
  const schema = (parsed as { schema?: unknown }).schema
  if (schema !== SUPPORTED_SCHEMA) {
    return {
      ok: false,
      error: `schema must be ${SUPPORTED_SCHEMA} (got ${String(schema)})`,
    }
  }
  return { ok: true, value: parsed }
}

export function AdminProvidersPage() {
  const qc = useQueryClient()
  const [text, setText] = useState('')
  const [localError, setLocalError] = useState<string | null>(null)

  const row = useQuery({
    queryKey: ['admin', 'provider_runtime_config'],
    queryFn: async () => {
      const { data, error } = await adminDb
        .from('provider_runtime_config')
        .select('id, schema_version, config, updated_at')
        .eq('id', 1)
        .maybeSingle()
      if (error) throw error
      if (!data) throw new Error('No provider_runtime_config row (id=1)')
      return data as {
        id: number
        schema_version: number
        config: unknown
        updated_at: string
      }
    },
  })

  useEffect(() => {
    if (!row.data) return
    setText(JSON.stringify(row.data.config, null, 2))
    setLocalError(null)
  }, [row.data])

  const save = useMutation({
    mutationFn: async (raw: string) => {
      const v = validateConfig(raw)
      if (!v.ok) throw new Error(v.error)
      const { error } = await adminDb
        .from('provider_runtime_config')
        .update({
          config: v.value,
          schema_version: SUPPORTED_SCHEMA,
          updated_at: new Date().toISOString(),
        })
        .eq('id', 1)
      if (error) throw error
    },
    onSuccess: async () => {
      setLocalError(null)
      await qc.invalidateQueries({ queryKey: ['admin', 'provider_runtime_config'] })
    },
    onError: (e: Error) => setLocalError(e.message),
  })

  const format = () => {
    const v = validateConfig(text)
    if (!v.ok) {
      setLocalError(v.error)
      return
    }
    setText(JSON.stringify(v.value, null, 2))
    setLocalError(null)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="font-disp text-xl font-bold tracking-tight">
            Provider runtime
          </h1>
          <p className="mt-1 text-sm text-forja-muted">
            Hosts, URL templates, WebStreamr bases, anime mirrors, CDN Referer
            rules. App merges over builtins (schema {SUPPORTED_SCHEMA}). Extract
            logic stays in the client.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button
            type="button"
            variant="secondary"
            size="sm"
            disabled={row.isLoading || save.isPending}
            onClick={() => format()}
          >
            Format
          </Button>
          <Button
            type="button"
            variant="secondary"
            size="sm"
            disabled={row.isLoading || save.isPending}
            onClick={() => void row.refetch()}
          >
            Reload
          </Button>
          <Button
            type="button"
            size="sm"
            disabled={row.isLoading || save.isPending}
            onClick={() => save.mutate(text)}
          >
            {save.isPending ? 'Saving…' : 'Save'}
          </Button>
        </div>
      </div>

      {row.data?.updated_at ? (
        <p className="text-xs text-forja-muted">
          Updated {new Date(row.data.updated_at).toLocaleString()}
        </p>
      ) : null}

      {row.error ? (
        <p className="text-sm text-red-400">{(row.error as Error).message}</p>
      ) : null}
      {localError || save.error ? (
        <p className="text-sm text-red-400">
          {localError || (save.error as Error).message}
        </p>
      ) : null}
      {save.isSuccess && !localError ? (
        <p className="text-sm text-forja-green">Saved. Clients refresh within ~6h TTL or next cold start.</p>
      ) : null}

      <textarea
        className="min-h-[28rem] w-full resize-y rounded-xl border border-forja-border bg-forja-elevated p-3 font-mono-ui text-xs leading-relaxed text-forja-text outline-none focus:border-forja-green/50"
        spellCheck={false}
        value={text}
        disabled={row.isLoading}
        onChange={(e) => {
          setText(e.target.value)
          setLocalError(null)
          save.reset()
        }}
      />
    </div>
  )
}
