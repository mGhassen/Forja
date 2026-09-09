import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Minus, Plus, Trash2, X } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { ConfirmDialog } from '@/components/confirm-dialog'
import {
  IptvPortalPeopleDialog,
} from '@/components/iptv-assign-dialog'
import {
  IptvPortalActionRow,
  IptvPortalEditDialog,
  decryptPortalPassword,
  errMessage,
  iptvPortalGridClassName,
  type IptvPortalEditForm,
} from '@/components/iptv-portal-row'
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
import {
  tableClassName,
  tdClassName,
  thClassName,
} from '@/components/admin-ui'
import {
  enabledFeatureDefs,
  parseAccountFeatures,
  parseMaxIptvPortals,
} from '@/lib/account-features'
import {
  addPackToProfile,
  listAccountProfiles,
  fetchProfilePacks,
  packVersionStatus,
  removePackFromProfile,
  resolveLatestPackVersions,
} from '@/lib/account-packs'
import { adminDb } from '@/lib/admin-db'
import { catalogVerify } from '@/lib/catalog-verify'
import {
  fetchAssignmentsForAccount,
  type AssignmentRow,
  unassignPortal,
} from '@/lib/iptv-portal-assign'
import {
  createPortalShare,
  formatShareCode,
} from '@/lib/iptv-portal-share'
import {
  formatClientLabel,
  formatRelativeSeen,
  type PosthogPersonRuntime,
} from '@/lib/posthog-persons'
import { cn } from '@/lib/utils'

export type AccountDetailRow = {
  id: string
  member_number: number
  email: string | null
  is_admin: boolean
  iptv_credits: number
  features: Record<string, unknown> | null
}

type TabId = 'overview' | 'portals' | 'plugins'

const TABS: { id: TabId; label: string }[] = [
  { id: 'overview', label: 'Overview' },
  { id: 'portals', label: 'Portals IPTV' },
  { id: 'plugins', label: 'Plugins' },
]

