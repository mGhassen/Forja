import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  CheckCircle2,
  ExternalLink,
  Package,
  Plus,
  RefreshCw,
  Trash2,
  XCircle,
} from 'lucide-react'
import {
  PageHeader,
  TablePagination,
  tableClassName,
  tdClassName,
  thClassName,
} from '@/components/admin-ui'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { useTablePagination } from '@/lib/use-table-pagination'
import {
  deletePluginBundle,
  deletePluginPack,
  errMessage,
  fetchManifest,
  listPluginBundles,
  listPluginPacks,
  persistValidation,
  slugifyId,
  updatePluginBundle,
  updatePluginPack,
  upsertPluginBundle,
  upsertPluginPack,
  validateManifestJson,
  validatePackAtUrl,
  type PluginBundleWithItems,
  type PluginPack,
} from '@/lib/plugin-catalog'
import { formatAdminDateTime } from '@/lib/iptv-portal-expiry'
import { cn } from '@/lib/utils'

type Tab = 'packs' | 'bundles'
type SortKey =
  | 'id'
  | 'name'
  | 'kind'
  | 'version'
  | 'published'
  | 'recommended'
  | 'validated'
type SortDir = 'asc' | 'desc'
type ColKey =
  | 'id'
  | 'name'
  | 'kind'
  | 'version'
  | 'official'
  | 'recommended'
  | 'published'
  | 'validated'
  | 'actions'

const STORAGE_KEY = 'admin.plugins.ui'
const ALL_COLS: ColKey[] = [
  'id',
  'name',
  'kind',
  'version',
  'official',
  'recommended',
  'published',
  'validated',
  'actions',
]
const DEFAULT_COLS: ColKey[] = [...ALL_COLS]

type UiState = {
  tab: Tab
  sortKey: SortKey
  sortDir: SortDir
  cols: ColKey[]
  kind: string
  published: 'all' | 'yes' | 'no'
  official: 'all' | 'yes' | 'no'
  tag: string
  search: string
}

const DEFAULT_UI: UiState = {
  tab: 'packs',
  sortKey: 'id',
  sortDir: 'asc',
  cols: DEFAULT_COLS,
  kind: 'all',
  published: 'all',
  official: 'all',
  tag: '',
  search: '',
}

function readUi(): UiState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return DEFAULT_UI
    const parsed = JSON.parse(raw) as Partial<UiState>
    return {
      ...DEFAULT_UI,
      ...parsed,
      cols:
        Array.isArray(parsed.cols) && parsed.cols.length > 0
          ? (parsed.cols.filter((c) => ALL_COLS.includes(c as ColKey)) as ColKey[])
          : DEFAULT_COLS,
    }
  } catch {
    return DEFAULT_UI
  }
}

function writeUi(next: UiState) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(next))
  } catch {
    /* ignore */
  }
}

function boolLabel(v: boolean) {
  return v ? 'Yes' : 'No'
}

