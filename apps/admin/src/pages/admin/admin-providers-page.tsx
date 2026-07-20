import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus, Trash2 } from 'lucide-react'
import { useEffect, useMemo, useState, type ReactNode } from 'react'
import {
  PageHeader,
  tableClassName,
  tdClassName,
  thClassName,
} from '@/components/admin-ui'
import { Button } from '@/components/ui/button'
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

const cellInputClassName =
  'h-8 w-full min-w-0 border-0 bg-transparent px-1.5 py-1 font-mono-ui text-xs text-forja-text outline-none placeholder:text-forja-muted/70 focus:bg-forja-green/[0.06] focus:ring-0'

const plainInputClassName =
  'h-8 w-full border-b border-forja-border/70 bg-transparent px-0 py-1 font-mono-ui text-xs text-forja-text outline-none placeholder:text-forja-muted/70 focus:border-forja-green/50 focus:ring-0'

const plainAreaClassName =
  'min-h-24 w-full resize-y border-b border-forja-border/70 bg-transparent px-0 py-1.5 font-mono-ui text-xs leading-relaxed text-forja-text outline-none placeholder:text-forja-muted/70 focus:border-forja-green/50 focus:ring-0'

function Section({
  title,
  hint,
  action,
  children,
}: {
  title: string
  hint?: string
  action?: ReactNode
  children: ReactNode
}) {
  return (
    <section className="space-y-3">
      <div className="flex flex-wrap items-end justify-between gap-2 border-b border-forja-border/60 pb-2">
        <div>
          <h2 className="text-sm font-semibold text-forja-text">{title}</h2>
          {hint ? (
            <p className="mt-0.5 text-xs text-forja-muted">{hint}</p>
          ) : null}
        </div>
        {action}
      </div>
      {children}
    </section>
  )
}

function CellInput({
  value,
  onChange,
  placeholder,
  className,
}: {
  value: string
  onChange: (v: string) => void
  placeholder?: string
  className?: string
}) {
  return (
    <input
      className={cn(cellInputClassName, className)}
      value={value}
      placeholder={placeholder}
      onChange={(e) => onChange(e.target.value)}
      spellCheck={false}
    />
  )
}

function PlainField({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string
  value: string
  onChange: (v: string) => void
  placeholder?: string
}) {
  return (
    <label className="block space-y-1">
      <Label className="text-[11px] text-forja-muted">{label}</Label>
      <input
        className={plainInputClassName}
        value={value}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        spellCheck={false}
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
    <div className="space-y-2">
      <p className="text-xs font-medium text-forja-text">{title}</p>
      <div className="grid gap-x-4 gap-y-2 sm:grid-cols-2">
        <PlainField label="Host" value={value.host} onChange={(v) => set('host', v)} />
        <PlainField
          label="Scrape referer"
          value={value.scrapeReferer}
          onChange={(v) => set('scrapeReferer', v)}
        />
        <PlainField
          label="Path (catalog)"
          value={value.pathCatalog}
          onChange={(v) => set('pathCatalog', v)}
          placeholder="/stream/s-2/{embedId}/{lang}"
        />
        <PlainField
          label="Path (AniList)"
          value={value.pathAnilist}
          onChange={(v) => set('pathAnilist', v)}
          placeholder="/stream/ani/{anilistId}/{ep}/{lang}"
        />
      </div>
    </div>
  )
}