function AccountPortalsPanel({
  accountId,
  onAssign,
}: {
  accountId: string
  onAssign: () => void
}) {
  const qc = useQueryClient()
  const [editingId, setEditingId] = useState<string | null>(null)
  const [form, setForm] = useState<IptvPortalEditForm>({
    url: '',
    username: '',
    password: '',
    region_primary: 'UNKNOWN',
  })
  const [editError, setEditError] = useState<string | null>(null)
  const [shareFlash, setShareFlash] = useState<Record<string, string>>({})
  const [sharingId, setSharingId] = useState<string | null>(null)
  const [checkingId, setCheckingId] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const [peopleFor, setPeopleFor] = useState<{
    id: string
    label: string
  } | null>(null)

  const list = useQuery({
    queryKey: ['admin', 'account_portals', accountId],
    queryFn: () => fetchAssignmentsForAccount(accountId),
  })

  const remove = useMutation({
    mutationFn: (assignmentId: string) => unassignPortal(assignmentId),
    onSuccess: async () => {
      await qc.invalidateQueries({
        queryKey: ['admin', 'account_portals', accountId],
      })
      await qc.invalidateQueries({ queryKey: ['admin', 'account_portal_counts'] })
      await qc.invalidateQueries({ queryKey: ['admin', 'portal_assignees'] })
    },
  })

  const saveEdit = useMutation({
    mutationFn: async () => {
      if (!editingId) return
      const patch: Record<string, string> = {
        url: form.url.trim(),
        username: form.username.trim(),
        region_primary: form.region_primary.trim() || 'UNKNOWN',
      }
      if (form.password.trim()) patch.password = form.password
      const { error } = await adminDb
        .from('iptv_portals')
        .update(patch)
        .eq('id', editingId)
      if (error) throw error
    },
    onSuccess: async () => {
      setEditingId(null)
      setEditError(null)
      setActionError(null)
      await qc.invalidateQueries({
        queryKey: ['admin', 'account_portals', accountId],
      })
      await qc.invalidateQueries({ queryKey: ['admin', 'pool'] })
    },
    onError: (e) => {
      setEditError(e instanceof Error ? e.message : 'Save failed')
    },
  })

  async function beginEdit(a: AssignmentRow) {
    const id = a.portal_id
    setEditError(null)
    setActionError(null)
    setEditingId(id)
    setForm({
      url: a.url,
      username: a.username,
      password: '',
      region_primary: a.region_primary,
    })
    try {
      const pw = await decryptPortalPassword(id)
      setEditingId((cur) => {
        if (cur === id) setForm((f) => ({ ...f, password: pw }))
        return cur
      })
    } catch (e) {
      setEditError(errMessage(e, 'Could not decrypt password'))
    }
  }

  async function copyShare(a: AssignmentRow) {
    setSharingId(a.portal_id)
    setActionError(null)
    try {
      const password = await decryptPortalPassword(a.portal_id)
      const code = await createPortalShare({
        url: a.url,
        username: a.username,
        password,
        platform: a.platform,
      })
      const formatted = formatShareCode(code)
      try {
        await navigator.clipboard.writeText(formatted)
      } catch {
        // still show code if clipboard denied
      }
      setShareFlash((prev) => ({ ...prev, [a.portal_id]: formatted }))
      window.setTimeout(() => {
        setShareFlash((prev) => {
          const next = { ...prev }
          delete next[a.portal_id]
          return next
        })
      }, 8000)
    } catch (e) {
      setActionError(errMessage(e, 'Could not create share code'))
    } finally {
      setSharingId(null)
    }
  }

  async function checkPortal(a: AssignmentRow) {
    setCheckingId(a.portal_id)
    setActionError(null)
    try {
      await catalogVerify({ candidateId: a.portal_id })
      await qc.invalidateQueries({
        queryKey: ['admin', 'account_portals', accountId],
      })
      await qc.invalidateQueries({ queryKey: ['admin', 'pool'] })
    } catch (e) {
      setActionError(errMessage(e, 'Status check failed'))
    } finally {
      setCheckingId(null)
    }
  }

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-forja-muted">
          Portals ({list.data?.length ?? 0})
        </p>
        <Button type="button" variant="secondary" size="sm" onClick={onAssign}>
          <Plus className="size-3.5" />
          Assign portal
        </Button>
      </div>
      {list.error ? (
        <p className="text-sm text-red-400">{(list.error as Error).message}</p>
      ) : null}
      {remove.error ? (
        <p className="text-sm text-red-400">{remove.error.message}</p>
      ) : null}
      {actionError ? (
        <p className="text-sm text-red-400">{actionError}</p>
      ) : null}
      {list.isLoading ? (
        <p className="text-sm text-forja-muted">Loading…</p>
      ) : (list.data?.length ?? 0) === 0 ? (
        <p className="text-sm text-forja-muted">No portals on this account.</p>
      ) : (
        <ul className={iptvPortalGridClassName}>
          {(list.data ?? []).map((a) => (
            <IptvPortalActionRow
              key={a.id}
              portal={a}
              badge={
                <span className="shrink-0 truncate rounded bg-white/8 px-1.5 py-0.5 text-[10px] font-semibold text-forja-muted">
                  {a.profile_name}
                </span>
              }
              sharing={sharingId === a.portal_id}
              shareCode={shareFlash[a.portal_id] ?? null}
              deleting={remove.isPending}
              checking={checkingId === a.portal_id}
              deleteConfirmLabel="Unassign portal from this account?"
              deleteTitle="Unassign portal"
              onShare={() => void copyShare(a)}
              onEdit={() => void beginEdit(a)}
              onDelete={() => remove.mutate(a.id)}
              onCheck={() => void checkPortal(a)}
              onPeople={() =>
                setPeopleFor({
                  id: a.portal_id,
                  label: `${a.username} · ${a.url}`,
                })
              }
            />
          ))}
        </ul>
      )}

      {editingId ? (
        <IptvPortalEditDialog
          form={form}
          setForm={setForm}
          saving={saveEdit.isPending}
          error={editError}
          onClose={() => {
            setEditingId(null)
            setEditError(null)
          }}
          onSave={() => saveEdit.mutate()}
        />
      ) : null}

      {peopleFor ? (
        <IptvPortalPeopleDialog
          portalId={peopleFor.id}
          portalLabel={peopleFor.label}
          onClose={() => setPeopleFor(null)}
        />
      ) : null}
    </div>
  )
}