export function AdminPluginsPage() {
  const qc = useQueryClient()
  const [ui, setUi] = useState<UiState>(() => readUi())
  const [selected, setSelected] = useState<Set<string>>(() => new Set())
  const [busyId, setBusyId] = useState<string | null>(null)
  const [bulkBusy, setBulkBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [registerOpen, setRegisterOpen] = useState(false)
  const [editPack, setEditPack] = useState<PluginPack | null>(null)
  const [bundleEdit, setBundleEdit] = useState<PluginBundleWithItems | null>(
    null,
  )
  const [bundleCreate, setBundleCreate] = useState(false)

  useEffect(() => {
    writeUi(ui)
  }, [ui])

  const packsQuery = useQuery({
    queryKey: ['admin', 'plugin_packs'],
    queryFn: listPluginPacks,
  })
  const bundlesQuery = useQuery({
    queryKey: ['admin', 'plugin_bundles'],
    queryFn: listPluginBundles,
  })

  const packs = packsQuery.data ?? []
  const bundles = bundlesQuery.data ?? []

  const kinds = useMemo(() => {
    const set = new Set(
      (packsQuery.data ?? []).map((p) => p.kind).filter(Boolean),
    )
    return [...set].sort()
  }, [packsQuery.data])

  const filtered = useMemo(() => {
    const source = packsQuery.data ?? []
    const q = ui.search.trim().toLowerCase()
    const tag = ui.tag.trim().toLowerCase()
    let rows = source.filter((p) => {
      if (ui.kind !== 'all' && p.kind !== ui.kind) return false
      if (ui.published === 'yes' && !p.published) return false
      if (ui.published === 'no' && p.published) return false
      if (ui.official === 'yes' && !p.official) return false
      if (ui.official === 'no' && p.official) return false
      if (tag && !(p.tags ?? []).some((t) => t.toLowerCase().includes(tag))) {
        return false
      }
      if (!q) return true
      const hay = [p.id, p.name, p.kind, p.manifest_url, p.cached_version ?? '']
        .join(' ')
        .toLowerCase()
      return hay.includes(q)
    })

    const dir = ui.sortDir === 'asc' ? 1 : -1
    rows = [...rows].sort((a, b) => {
      const key = ui.sortKey
      const av =
        key === 'version'
          ? (a.cached_version ?? '')
          : key === 'validated'
            ? (a.last_validated_at ?? '')
            : key === 'published'
              ? (a.published ? 1 : 0)
              : key === 'recommended'
                ? (a.recommended ? 1 : 0)
                : key === 'id'
                  ? a.id
                  : key === 'name'
                    ? a.name
                    : key === 'kind'
                      ? a.kind
                      : a.id
      const bv =
        key === 'version'
          ? (b.cached_version ?? '')
          : key === 'validated'
            ? (b.last_validated_at ?? '')
            : key === 'published'
              ? (b.published ? 1 : 0)
              : key === 'recommended'
                ? (b.recommended ? 1 : 0)
                : key === 'id'
                  ? b.id
                  : key === 'name'
                    ? b.name
                    : key === 'kind'
                      ? b.kind
                      : b.id
      if (av < bv) return -1 * dir
      if (av > bv) return 1 * dir
      return a.id.localeCompare(b.id)
    })
    return rows
  }, [packsQuery.data, ui])

  const page = useTablePagination(filtered, {
    initialPageSize: 40,
    resetKey: `${ui.search}|${ui.kind}|${ui.published}|${ui.official}|${ui.tag}|${ui.sortKey}|${ui.sortDir}`,
  })
  const pageRows = page.pageRows

  function toggleCol(col: ColKey) {
    setUi((prev) => {
      const has = prev.cols.includes(col)
      if (has && prev.cols.length <= 2) return prev
      return {
        ...prev,
        cols: has ? prev.cols.filter((c) => c !== col) : [...prev.cols, col],
      }
    })
  }

  function toggleSort(key: SortKey) {
    setUi((prev) => {
      if (prev.sortKey === key) {
        return { ...prev, sortDir: prev.sortDir === 'asc' ? 'desc' : 'asc' }
      }
      return { ...prev, sortKey: key, sortDir: 'asc' }
    })
  }

  async function runValidate(pack: PluginPack) {
    setBusyId(pack.id)
    setError(null)
    try {
      const result = await validatePackAtUrl(pack.manifest_url)
      await persistValidation(pack.id, result)
      await qc.invalidateQueries({ queryKey: ['admin', 'plugin_packs'] })
    } catch (e) {
      setError(errMessage(e))
    } finally {
      setBusyId(null)
    }
  }

  async function bulkValidate() {
    const ids = [...selected]
    if (ids.length === 0) return
    setBulkBusy(true)
    setError(null)
    try {
      for (const id of ids) {
        const pack = packs.find((p) => p.id === id)
        if (!pack) continue
        setBusyId(id)
        const result = await validatePackAtUrl(pack.manifest_url)
        await persistValidation(id, result)
      }
      await qc.invalidateQueries({ queryKey: ['admin', 'plugin_packs'] })
    } catch (e) {
      setError(errMessage(e))
    } finally {
      setBusyId(null)
      setBulkBusy(false)
    }
  }

  async function bulkSet(patch: {
    published?: boolean
    recommended?: boolean
  }) {
    const ids = [...selected]
    if (ids.length === 0) return
    setBulkBusy(true)
    setError(null)
    try {
      for (const id of ids) {
        await updatePluginPack(id, patch)
      }
      await qc.invalidateQueries({ queryKey: ['admin', 'plugin_packs'] })
      setSelected(new Set())
    } catch (e) {
      setError(errMessage(e))
    } finally {
      setBulkBusy(false)
    }
  }

  const deleteMut = useMutation({
    mutationFn: deletePluginPack,
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ['admin', 'plugin_packs'] })
    },
    onError: (e) => setError(errMessage(e)),
  })

  const show = (c: ColKey) => ui.cols.includes(c)

  return (
    <div className="space-y-6">
      <PageHeader
        title="Plugins"
        description="Catalog metadata, validation, and product bundles. Pack files stay on GitHub raw — this page publishes what the app sees."
        actions={
          <div className="flex flex-wrap gap-2">
            <Button
              type="button"
              variant={ui.tab === 'packs' ? 'default' : 'outline'}
              size="sm"
              onClick={() => setUi((u) => ({ ...u, tab: 'packs' }))}
            >
              <Package className="size-3.5" />
              Packs
            </Button>
            <Button
              type="button"
              variant={ui.tab === 'bundles' ? 'default' : 'outline'}
              size="sm"
              onClick={() => setUi((u) => ({ ...u, tab: 'bundles' }))}
            >
              Bundles
            </Button>
          </div>
        }
      />

      {error ? (
        <p className="rounded-lg border border-red-500/30 bg-red-500/10 px-3 py-2 text-sm text-red-300">
          {error}
        </p>
      ) : null}

      {ui.tab === 'packs' ? (
        <>
          <div className="flex flex-wrap items-end gap-3">
            <div className="min-w-[180px] flex-1 space-y-1">
              <Label className="text-xs text-forja-muted">Search</Label>
              <Input
                value={ui.search}
                onChange={(e) =>
                  setUi((u) => ({ ...u, search: e.target.value }))
                }
                placeholder="id, name, url…"
              />
            </div>
            <div className="w-[140px] space-y-1">
              <Label className="text-xs text-forja-muted">Kind</Label>
              <Select
                value={ui.kind}
                onValueChange={(v) => setUi((u) => ({ ...u, kind: v }))}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All</SelectItem>
                  {kinds.map((k) => (
                    <SelectItem key={k} value={k}>
                      {k}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="w-[120px] space-y-1">
              <Label className="text-xs text-forja-muted">Published</Label>
              <Select
                value={ui.published}
                onValueChange={(v) =>
                  setUi((u) => ({
                    ...u,
                    published: v as UiState['published'],
                  }))
                }
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All</SelectItem>
                  <SelectItem value="yes">Yes</SelectItem>
                  <SelectItem value="no">No</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="w-[120px] space-y-1">
              <Label className="text-xs text-forja-muted">Official</Label>
              <Select
                value={ui.official}
                onValueChange={(v) =>
                  setUi((u) => ({
                    ...u,
                    official: v as UiState['official'],
                  }))
                }
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All</SelectItem>
                  <SelectItem value="yes">Yes</SelectItem>
                  <SelectItem value="no">No</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="w-[140px] space-y-1">
              <Label className="text-xs text-forja-muted">Tag</Label>
              <Input
                value={ui.tag}
                onChange={(e) => setUi((u) => ({ ...u, tag: e.target.value }))}
                placeholder="anime…"
              />
            </div>
            <Button
              type="button"
              size="sm"
              onClick={() => setRegisterOpen(true)}
            >
              <Plus className="size-3.5" />
              Register
            </Button>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs text-forja-muted">Columns:</span>
            {ALL_COLS.filter((c) => c !== 'actions').map((c) => (
              <button
                key={c}
                type="button"
                className={cn(
                  'rounded-md px-2 py-0.5 text-xs',
                  show(c)
                    ? 'bg-forja-green/15 text-forja-green'
                    : 'bg-white/[0.04] text-forja-muted',
                )}
                onClick={() => toggleCol(c)}
              >
                {c}
              </button>
            ))}
          </div>

          {selected.size > 0 ? (
            <div className="flex flex-wrap items-center gap-2 rounded-xl border border-forja-border/80 bg-forja-elevated/40 px-3 py-2">
              <span className="text-xs text-forja-muted">
                {selected.size} selected
              </span>
              <Button
                type="button"
                size="sm"
                variant="outline"
                disabled={bulkBusy}
                onClick={() => void bulkValidate()}
              >
                <RefreshCw className="size-3.5" />
                Validate
              </Button>
              <Button
                type="button"
                size="sm"
                variant="outline"
                disabled={bulkBusy}
                onClick={() => void bulkSet({ published: true })}
              >
                Publish
              </Button>
              <Button
                type="button"
                size="sm"
                variant="outline"
                disabled={bulkBusy}
                onClick={() => void bulkSet({ published: false })}
              >
                Unpublish
              </Button>
              <Button
                type="button"
                size="sm"
                variant="outline"
                disabled={bulkBusy}
                onClick={() => void bulkSet({ recommended: true })}
              >
                Recommend
              </Button>
              <Button
                type="button"
                size="sm"
                variant="ghost"
                onClick={() => setSelected(new Set())}
              >
                Clear
              </Button>
            </div>
          ) : null}

          <div className="overflow-x-auto rounded-xl border border-forja-border">
            <table className={tableClassName}>
              <thead>
                <tr>
                  <th className={thClassName}>
                    <input
                      type="checkbox"
                      checked={
                        pageRows.length > 0 &&
                        pageRows.every((r) => selected.has(r.id))
                      }
                      onChange={(e) => {
                        setSelected((prev) => {
                          const next = new Set(prev)
                          if (e.target.checked) {
                            for (const r of pageRows) next.add(r.id)
                          } else {
                            for (const r of pageRows) next.delete(r.id)
                          }
                          return next
                        })
                      }}
                    />
                  </th>
                  {show('id') ? (
                    <th className={thClassName}>
                      <button type="button" onClick={() => toggleSort('id')}>
                        ID
                      </button>
                    </th>
                  ) : null}
                  {show('name') ? (
                    <th className={thClassName}>
                      <button type="button" onClick={() => toggleSort('name')}>
                        Name
                      </button>
                    </th>
                  ) : null}
                  {show('kind') ? (
                    <th className={thClassName}>
                      <button type="button" onClick={() => toggleSort('kind')}>
                        Kind
                      </button>
                    </th>
                  ) : null}
                  {show('version') ? (
                    <th className={thClassName}>
                      <button
                        type="button"
                        onClick={() => toggleSort('version')}
                      >
                        Version
                      </button>
                    </th>
                  ) : null}
                  {show('official') ? (
                    <th className={thClassName}>Official</th>
                  ) : null}
                  {show('recommended') ? (
                    <th className={thClassName}>
                      <button
                        type="button"
                        onClick={() => toggleSort('recommended')}
                      >
                        Rec
                      </button>
                    </th>
                  ) : null}
                  {show('published') ? (
                    <th className={thClassName}>
                      <button
                        type="button"
                        onClick={() => toggleSort('published')}
                      >
                        Pub
                      </button>
                    </th>
                  ) : null}
                  {show('validated') ? (
                    <th className={thClassName}>
                      <button
                        type="button"
                        onClick={() => toggleSort('validated')}
                      >
                        Validated
                      </button>
                    </th>
                  ) : null}
                  {show('actions') ? (
                    <th className={thClassName}>Actions</th>
                  ) : null}
                </tr>
              </thead>
              <tbody>
                {packsQuery.isLoading ? (
                  <tr>
                    <td className={tdClassName} colSpan={10}>
                      Loading…
                    </td>
                  </tr>
                ) : pageRows.length === 0 ? (
                  <tr>
                    <td className={tdClassName} colSpan={10}>
                      No packs match filters.
                    </td>
                  </tr>
                ) : (
                  pageRows.map((pack) => {
                    const validation = pack.last_validation as
                      | { ok?: boolean; errors?: string[] }
                      | null
                    return (
                      <tr key={pack.id} className="border-t border-forja-border/60">
                        <td className={tdClassName}>
                          <input
                            type="checkbox"
                            checked={selected.has(pack.id)}
                            onChange={(e) => {
                              setSelected((prev) => {
                                const next = new Set(prev)
                                if (e.target.checked) next.add(pack.id)
                                else next.delete(pack.id)
                                return next
                              })
                            }}
                          />
                        </td>
                        {show('id') ? (
                          <td className={cn(tdClassName, 'font-mono-ui text-xs')}>
                            {pack.id}
                          </td>
                        ) : null}
                        {show('name') ? (
                          <td className={tdClassName}>{pack.name}</td>
                        ) : null}
                        {show('kind') ? (
                          <td className={tdClassName}>{pack.kind}</td>
                        ) : null}
                        {show('version') ? (
                          <td className={cn(tdClassName, 'font-mono-ui text-xs')}>
                            {pack.cached_version ?? '—'}
                          </td>
                        ) : null}
                        {show('official') ? (
                          <td className={tdClassName}>
                            {boolLabel(pack.official)}
                          </td>
                        ) : null}
                        {show('recommended') ? (
                          <td className={tdClassName}>
                            {boolLabel(pack.recommended)}
                          </td>
                        ) : null}
                        {show('published') ? (
                          <td className={tdClassName}>
                            <span
                              className={cn(
                                pack.published
                                  ? 'text-forja-green'
                                  : 'text-forja-muted',
                              )}
                            >
                              {boolLabel(pack.published)}
                            </span>
                          </td>
                        ) : null}
                        {show('validated') ? (
                          <td className={tdClassName}>
                            <div className="flex items-center gap-1.5">
                              {validation?.ok === true ? (
                                <CheckCircle2 className="size-3.5 text-forja-green" />
                              ) : validation?.ok === false ? (
                                <XCircle className="size-3.5 text-red-400" />
                              ) : null}
                              <span className="text-xs text-forja-muted">
                                {pack.last_validated_at
                                  ? formatAdminDateTime(pack.last_validated_at)
                                  : '—'}
                              </span>
                            </div>
                          </td>
                        ) : null}
                        {show('actions') ? (
                          <td className={tdClassName}>
                            <div className="flex flex-wrap gap-1">
                              <Button
                                type="button"
                                size="sm"
                                variant="ghost"
                                disabled={busyId === pack.id || bulkBusy}
                                onClick={() => void runValidate(pack)}
                              >
                                <RefreshCw
                                  className={cn(
                                    'size-3.5',
                                    busyId === pack.id && 'animate-spin',
                                  )}
                                />
                              </Button>
                              <Button
                                type="button"
                                size="sm"
                                variant="ghost"
                                onClick={() => setEditPack(pack)}
                              >
                                Edit
                              </Button>
                              <Button
                                type="button"
                                size="sm"
                                variant="ghost"
                                onClick={() =>
                                  void updatePluginPack(pack.id, {
                                    published: !pack.published,
                                  }).then(() =>
                                    qc.invalidateQueries({
                                      queryKey: ['admin', 'plugin_packs'],
                                    }),
                                  )
                                }
                              >
                                {pack.published ? 'Unpub' : 'Publish'}
                              </Button>
                              <a
                                href={pack.manifest_url}
                                target="_blank"
                                rel="noreferrer"
                                className="inline-flex items-center rounded-md px-2 py-1 text-forja-muted hover:text-forja-text"
                              >
                                <ExternalLink className="size-3.5" />
                              </a>
                              <Button
                                type="button"
                                size="sm"
                                variant="ghost"
                                className="text-red-400"
                                onClick={() => {
                                  if (
                                    !confirm(
                                      `Delete pack ${pack.id}? Bundles that include it will block delete.`,
                                    )
                                  ) {
                                    return
                                  }
                                  deleteMut.mutate(pack.id)
                                }}
                              >
                                <Trash2 className="size-3.5" />
                              </Button>
                            </div>
                          </td>
                        ) : null}
                      </tr>
                    )
                  })
                )}
              </tbody>
            </table>
          </div>
          <TablePagination
            page={page.page}
            pageSize={page.pageSize}
            total={page.total}
            onPageChange={page.setPage}
            onPageSizeChange={page.setPageSize}
          />
        </>
      ) : (
        <BundlesPanel
          packs={packs}
          bundles={bundles}
          loading={bundlesQuery.isLoading}
          onCreate={() => setBundleCreate(true)}
          onEdit={(b) => setBundleEdit(b)}
          onTogglePublish={async (b) => {
            await updatePluginBundle(b.id, { published: !b.published })
            await qc.invalidateQueries({ queryKey: ['admin', 'plugin_bundles'] })
          }}
          onDelete={async (id) => {
            if (!confirm(`Delete bundle ${id}?`)) return
            await deletePluginBundle(id)
            await qc.invalidateQueries({ queryKey: ['admin', 'plugin_bundles'] })
          }}
        />
      )}

      {registerOpen ? (
        <RegisterPackDialog
          onClose={() => setRegisterOpen(false)}
          onSaved={async () => {
            setRegisterOpen(false)
            await qc.invalidateQueries({ queryKey: ['admin', 'plugin_packs'] })
          }}
        />
      ) : null}

      {editPack ? (
        <EditPackDialog
          pack={editPack}
          onClose={() => setEditPack(null)}
          onSaved={async () => {
            setEditPack(null)
            await qc.invalidateQueries({ queryKey: ['admin', 'plugin_packs'] })
          }}
        />
      ) : null}

      {bundleCreate || bundleEdit ? (
        <BundleDialog
          packs={packs}
          initial={bundleEdit}
          onClose={() => {
            setBundleCreate(false)
            setBundleEdit(null)
          }}
          onSaved={async () => {
            setBundleCreate(false)
            setBundleEdit(null)
            await qc.invalidateQueries({ queryKey: ['admin', 'plugin_bundles'] })
          }}
        />
      ) : null}
    </div>
  )
}

function BundlesPanel({
  packs,
  bundles,
  loading,
  onCreate,
  onEdit,
  onTogglePublish,
  onDelete,
}: {
  packs: PluginPack[]
  bundles: PluginBundleWithItems[]
  loading: boolean
  onCreate: () => void
  onEdit: (b: PluginBundleWithItems) => void
  onTogglePublish: (b: PluginBundleWithItems) => Promise<void>
  onDelete: (id: string) => Promise<void>
}) {
  const packName = (id: string) =>
    packs.find((p) => p.id === id)?.name ?? id

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <Button type="button" size="sm" onClick={onCreate}>
          <Plus className="size-3.5" />
          New bundle
        </Button>
      </div>
      <div className="overflow-x-auto rounded-xl border border-forja-border">
        <table className={tableClassName}>
          <thead>
            <tr>
              <th className={thClassName}>ID</th>
              <th className={thClassName}>Name</th>
              <th className={thClassName}>Packs</th>
              <th className={thClassName}>Rec</th>
              <th className={thClassName}>Published</th>
              <th className={thClassName}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td className={tdClassName} colSpan={6}>
                  Loading…
                </td>
              </tr>
            ) : bundles.length === 0 ? (
              <tr>
                <td className={tdClassName} colSpan={6}>
                  No bundles yet.
                </td>
              </tr>
            ) : (
              bundles.map((b) => (
                <tr key={b.id} className="border-t border-forja-border/60">
                  <td className={cn(tdClassName, 'font-mono-ui text-xs')}>
                    {b.id}
                  </td>
                  <td className={tdClassName}>
                    <div>{b.name}</div>
                    {b.description ? (
                      <p className="mt-0.5 text-xs text-forja-muted">
                        {b.description}
                      </p>
                    ) : null}
                  </td>
                  <td className={tdClassName}>
                    <ol className="list-decimal space-y-0.5 pl-4 text-xs">
                      {[...b.items]
                        .sort((a, c) => a.sort_order - c.sort_order)
                        .map((item) => (
                          <li key={item.pack_id}>
                            {packName(item.pack_id)}{' '}
                            <span className="font-mono-ui text-forja-muted">
                              ({item.pack_id})
                            </span>
                          </li>
                        ))}
                    </ol>
                  </td>
                  <td className={tdClassName}>{boolLabel(b.recommended)}</td>
                  <td className={tdClassName}>
                    <span
                      className={cn(
                        b.published ? 'text-forja-green' : 'text-forja-muted',
                      )}
                    >
                      {boolLabel(b.published)}
                    </span>
                  </td>
                  <td className={tdClassName}>
                    <div className="flex flex-wrap gap-1">
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        onClick={() => onEdit(b)}
                      >
                        Edit
                      </Button>
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        onClick={() => void onTogglePublish(b)}
                      >
                        {b.published ? 'Unpub' : 'Publish'}
                      </Button>
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        className="text-red-400"
                        onClick={() => void onDelete(b.id)}
                      >
                        <Trash2 className="size-3.5" />
                      </Button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function DialogShell({
  title,
  children,
  onClose,
}: {
  title: string
  children: ReactNode
  onClose: () => void
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-2xl border border-forja-border bg-forja-bg p-5 shadow-xl">
        <div className="mb-4 flex items-start justify-between gap-3">
          <h2 className="font-disp text-lg font-bold">{title}</h2>
          <Button type="button" size="sm" variant="ghost" onClick={onClose}>
            Close
          </Button>
        </div>
        {children}
      </div>
    </div>
  )
}

function RegisterPackDialog({
  onClose,
  onSaved,
}: {
  onClose: () => void
  onSaved: () => Promise<void>
}) {
  const [url, setUrl] = useState('')
  const [id, setId] = useState('')
  const [name, setName] = useState('')
  const [kind, setKind] = useState('hubs')
  const [description, setDescription] = useState('')
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  async function peek() {
    setBusy(true)
    setErr(null)
    try {
      const raw = await fetchManifest(url.trim())
      const parsed = validateManifestJson(raw)
      if (parsed.packId) setId(parsed.packId)
      else if (!id) setId(slugifyId(parsed.name ?? 'pack'))
      if (parsed.name) setName(parsed.name)
      if (!parsed.ok) {
        setErr(parsed.errors.join('; '))
      }
    } catch (e) {
      setErr(errMessage(e))
    } finally {
      setBusy(false)
    }
  }

  async function save() {
    setBusy(true)
    setErr(null)
    try {
      const packId = slugifyId(id)
      if (!packId) throw new Error('id required')
      if (!url.trim()) throw new Error('manifest URL required')
      await upsertPluginPack({
        id: packId,
        manifest_url: url.trim(),
        name: name.trim() || packId,
        kind: kind.trim() || 'providers',
        description: description.trim(),
        official: false,
        recommended: false,
        published: false,
        sort_order: 999,
        tags: [],
        accent: 'brand',
      })
      const result = await validatePackAtUrl(url.trim())
      await persistValidation(packId, result)
      await onSaved()
    } catch (e) {
      setErr(errMessage(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <DialogShell title="Register pack" onClose={onClose}>
      <div className="space-y-3">
        <div className="space-y-1">
          <Label>GitHub manifest URL</Label>
          <Input
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            placeholder="https://raw.githubusercontent.com/…/manifest.json"
          />
        </div>
        <Button
          type="button"
          size="sm"
          variant="outline"
          disabled={busy || !url.trim()}
          onClick={() => void peek()}
        >
          Fetch preview
        </Button>
        <div className="space-y-1">
          <Label>ID</Label>
          <Input value={id} onChange={(e) => setId(e.target.value)} />
        </div>
        <div className="space-y-1">
          <Label>Name</Label>
          <Input value={name} onChange={(e) => setName(e.target.value)} />
        </div>
        <div className="space-y-1">
          <Label>Kind</Label>
          <Input value={kind} onChange={(e) => setKind(e.target.value)} />
        </div>
        <div className="space-y-1">
          <Label>Description</Label>
          <Input
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </div>
        {err ? <p className="text-sm text-red-300">{err}</p> : null}
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            type="button"
            disabled={busy}
            onClick={() => void save()}
          >
            Save draft
          </Button>
        </div>
      </div>
    </DialogShell>
  )
}

function EditPackDialog({
  pack,
  onClose,
  onSaved,
}: {
  pack: PluginPack
  onClose: () => void
  onSaved: () => Promise<void>
}) {
  const [name, setName] = useState(pack.name)
  const [kind, setKind] = useState(pack.kind)
  const [description, setDescription] = useState(pack.description)
  const [manifestUrl, setManifestUrl] = useState(pack.manifest_url)
  const [tags, setTags] = useState((pack.tags ?? []).join(', '))
  const [sortOrder, setSortOrder] = useState(String(pack.sort_order))
  const [official, setOfficial] = useState(pack.official)
  const [recommended, setRecommended] = useState(pack.recommended)
  const [published, setPublished] = useState(pack.published)
  const [accent, setAccent] = useState(pack.accent)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  async function save() {
    setBusy(true)
    setErr(null)
    try {
      await updatePluginPack(pack.id, {
        name: name.trim(),
        kind: kind.trim(),
        description: description.trim(),
        manifest_url: manifestUrl.trim(),
        tags: tags
          .split(',')
          .map((t) => t.trim())
          .filter(Boolean),
        sort_order: Number.parseInt(sortOrder, 10) || 0,
        official,
        recommended,
        published,
        accent: accent === 'flame' ? 'flame' : 'brand',
      })
      await onSaved()
    } catch (e) {
      setErr(errMessage(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <DialogShell title={`Edit ${pack.id}`} onClose={onClose}>
      <div className="space-y-3">
        <div className="space-y-1">
          <Label>Name</Label>
          <Input value={name} onChange={(e) => setName(e.target.value)} />
        </div>
        <div className="space-y-1">
          <Label>Kind</Label>
          <Input value={kind} onChange={(e) => setKind(e.target.value)} />
        </div>
        <div className="space-y-1">
          <Label>Description</Label>
          <Input
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </div>
        <div className="space-y-1">
          <Label>Manifest URL</Label>
          <Input
            value={manifestUrl}
            onChange={(e) => setManifestUrl(e.target.value)}
          />
        </div>
        <div className="space-y-1">
          <Label>Tags (comma)</Label>
          <Input value={tags} onChange={(e) => setTags(e.target.value)} />
        </div>
        <div className="space-y-1">
          <Label>Sort order</Label>
          <Input
            value={sortOrder}
            onChange={(e) => setSortOrder(e.target.value)}
          />
        </div>
        <div className="space-y-1">
          <Label>Accent</Label>
          <Select value={accent} onValueChange={setAccent}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="brand">brand</SelectItem>
              <SelectItem value="flame">flame</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={official}
            onChange={(e) => setOfficial(e.target.checked)}
          />
          Official
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={recommended}
            onChange={(e) => setRecommended(e.target.checked)}
          />
          Recommended
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={published}
            onChange={(e) => setPublished(e.target.checked)}
          />
          Published
        </label>
        {err ? <p className="text-sm text-red-300">{err}</p> : null}
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button type="button" disabled={busy} onClick={() => void save()}>
            Save
          </Button>
        </div>
      </div>
    </DialogShell>
  )
}

function BundleDialog({
  packs,
  initial,
  onClose,
  onSaved,
}: {
  packs: PluginPack[]
  initial: PluginBundleWithItems | null
  onClose: () => void
  onSaved: () => Promise<void>
}) {
  const [id, setId] = useState(initial?.id ?? '')
  const [name, setName] = useState(initial?.name ?? '')
  const [description, setDescription] = useState(initial?.description ?? '')
  const [recommended, setRecommended] = useState(initial?.recommended ?? false)
  const [published, setPublished] = useState(initial?.published ?? false)
  const [sortOrder, setSortOrder] = useState(String(initial?.sort_order ?? 10))
  const [selected, setSelected] = useState<string[]>(() =>
    [...(initial?.items ?? [])]
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((i) => i.pack_id),
  )
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  function togglePack(packId: string) {
    setSelected((prev) =>
      prev.includes(packId)
        ? prev.filter((p) => p !== packId)
        : [...prev, packId],
    )
  }

  function move(packId: string, dir: -1 | 1) {
    setSelected((prev) => {
      const i = prev.indexOf(packId)
      if (i < 0) return prev
      const j = i + dir
      if (j < 0 || j >= prev.length) return prev
      const next = [...prev]
      ;[next[i], next[j]] = [next[j], next[i]]
      return next
    })
  }

  async function save() {
    setBusy(true)
    setErr(null)
    try {
      const bundleId = slugifyId(id)
      if (!bundleId) throw new Error('id required')
      if (!name.trim()) throw new Error('name required')
      await upsertPluginBundle(
        {
          id: bundleId,
          name: name.trim(),
          description: description.trim(),
          recommended,
          published,
          sort_order: Number.parseInt(sortOrder, 10) || 0,
        },
        selected,
      )
      await onSaved()
    } catch (e) {
      setErr(errMessage(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <DialogShell
      title={initial ? `Edit bundle ${initial.id}` : 'New bundle'}
      onClose={onClose}
    >
      <div className="space-y-3">
        <div className="space-y-1">
          <Label>ID</Label>
          <Input
            value={id}
            disabled={!!initial}
            onChange={(e) => setId(e.target.value)}
          />
        </div>
        <div className="space-y-1">
          <Label>Name</Label>
          <Input value={name} onChange={(e) => setName(e.target.value)} />
        </div>
        <div className="space-y-1">
          <Label>Description</Label>
          <Input
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </div>
        <div className="space-y-1">
          <Label>Sort order</Label>
          <Input
            value={sortOrder}
            onChange={(e) => setSortOrder(e.target.value)}
          />
        </div>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={recommended}
            onChange={(e) => setRecommended(e.target.checked)}
          />
          Recommended
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={published}
            onChange={(e) => setPublished(e.target.checked)}
          />
          Published
        </label>
        <div className="space-y-2">
          <Label>Packs (order = install order)</Label>
          <div className="max-h-56 space-y-1 overflow-y-auto rounded-lg border border-forja-border p-2">
            {packs.map((p) => {
              const on = selected.includes(p.id)
              const idx = selected.indexOf(p.id)
              return (
                <div
                  key={p.id}
                  className="flex items-center gap-2 text-sm"
                >
                  <input
                    type="checkbox"
                    checked={on}
                    onChange={() => togglePack(p.id)}
                  />
                  <span className="min-w-0 flex-1 truncate">
                    {p.name}{' '}
                    <span className="font-mono-ui text-xs text-forja-muted">
                      {p.id}
                    </span>
                  </span>
                  {on ? (
                    <span className="flex gap-1">
                      <button
                        type="button"
                        className="text-xs text-forja-muted"
                        onClick={() => move(p.id, -1)}
                      >
                        ↑
                      </button>
                      <button
                        type="button"
                        className="text-xs text-forja-muted"
                        onClick={() => move(p.id, 1)}
                      >
                        ↓
                      </button>
                      <span className="font-mono-ui text-xs text-forja-muted">
                        #{idx + 1}
                      </span>
                    </span>
                  ) : null}
                </div>
              )
            })}
          </div>
        </div>
        {err ? <p className="text-sm text-red-300">{err}</p> : null}
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button type="button" disabled={busy} onClick={() => void save()}>
            Save
          </Button>
        </div>
      </div>
    </DialogShell>
  )
}