function DataTable({
  headers,
  colSpan,
  empty,
  children,
  footer,
}: {
  headers: ReactNode[]
  colSpan: number
  empty?: boolean
  children: ReactNode
  footer?: ReactNode
}) {
  return (
    <div className="space-y-2">
      <div className="overflow-x-auto border-y border-forja-border/70">
        <table className={tableClassName}>
          <thead>
            <tr className="border-b border-forja-border/60">
              {headers.map((h, i) => (
                <th
                  key={i}
                  className={cn(
                    thClassName,
                    'bg-transparent px-2 py-1.5 font-medium tracking-[0.08em]',
                    i === headers.length - 1 && 'w-10',
                  )}
                >
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {empty ? (
              <tr>
                <td
                  colSpan={colSpan}
                  className={cn(tdClassName, 'px-2 py-3 text-forja-muted')}
                >
                  No rows — add one below.
                </td>
              </tr>
            ) : (
              children
            )}
          </tbody>
        </table>
      </div>
      {footer}
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
    <DataTable
      headers={[keyLabel, valueLabel, '']}
      colSpan={3}
      empty={rows.length === 0}
      footer={
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="h-7 px-2 text-forja-muted hover:text-forja-text"
          onClick={() => onChange([...rows, { key: '', value: '' }])}
        >
          <Plus className="size-3.5" />
          Add
        </Button>
      }
    >
      {rows.map((r, i) => (
        <tr
          key={i}
          className="border-t border-forja-border/40 hover:bg-white/2"
        >
          <td className={cn(tdClassName, 'px-1 py-0.5')}>
            <CellInput
              value={r.key}
              onChange={(v) => {
                const next = [...rows]
                next[i] = { ...r, key: v }
                onChange(next)
              }}
            />
          </td>
          <td className={cn(tdClassName, 'px-1 py-0.5')}>
            <CellInput
              value={r.value}
              onChange={(v) => {
                const next = [...rows]
                next[i] = { ...r, value: v }
                onChange(next)
              }}
            />
          </td>
          <td className={cn(tdClassName, 'px-1 py-0.5')}>
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="size-7 text-forja-muted hover:text-red-300"
              onClick={() => onChange(rows.filter((_, j) => j !== i))}
              aria-label="Remove row"
            >
              <Trash2 className="size-3.5" />
            </Button>
          </td>
        </tr>
      ))}
    </DataTable>
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

      <p className="text-xs text-forja-muted">
        schema {SUPPORTED_SCHEMA}
        <span className="mx-2 text-forja-border">·</span>
        {counts.templates} templates
        <span className="mx-2 text-forja-border">·</span>
        {counts.apis} apis
        <span className="mx-2 text-forja-border">·</span>
        {counts.webstreamr} webstreamr
        <span className="mx-2 text-forja-border">·</span>
        {counts.cdn} cdn rules
        {row.data?.updated_at ? (
          <>
            <span className="mx-2 text-forja-border">·</span>
            updated {new Date(row.data.updated_at).toLocaleString()}
            {dirty ? ' · unsaved' : ''}
          </>
        ) : null}
      </p>

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
        <textarea
          className="min-h-128 w-full resize-y border-y border-forja-border/70 bg-transparent py-3 font-mono-ui text-xs leading-relaxed text-forja-text outline-none focus:ring-0"
          spellCheck={false}
          value={jsonText}
          disabled={row.isLoading}
          onChange={(e) => {
            setJsonText(e.target.value)
            setLocalError(null)
            save.reset()
          }}
        />
      ) : (
        <div className="space-y-8">
          <Section
            title="Templates"
            hint={`Embed URL patterns — {tmdb}, {season}, {episode}.`}
          >
            <DataTable
              headers={['Provider', 'Movie', 'TV', '']}
              colSpan={4}
              empty={templateRows.length === 0}
              footer={
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="h-7 px-2 text-forja-muted hover:text-forja-text"
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
              }
            >
              {templateRows.map((r, i) => (
                <tr
                  key={i}
                  className="border-t border-forja-border/40 hover:bg-white/2"
                >
                  <td className={cn(tdClassName, 'w-36 px-1 py-0.5')}>
                    <CellInput
                      value={r.id}
                      onChange={(v) => {
                        const next = [...templateRows]
                        next[i] = { ...r, id: v }
                        setTemplates(next)
                      }}
                    />
                  </td>
                  <td className={cn(tdClassName, 'px-1 py-0.5')}>
                    <CellInput
                      value={r.movie}
                      onChange={(v) => {
                        const next = [...templateRows]
                        next[i] = { ...r, movie: v }
                        setTemplates(next)
                      }}
                    />
                  </td>
                  <td className={cn(tdClassName, 'px-1 py-0.5')}>
                    <CellInput
                      value={r.tv}
                      onChange={(v) => {
                        const next = [...templateRows]
                        next[i] = { ...r, tv: v }
                        setTemplates(next)
                      }}
                    />
                  </td>
                  <td className={cn(tdClassName, 'px-1 py-0.5')}>
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      className="size-7 text-forja-muted hover:text-red-300"
                      onClick={() =>
                        setTemplates(templateRows.filter((_, j) => j !== i))
                      }
                      aria-label="Remove template"
                    >
                      <Trash2 className="size-3.5" />
                    </Button>
                  </td>
                </tr>
              ))}
            </DataTable>
          </Section>

          <Section
            title="APIs"
            hint="Named bases (vidnestApi, vidsrcEmbed, anikotoApi, …)."
          >
            <KvTable
              rows={apiRows}
              keyLabel="Key"
              valueLabel="URL / host"
              onChange={setApis}
            />
          </Section>

          <Section
            title="WebStreamr"
            hint="Source id → resolved base URL."
          >
            <KvTable
              rows={wsRows}
              keyLabel="Source id"
              valueLabel="Base URL"
              onChange={setWs}
            />
          </Section>

          <Section title="Anime">
            <div className="space-y-6">
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
              <div className="grid gap-6 sm:grid-cols-2">
                <label className="block space-y-1">
                  <Label className="text-[11px] text-forja-muted">
                    Miruro origins ({counts.miruro})
                  </Label>
                  <textarea
                    className={plainAreaClassName}
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
                <label className="block space-y-1">
                  <Label className="text-[11px] text-forja-muted">
                    KissKh mirrors ({counts.kisskh})
                  </Label>
                  <textarea
                    className={plainAreaClassName}
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
          </Section>

          <Section
            title="CDN Referer rules"
            hint="Match stream host substrings → force Referer / Origin."
            action={
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-7 px-2 text-forja-muted hover:text-forja-text"
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
            }
          >
            {cfg.cdnRefererRules.length === 0 ? (
              <p className="text-sm text-forja-muted">No CDN rules.</p>
            ) : (
              <DataTable
                headers={[
                  'hostContains',
                  'acceptRefererContains',
                  'Referer',
                  'Origin',
                  '',
                ]}
                colSpan={5}
              >
                {cfg.cdnRefererRules.map((r, i) => (
                  <tr
                    key={i}
                    className="border-t border-forja-border/40 hover:bg-white/2"
                  >
                    <td className={cn(tdClassName, 'px-1 py-0.5')}>
                      <CellInput
                        value={listToCsv(r.hostContains)}
                        onChange={(v) =>
                          setRule(i, { hostContains: csvToList(v) })
                        }
                        placeholder="nekostream, mewstream"
                      />
                    </td>
                    <td className={cn(tdClassName, 'px-1 py-0.5')}>
                      <CellInput
                        value={listToCsv(r.acceptRefererContains)}
                        onChange={(v) =>
                          setRule(i, {
                            acceptRefererContains: csvToList(v),
                          })
                        }
                        placeholder="megaplay"
                      />
                    </td>
                    <td className={cn(tdClassName, 'px-1 py-0.5')}>
                      <CellInput
                        value={r.referer}
                        onChange={(v) => setRule(i, { referer: v })}
                      />
                    </td>
                    <td className={cn(tdClassName, 'px-1 py-0.5')}>
                      <CellInput
                        value={r.origin}
                        onChange={(v) => setRule(i, { origin: v })}
                      />
                    </td>
                    <td className={cn(tdClassName, 'px-1 py-0.5')}>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="size-7 text-forja-muted hover:text-red-300"
                        onClick={() =>
                          setCfg((c) => ({
                            ...c,
                            cdnRefererRules: c.cdnRefererRules.filter(
                              (_, j) => j !== i,
                            ),
                          }))
                        }
                        aria-label="Remove rule"
                      >
                        <Trash2 className="size-3.5" />
                      </Button>
                    </td>
                  </tr>
                ))}
              </DataTable>
            )}
          </Section>
        </div>
      )}
    </div>
  )
}
