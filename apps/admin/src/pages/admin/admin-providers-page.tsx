import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus, Trash2 } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import {
  MetricChip,
  PageHeader,
  Panel,
  PanelLabel,
  tableClassName,
  tableWrapClassName,
  tdClassName,
  thClassName,
} from '@/components/admin-ui'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { adminDb } from '@/lib/admin-db'
import {
  SUPPORTED_SCHEMA,
  type AnimeEmbedHost,
  type CdnRefererRule,
  type KvRow,
  type ProviderRuntimeConfig,
  type TemplateRow,
  canonicalJson,
  configToPrettyJson,
  csvToList,
  emptyConfig,
  kvToMap,
  listToCsv,
  listToLines,
  linesToList,
  mapToKv,
  parseConfig,
  parseConfigJson,
  rowsToTemplates,
  serializeConfig,
  templatesToRows,
} from '@/lib/provider-runtime-config'
import { cn } from '@/lib/utils'

type Mode = 'form' | 'json'

function Field({
  label,
  value,
  onChange,
  placeholder,
  mono,
}: {
  label: string
  value: string
  onChange: (v: string) => void
  placeholder?: string
  mono?: boolean
}) {
  return (
    <label className="block space-y-1.5">
      <Label>{label}</Label>
      <Input
        className={cn(mono && 'font-mono-ui text-xs')}
        value={value}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
      />
    </label>
  )
}

function EmbedHostFields({
  title,
  value,
  onChange,
}: {
  title: string
  value: AnimeEmbedHost
  onChange: (v: AnimeEmbedHost) => void
}) {
  const set = (k: keyof AnimeEmbedHost, v: string) =>
    onChange({ ...value, [k]: v })
  return (
    <div className="space-y-3">
      <p className="text-sm font-medium text-forja-text">{title}</p>
      <div className="grid gap-3 sm:grid-cols-2">
        <Field label="Host" value={value.host} onChange={(v) => set('host', v)} mono />
        <Field
          label="Scrape referer"
          value={value.scrapeReferer}
          onChange={(v) => set('scrapeReferer', v)}
          mono
        />
        <Field
          label="Path (catalog)"
          value={value.pathCatalog}
          onChange={(v) => set('pathCatalog', v)}
          placeholder="/stream/s-2/{embedId}/{lang}"
          mono
        />
        <Field
          label="Path (AniList)"
          value={value.pathAnilist}
          onChange={(v) => set('pathAnilist', v)}
          placeholder="/stream/ani/{anilistId}/{ep}/{lang}"
          mono
        />
      </div>
    </div>
  )
}