function AccountOverviewPanel({
  account,
  runtime,
  runtimeLoading,
  creditsBusy,
  onAdjustCredits,
  onEditFeatures,
}: {
  account: AccountDetailRow
  runtime: PosthogPersonRuntime | undefined
  runtimeLoading: boolean
  creditsBusy: boolean
  onAdjustCredits: (delta: number) => void
  onEditFeatures: () => void
}) {
  const feats = parseAccountFeatures(account.features)
  const enabled = enabledFeatureDefs(feats)
  const credits = account.iptv_credits ?? 0
  const maxPortals = parseMaxIptvPortals(account.features)
  const clientLabel = formatClientLabel(runtime)
  const seenLabel = formatRelativeSeen(runtime?.lastSeenAt)

  return (
    <div className="space-y-5">
      <dl className="grid gap-3 sm:grid-cols-2">
        <div>
          <dt className="text-[11px] font-semibold uppercase tracking-wide text-forja-muted">
            Member #
          </dt>
          <dd className="mt-0.5 font-mono tabular-nums text-forja-text">
            {account.member_number}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] font-semibold uppercase tracking-wide text-forja-muted">
            Email
          </dt>
          <dd className="mt-0.5 break-all text-sm text-forja-text">
            {account.email ?? '—'}
            {account.is_admin ? (
              <span className="ml-2 inline-flex rounded-full bg-amber-400/15 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-300">
                admin
              </span>
            ) : null}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] font-semibold uppercase tracking-wide text-forja-muted">
            App
          </dt>
          <dd className="mt-0.5 font-mono text-sm tabular-nums">
            {runtimeLoading && !runtime ? '…' : (runtime?.appVersion ?? '—')}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] font-semibold uppercase tracking-wide text-forja-muted">
            Client
          </dt>
          <dd className="mt-0.5 text-sm">
            {runtimeLoading && !runtime ? '…' : clientLabel}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] font-semibold uppercase tracking-wide text-forja-muted">
            Last seen
          </dt>
          <dd
            className="mt-0.5 text-sm tabular-nums text-forja-muted"
            title={runtime?.lastSeenAt ?? undefined}
          >
            {runtimeLoading && !runtime ? '…' : seenLabel}
          </dd>
        </div>
        {runtime?.osVersion ? (
          <div>
            <dt className="text-[11px] font-semibold uppercase tracking-wide text-forja-muted">
              OS
            </dt>
            <dd className="mt-0.5 text-sm text-forja-muted">
              {runtime.osVersion}
            </dd>
          </div>
        ) : null}
      </dl>

      <div>
        <p className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-forja-muted">
          Credits
        </p>
        <div className="inline-flex items-center gap-1.5">
          <button
            type="button"
            disabled={creditsBusy || credits <= 0}
            aria-label="Revoke 1 credit"
            title="−1"
            onClick={() => onAdjustCredits(-1)}
            className="inline-flex size-7 items-center justify-center rounded-md border border-forja-border text-forja-muted transition-colors hover:bg-white/5 hover:text-forja-text disabled:pointer-events-none disabled:opacity-40"
          >
            <Minus className="size-3.5" />
          </button>
          <span className="min-w-8 text-center font-disp text-base tabular-nums">
            {credits}
          </span>
          <button
            type="button"
            disabled={creditsBusy}
            aria-label="Grant 5 credits"
            title="+5"
            onClick={() => onAdjustCredits(5)}
            className="inline-flex size-7 items-center justify-center rounded-md border border-forja-border text-forja-muted transition-colors hover:border-forja-green/40 hover:bg-forja-green/10 hover:text-forja-green disabled:pointer-events-none disabled:opacity-40"
          >
            <Plus className="size-3.5" />
          </button>
        </div>
      </div>

      <div>
        <p className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-forja-muted">
          Features
        </p>
        <button
          type="button"
          onClick={onEditFeatures}
          className="inline-flex max-w-full flex-wrap items-center gap-1 rounded-md border border-forja-border px-2 py-1.5 text-left transition-colors hover:border-forja-green/40 hover:bg-forja-green/5"
          title="Edit feature flags"
        >
          <span className="rounded bg-white/8 px-1.5 py-0.5 text-[10px] font-semibold text-forja-muted">
            {account.is_admin ? '∞ portals' : `Max ${maxPortals}`}
          </span>
          {enabled.length === 0 ? (
            <span className="text-xs text-forja-muted">Edit</span>
          ) : (
            enabled.map((d) => (
              <span
                key={d.key}
                className="rounded bg-forja-green/15 px-1.5 py-0.5 text-[10px] font-semibold text-forja-green"
              >
                {d.shortLabel}
              </span>
            ))
          )}
        </button>
      </div>
    </div>
  )
}

function AccountPluginsPanel({
  accountId,
}: {
  accountId: string
}) {
  const qc = useQueryClient()
  const [profileId, setProfileId] = useState<string>('')
  const [manifestUrl, setManifestUrl] = useState('')
  const [addError, setAddError] = useState<string | null>(null)
  const [removeUrl, setRemoveUrl] = useState<string | null>(null)

  const profiles = useQuery({
    queryKey: ['admin', 'account_profiles', accountId],
    queryFn: () => listAccountProfiles(accountId),
  })

  useEffect(() => {
    const rows = profiles.data ?? []
    if (!rows.length) {
      setProfileId('')
      return
    }
    setProfileId((cur) =>
      cur && rows.some((p) => p.id === cur) ? cur : rows[0]!.id,
    )
  }, [profiles.data])

  const packs = useQuery({
    queryKey: ['admin', 'account_packs', accountId, profileId],
    queryFn: () => fetchProfilePacks(accountId, profileId),
    enabled: Boolean(profileId),
  })

  const packUrls = useMemo(
    () => (packs.data?.packs ?? []).map((p) => p.manifestUrl.trim()),
    [packs.data?.packs],
  )

  const latestVersions = useQuery({
    queryKey: ['admin', 'pack_latest_versions', packUrls],
    queryFn: () => resolveLatestPackVersions(packUrls),
    enabled: packUrls.length > 0,
    staleTime: 60_000,
  })

  const add = useMutation({
    mutationFn: () =>
      addPackToProfile({
        accountId,
        profileId,
        manifestUrl,
      }),
    onSuccess: async () => {
      setManifestUrl('')
      setAddError(null)
      await qc.invalidateQueries({
        queryKey: ['admin', 'account_packs', accountId, profileId],
      })
    },
    onError: (e) => {
      setAddError(e instanceof Error ? e.message : 'Add failed')
    },
  })

  const remove = useMutation({
    mutationFn: (url: string) =>
      removePackFromProfile({
        accountId,
        profileId,
        manifestUrl: url,
      }),
    onSuccess: async () => {
      setRemoveUrl(null)
      await qc.invalidateQueries({
        queryKey: ['admin', 'account_packs', accountId, profileId],
      })
    },
  })

  return (
    <div className="space-y-4">
      <div className="space-y-1.5">
        <Label htmlFor="account-plugin-profile">Profile</Label>
        <Select
          value={profileId || undefined}
          onValueChange={setProfileId}
          disabled={profiles.isLoading || (profiles.data?.length ?? 0) === 0}
        >
          <SelectTrigger id="account-plugin-profile">
            <SelectValue placeholder="Select profile…" />
          </SelectTrigger>
          <SelectContent>
            {(profiles.data ?? []).map((p) => (
              <SelectItem key={p.id} value={p.id}>
                {p.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {profiles.error ? (
        <p className="text-sm text-red-400">
          {(profiles.error as Error).message}
        </p>
      ) : null}
      {!profiles.isLoading && (profiles.data?.length ?? 0) === 0 ? (
        <p className="text-sm text-forja-muted">No profiles on this account.</p>
      ) : null}

      {profileId ? (
        <>
          <div className="flex flex-wrap items-end gap-2">
            <div className="min-w-0 flex-1 space-y-1.5">
              <Label htmlFor="account-plugin-url">Add pack</Label>
              <Input
                id="account-plugin-url"
                placeholder="https://…/manifest.json"
                value={manifestUrl}
                onChange={(e) => setManifestUrl(e.target.value)}
                disabled={add.isPending}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault()
                    if (manifestUrl.trim()) add.mutate()
                  }
                }}
              />
            </div>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={!manifestUrl.trim() || add.isPending}
              onClick={() => add.mutate()}
            >
              <Plus className="size-3.5" />
              {add.isPending ? 'Adding…' : 'Add'}
            </Button>
          </div>
          {addError ? (
            <p className="text-sm text-red-400">{addError}</p>
          ) : null}
          {remove.error ? (
            <p className="text-sm text-red-400">{remove.error.message}</p>
          ) : null}

          {packs.isLoading ? (
            <p className="text-sm text-forja-muted">Loading packs…</p>
          ) : packs.error ? (
            <p className="text-sm text-red-400">
              {(packs.error as Error).message}
            </p>
          ) : (packs.data?.packs.length ?? 0) === 0 ? (
            <p className="text-sm text-forja-muted">
              No packs on this profile.
            </p>
          ) : (
            <div className="overflow-x-auto rounded-md border border-forja-border/80">
              <table className={tableClassName}>
                <thead>
                  <tr>
                    <th className={thClassName}>Name</th>
                    <th className={cn(thClassName, 'w-24')}>Version</th>
                    <th className={thClassName}>Manifest</th>
                    <th className={cn(thClassName, 'w-12')} />
                  </tr>
                </thead>
                <tbody>
                  {(packs.data?.packs ?? []).map((p) => {
                    const installed = p.version?.trim() || ''
                    const latest =
                      latestVersions.data?.[p.manifestUrl.trim()]?.trim() || ''
                    const status = packVersionStatus(installed, latest)
                    const versionClass =
                      status === 'current'
                        ? 'text-forja-green'
                        : status === 'outdated'
                          ? 'text-amber-300'
                          : 'text-forja-muted'
                    const versionTitle =
                      status === 'outdated' && latest
                        ? `Installed ${installed} · latest ${latest}`
                        : status === 'current' && latest
                          ? `Up to date (${installed})`
                          : latest
                            ? `Latest known ${latest}`
                            : undefined
                    return (
                      <tr
                        key={p.manifestUrl}
                        className="border-t border-forja-border/80"
                      >
                        <td className={tdClassName}>
                          <span className="font-medium">
                            {p.name?.trim() || 'Pack'}
                          </span>
                        </td>
                        <td
                          className={cn(
                            tdClassName,
                            'font-mono text-xs tabular-nums',
                            versionClass,
                          )}
                          title={versionTitle}
                        >
                          {installed || '—'}
                          {status === 'outdated' && latest ? (
                            <span className="mt-0.5 block text-[10px] text-forja-muted">
                              → {latest}
                            </span>
                          ) : null}
                        </td>
                        <td className={tdClassName}>
                          <span
                            className="block max-w-55 truncate font-mono text-[11px] text-forja-muted"
                            title={p.manifestUrl}
                          >
                            {p.manifestUrl}
                          </span>
                        </td>
                        <td className={tdClassName}>
                          <Button
                            type="button"
                            variant="ghost"
                            size="sm"
                            className="size-7 p-0 text-red-300 hover:text-red-200"
                            aria-label={`Remove ${p.name ?? p.manifestUrl}`}
                            disabled={remove.isPending}
                            onClick={() => setRemoveUrl(p.manifestUrl)}
                          >
                            <Trash2 className="size-3.5" />
                          </Button>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          )}
        </>
      ) : null}

      <ConfirmDialog
        open={Boolean(removeUrl)}
        title="Remove pack"
        description="Remove this pack from the profile cloud settings? Devices will drop it on next sync."
        confirmLabel="Remove"
        danger
        busy={remove.isPending}
        onConfirm={() => {
          if (removeUrl) remove.mutate(removeUrl)
        }}
        onClose={() => {
          if (!remove.isPending) setRemoveUrl(null)
        }}
      />
    </div>
  )
}

export function AccountDetailPanel({
  account,
  runtime,
  runtimeLoading,
  creditsBusy,
  onClose,
  onAdjustCredits,
  onEditFeatures,
  onAssignPortal,
}: {
  account: AccountDetailRow
  runtime: PosthogPersonRuntime | undefined
  runtimeLoading: boolean
  creditsBusy: boolean
  onClose: () => void
  onAdjustCredits: (delta: number) => void
  onEditFeatures: () => void
  onAssignPortal: () => void
}) {
  const [tab, setTab] = useState<TabId>('overview')

  useEffect(() => {
    setTab('overview')
  }, [account.id])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  return (
    <div className="fixed inset-0 z-50 flex justify-end" role="presentation">
      <button
        type="button"
        className="absolute inset-0 bg-black/50"
        aria-label="Close account panel"
        onClick={onClose}
      />
      <aside
        className="relative z-10 flex h-dvh w-full max-w-full flex-col border-l border-forja-border bg-forja-bg shadow-2xl sm:w-1/2"
        aria-label="Account detail"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex shrink-0 items-start gap-2 border-b border-forja-border/80 px-3 py-2.5">
          <div className="min-w-0 flex-1">
            <p className="text-[11px] font-medium uppercase tracking-wide text-forja-muted">
              Account
            </p>
            <p
              className="mt-0.5 truncate text-sm font-medium text-forja-text"
              title={account.email ?? account.id}
            >
              {account.email ?? account.id.slice(0, 8)}
            </p>
            <p className="mt-0.5 font-mono text-[11px] tabular-nums text-forja-muted">
              #{account.member_number}
            </p>
          </div>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="size-7 shrink-0 p-0"
            onClick={onClose}
            aria-label="Close account panel"
          >
            <X className="size-4" />
          </Button>
        </div>

        <div
          className="flex shrink-0 gap-1 border-b border-forja-border/80 px-2 py-1.5"
          role="tablist"
          aria-label="Account sections"
        >
          {TABS.map((t) => (
            <button
              key={t.id}
              type="button"
              role="tab"
              aria-selected={tab === t.id}
              className={cn(
                'rounded-md px-2.5 py-1.5 text-xs font-medium transition-colors',
                tab === t.id
                  ? 'bg-forja-green/15 text-forja-green'
                  : 'text-forja-muted hover:bg-white/5 hover:text-forja-text',
              )}
              onClick={() => setTab(t.id)}
            >
              {t.label}
            </button>
          ))}
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto px-3 py-3">
          {tab === 'overview' ? (
            <AccountOverviewPanel
              account={account}
              runtime={runtime}
              runtimeLoading={runtimeLoading}
              creditsBusy={creditsBusy}
              onAdjustCredits={onAdjustCredits}
              onEditFeatures={onEditFeatures}
            />
          ) : null}
          {tab === 'portals' ? (
            <AccountPortalsPanel
              accountId={account.id}
              onAssign={onAssignPortal}
            />
          ) : null}
          {tab === 'plugins' ? (
            <AccountPluginsPanel accountId={account.id} />
          ) : null}
        </div>
      </aside>
    </div>
  )
}