function KvTable({
  rows,
  keyLabel,
  valueLabel,
  onChange,
}: {
  rows: KvRow[]
  keyLabel: string
  valueLabel: string
  onChange: (rows: KvRow[]) => void
}) {
  return (
    <div className="space-y-2">
      <div className={tableWrapClassName}>
        <div className="overflow-x-auto">
          <table className={tableClassName}>
            <thead>
              <tr>
                <th className={thClassName}>{keyLabel}</th>
                <th className={thClassName}>{valueLabel}</th>
                <th className={cn(thClassName, 'w-12')} />
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 ? (
                <tr>
                  <td
                    colSpan={3}
                    className={cn(tdClassName, 'text-forja-muted')}
                  >
                    No rows — add one below.
                  </td>
                </tr>
              ) : (
                rows.map((r, i) => (
                  <tr key={i} className="border-t border-forja-border/80">
                    <td className={tdClassName}>
                      <Input
                        className="h-8 font-mono-ui text-xs"
                        value={r.key}
                        onChange={(e) => {
                          const next = [...rows]
                          next[i] = { ...r, key: e.target.value }
                          onChange(next)
                        }}
                      />
                    </td>
                    <td className={tdClassName}>
                      <Input
                        className="h-8 font-mono-ui text-xs"
                        value={r.value}
                        onChange={(e) => {
                          const next = [...rows]
                          next[i] = { ...r, value: e.target.value }
                          onChange(next)
                        }}
                      />
                    </td>
                    <td className={tdClassName}>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="size-8 text-forja-muted hover:text-red-300"
                        onClick={() => onChange(rows.filter((_, j) => j !== i))}
                        aria-label="Remove row"
                      >
                        <Trash2 className="size-3.5" />
                      </Button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
      <Button
        type="button"
        variant="secondary"
        size="sm"
        onClick={() => onChange([...rows, { key: '', value: '' }])}
      >
        <Plus className="size-3.5" />
        Add
      </Button>
    </div>
  )
}

export function AdminProvidersPage() {
  const qc = useQueryClient()
  const [mode, setMode] = useState<Mode>('form')
  const [cfg, setCfg] = useState<ProviderRuntimeConfig>(emptyConfig)
  const [jsonText, setJsonText] = useState('')
  const [savedCanon, setSavedCanon] = useState<string | null>(null)
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

  const liveCfg = useMemo(() => {
    if (mode === 'json') {
      const v = parseConfigJson(jsonText)
      return v.ok ? v.value : null
    }
    return cfg
  }, [mode, jsonText, cfg])

  const currentCanon = liveCfg ? canonicalJson(liveCfg) : null

  const dirty =
    savedCanon != null && currentCanon != null && currentCanon !== savedCanon

  useEffect(() => {
    if (!row.dataUpdatedAt || !row.data) return
    if (dirty) return
    const raw = row.data.config
    const v = parseConfig(raw)
    if (!v.ok) {
      setLocalError(v.error)
      setJsonText(JSON.stringify(raw, null, 2))
      setMode('json')
      return
    }
    setCfg(v.value)
    setJsonText(configToPrettyJson(v.value))
    setSavedCanon(canonicalJson(v.value))
    setLocalError(null)
  }, [row.dataUpdatedAt, row.data, dirty])

  const counts = {
    templates: Object.keys(liveCfg?.templates ?? cfg.templates).length,
    apis: Object.keys(liveCfg?.apis ?? cfg.apis).length,
    webstreamr: Object.keys(liveCfg?.webstreamr ?? cfg.webstreamr).length,
    cdn: (liveCfg?.cdnRefererRules ?? cfg.cdnRefererRules).length,
    miruro: (liveCfg?.anime.miruroOrigins ?? cfg.anime.miruroOrigins).length,
    kisskh: (liveCfg?.anime.kisskhMirrors ?? cfg.anime.kisskhMirrors).length,
  }

  const save = useMutation({
    mutationFn: async () => {
      let value: unknown
      if (mode === 'json') {
        const v = parseConfigJson(jsonText)
        if (!v.ok) throw new Error(v.error)
        value = serializeConfig(v.value)
        setCfg(v.value)
      } else {
        value = serializeConfig(cfg)
        setJsonText(configToPrettyJson(cfg))
      }
      const { error } = await adminDb
        .from('provider_runtime_config')
        .update({
          config: value,
          schema_version: SUPPORTED_SCHEMA,
          updated_at: new Date().toISOString(),
        })
        .eq('id', 1)
      if (error) throw error
      return value
    },
    onSuccess: async (value) => {
      const v = parseConfig(value)
      if (v.ok) setSavedCanon(canonicalJson(v.value))
      setLocalError(null)
      await qc.invalidateQueries({ queryKey: ['admin', 'provider_runtime_config'] })
    },
    onError: (e: Error) => setLocalError(e.message),
  })

  const switchMode = (next: Mode) => {
    if (next === mode) return
    if (next === 'json') {
      setJsonText(configToPrettyJson(cfg))
      setLocalError(null)
      setMode('json')
      return
    }
    const v = parseConfigJson(jsonText)
    if (!v.ok) {
      setLocalError(`Fix JSON before switching to Form: ${v.error}`)
      return
    }
    setCfg(v.value)
    setLocalError(null)
    setMode('form')
  }

  const formatJson = () => {
    const v = parseConfigJson(jsonText)
    if (!v.ok) {
      setLocalError(v.error)
      return
    }
    setJsonText(configToPrettyJson(v.value))
    setCfg(v.value)
    setLocalError(null)
  }

  const templateRows = templatesToRows(cfg.templates)
  const apiRows = mapToKv(cfg.apis)
  const wsRows = mapToKv(cfg.webstreamr)

  const setTemplates = (rows: TemplateRow[]) =>
    setCfg((c) => ({ ...c, templates: rowsToTemplates(rows) }))
  const setApis = (rows: KvRow[]) =>
    setCfg((c) => ({ ...c, apis: kvToMap(rows) }))
  const setWs = (rows: KvRow[]) =>
    setCfg((c) => ({ ...c, webstreamr: kvToMap(rows) }))

  const setRule = (i: number, patch: Partial<CdnRefererRule>) =>
    setCfg((c) => {
      const rules = [...c.cdnRefererRules]
      rules[i] = { ...rules[i], ...patch }
      return { ...c, cdnRefererRules: rules }
    })

  const busy = row.isLoading || save.isPending

  return (
    <div className="space-y-6">
      <PageHeader
        title="Providers"
        description="Hosts, URL templates, WebStreamr bases, anime mirrors, CDN Referer rules. App deep-merges over builtins (schema 1). Extract logic stays in the client."
        actions={
          <>
            <div className="flex rounded-lg border border-forja-border p-0.5">
              <Button
                type="button"
                size="sm"
                variant={mode === 'form' ? 'default' : 'ghost'}
                className="h-7"
                disabled={busy}
                onClick={() => switchMode('form')}
              >
                Form
              </Button>
              <Button
                type="button"
                size="sm"
                variant={mode === 'json' ? 'default' : 'ghost'}
                className="h-7"
                disabled={busy}
                onClick={() => switchMode('json')}
              >
                JSON
              </Button>
            </div>
            {mode === 'json' ? (
              <Button
                type="button"
                variant="secondary"
                size="sm"
                disabled={busy}
                onClick={() => formatJson()}
              >
                Format
              </Button>
            ) : null}
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={busy}
              onClick={() => void row.refetch()}
            >
              Reload
            </Button>
            <Button
              type="button"
              size="sm"
              disabled={busy || (mode === 'json' && currentCanon == null)}
              onClick={() => save.mutate()}
            >
              {save.isPending ? 'Saving…' : dirty ? 'Save*' : 'Save'}
            </Button>
          </>
        }
      />

      <div className="flex flex-wrap items-center gap-2">
        <MetricChip label="Schema" value={SUPPORTED_SCHEMA} />
        <MetricChip label="Templates" value={counts.templates} />
        <MetricChip label="APIs" value={counts.apis} />
        <MetricChip label="WebStreamr" value={counts.webstreamr} />
        <MetricChip label="CDN rules" value={counts.cdn} />
        {row.data?.updated_at ? (
          <span className="text-xs text-forja-muted">
            Updated {new Date(row.data.updated_at).toLocaleString()}
            {dirty ? ' · unsaved changes' : ''}
          </span>
        ) : null}
      </div>

      {row.error ? (
        <p className="text-sm text-red-400">{(row.error as Error).message}</p>
      ) : null}
      {localError || save.error ? (
        <p className="text-sm text-red-400">
          {localError || (save.error as Error).message}
        </p>
      ) : null}
      {save.isSuccess && !localError && !dirty ? (
        <p className="text-sm text-forja-green">
          Saved. Clients refresh within ~6h TTL or next cold start.
        </p>
      ) : null}

      {mode === 'json' ? (
        <Panel className="overflow-hidden p-0">
          <textarea
            className="min-h-128 w-full resize-y border-0 bg-transparent p-4 font-mono-ui text-xs leading-relaxed text-forja-text outline-none focus:ring-0"
            spellCheck={false}
            value={jsonText}
            disabled={row.isLoading}
            onChange={(e) => {
              setJsonText(e.target.value)
              setLocalError(null)
              save.reset()
            }}
          />
        </Panel>
      ) : (
        <div className="space-y-4">
          <Panel>
            <PanelLabel>Templates</PanelLabel>
            <p className="mt-1 mb-3 text-xs text-forja-muted">
              Embed URL patterns — placeholders {'{tmdb}'}, {'{season}'},{' '}
              {'{episode}'}.
            </p>
            <div className="space-y-2">
              <div className={tableWrapClassName}>
                <div className="overflow-x-auto">
                  <table className={tableClassName}>
                    <thead>
                      <tr>
                        <th className={thClassName}>Provider</th>
                        <th className={thClassName}>Movie</th>
                        <th className={thClassName}>TV</th>
                        <th className={cn(thClassName, 'w-12')} />
                      </tr>
                    </thead>
                    <tbody>
                      {templateRows.length === 0 ? (
                        <tr>
                          <td
                            colSpan={4}
                            className={cn(tdClassName, 'text-forja-muted')}
                          >
                            No templates — add one below.
                          </td>
                        </tr>
                      ) : (
                        templateRows.map((r, i) => (
                          <tr
                            key={i}
                            className="border-t border-forja-border/80"
                          >
                            <td className={tdClassName}>
                              <Input
                                className="h-8 font-mono-ui text-xs"
                                value={r.id}
                                onChange={(e) => {
                                  const next = [...templateRows]
                                  next[i] = { ...r, id: e.target.value }
                                  setTemplates(next)
                                }}
                              />
                            </td>
                            <td className={tdClassName}>
                              <Input
                                className="h-8 font-mono-ui text-xs"
                                value={r.movie}
                                onChange={(e) => {
                                  const next = [...templateRows]
                                  next[i] = { ...r, movie: e.target.value }
                                  setTemplates(next)
                                }}
                              />
                            </td>
                            <td className={tdClassName}>
                              <Input
                                className="h-8 font-mono-ui text-xs"
                                value={r.tv}
                                onChange={(e) => {
                                  const next = [...templateRows]
                                  next[i] = { ...r, tv: e.target.value }
                                  setTemplates(next)
                                }}
                              />
                            </td>
                            <td className={tdClassName}>
                              <Button
                                type="button"
                                variant="ghost"
                                size="icon"
                                className="size-8 text-forja-muted hover:text-red-300"
                                onClick={() =>
                                  setTemplates(
                                    templateRows.filter((_, j) => j !== i),
                                  )
                                }
                                aria-label="Remove template"
                              >
                                <Trash2 className="size-3.5" />
                              </Button>
                            </td>
                          </tr>
                        ))
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
              <Button
                type="button"
                variant="secondary"
                size="sm"
                onClick={() =>
                  setTemplates([
                    ...templateRows,
                    { id: '', movie: '', tv: '' },
                  ])
                }
              >
                <Plus className="size-3.5" />
                Add template
              </Button>
            </div>
          </Panel>

          <Panel>
            <PanelLabel>APIs</PanelLabel>
            <p className="mt-1 mb-3 text-xs text-forja-muted">
              Named bases (vidnestApi, vidsrcEmbed, anikotoApi, …).
            </p>
            <KvTable
              rows={apiRows}
              keyLabel="Key"
              valueLabel="URL / host"
              onChange={setApis}
            />
          </Panel>

          <Panel>
            <PanelLabel>WebStreamr</PanelLabel>
            <p className="mt-1 mb-3 text-xs text-forja-muted">
              Source id → resolved base URL.
            </p>
            <KvTable
              rows={wsRows}
              keyLabel="Source id"
              valueLabel="Base URL"
              onChange={setWs}
            />
          </Panel>

          <Panel>
            <PanelLabel>Anime</PanelLabel>
            <div className="mt-4 space-y-6">
              <EmbedHostFields
                title="Megaplay"
                value={cfg.anime.megaplay}
                onChange={(megaplay) =>
                  setCfg((c) => ({
                    ...c,
                    anime: { ...c.anime, megaplay },
                  }))
                }
              />
              <EmbedHostFields
                title="Vidwish"
                value={cfg.anime.vidwish}
                onChange={(vidwish) =>
                  setCfg((c) => ({
                    ...c,
                    anime: { ...c.anime, vidwish },
                  }))
                }
              />
              <div className="grid gap-4 sm:grid-cols-2">
                <label className="block space-y-1.5">
                  <Label>Miruro origins ({counts.miruro})</Label>
                  <textarea
                    className="min-h-28 w-full resize-y rounded-lg border border-forja-border bg-forja-elevated/60 p-3 font-mono-ui text-xs text-forja-text outline-none focus-visible:ring-2 focus-visible:ring-forja-green/35"
                    spellCheck={false}
                    placeholder="https://www.miruro.tv"
                    value={listToLines(cfg.anime.miruroOrigins)}
                    onChange={(e) =>
                      setCfg((c) => ({
                        ...c,
                        anime: {
                          ...c.anime,
                          miruroOrigins: linesToList(e.target.value),
                        },
                      }))
                    }
                  />
                  <p className="text-[11px] text-forja-muted">One URL per line</p>
                </label>
                <label className="block space-y-1.5">
                  <Label>KissKh mirrors ({counts.kisskh})</Label>
                  <textarea
                    className="min-h-28 w-full resize-y rounded-lg border border-forja-border bg-forja-elevated/60 p-3 font-mono-ui text-xs text-forja-text outline-none focus-visible:ring-2 focus-visible:ring-forja-green/35"
                    spellCheck={false}
                    placeholder="https://kisskh.co"
                    value={listToLines(cfg.anime.kisskhMirrors)}
                    onChange={(e) =>
                      setCfg((c) => ({
                        ...c,
                        anime: {
                          ...c.anime,
                          kisskhMirrors: linesToList(e.target.value),
                        },
                      }))
                    }
                  />
                  <p className="text-[11px] text-forja-muted">One URL per line</p>
                </label>
              </div>
            </div>
          </Panel>

          <Panel>
            <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
              <div>
                <PanelLabel>CDN Referer rules</PanelLabel>
                <p className="mt-1 text-xs text-forja-muted">
                  Match stream host substrings → force Referer / Origin.
                </p>
              </div>
              <Button
                type="button"
                variant="secondary"
                size="sm"
                onClick={() =>
                  setCfg((c) => ({
                    ...c,
                    cdnRefererRules: [
                      ...c.cdnRefererRules,
                      {
                        hostContains: [],
                        referer: '',
                        origin: '',
                        acceptRefererContains: [],
                      },
                    ],
                  }))
                }
              >
                <Plus className="size-3.5" />
                Add rule
              </Button>
            </div>
            {cfg.cdnRefererRules.length === 0 ? (
              <p className="text-sm text-forja-muted">No CDN rules.</p>
            ) : (
              <div className="space-y-3">
                {cfg.cdnRefererRules.map((r, i) => (
                  <div
                    key={i}
                    className="rounded-xl border border-forja-border/80 bg-black/20 p-4"
                  >
                    <div className="mb-3 flex items-center justify-between gap-2">
                      <p className="text-xs font-semibold uppercase tracking-[0.14em] text-forja-muted">
                        Rule {i + 1}
                      </p>
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="text-forja-muted hover:text-red-300"
                        onClick={() =>
                          setCfg((c) => ({
                            ...c,
                            cdnRefererRules: c.cdnRefererRules.filter(
                              (_, j) => j !== i,
                            ),
                          }))
                        }
                      >
                        <Trash2 className="size-3.5" />
                        Remove
                      </Button>
                    </div>
                    <div className="grid gap-3 sm:grid-cols-2">
                      <Field
                        label="hostContains (comma-separated)"
                        value={listToCsv(r.hostContains)}
                        onChange={(v) =>
                          setRule(i, { hostContains: csvToList(v) })
                        }
                        placeholder="nekostream, mewstream"
                        mono
                      />
                      <Field
                        label="acceptRefererContains (optional)"
                        value={listToCsv(r.acceptRefererContains)}
                        onChange={(v) =>
                          setRule(i, { acceptRefererContains: csvToList(v) })
                        }
                        placeholder="megaplay"
                        mono
                      />
                      <Field
                        label="Referer"
                        value={r.referer}
                        onChange={(v) => setRule(i, { referer: v })}
                        mono
                      />
                      <Field
                        label="Origin"
                        value={r.origin}
                        onChange={(v) => setRule(i, { origin: v })}
                        mono
                      />
                    </div>
                  </div>
                ))}
              </div>
            )}
          </Panel>
        </div>
      )}
    </div>
  )
}
