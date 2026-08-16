import {
  useEffect,
  useState,
  type Dispatch,
  type ReactNode,
  type SetStateAction,
} from 'react'
import {
  Check,
  Copy,
  Pencil,
  Radio,
  Share2,
  Trash2,
  UserPlus,
  X,
} from 'lucide-react'
import {
  IptvPortalCardBody,
  type IptvPortalCardData,
} from '@/components/iptv-portal-card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { PasswordInput } from '@/components/ui/password-input'
import { adminDb } from '@/lib/admin-db'
import { cn } from '@/lib/utils'

const ACTION_RAIL_W = 180

export type IptvPortalEditForm = {
  url: string
  username: string
  password: string
  region_primary: string
}

export function errMessage(e: unknown, fallback: string): string {
  if (e instanceof Error && e.message) return e.message
  if (typeof e === 'object' && e && 'message' in e) {
    const m = (e as { message: unknown }).message
    if (typeof m === 'string' && m.trim()) return m
  }
  if (typeof e === 'string' && e.trim()) return e
  return fallback
}

export async function decryptPortalPassword(id: string): Promise<string> {
  const { data, error } = await adminDb.rpc(
    'admin_iptv_catalog_candidate_password',
    { p_id: id },
  )
  if (error) {
    const msg = errMessage(error, 'decrypt failed')
    if (/does not exist|could not find.*function/i.test(msg)) {
      throw new Error(
        'Missing RPC admin_iptv_catalog_candidate_password — apply migration 20260719015100_admin_catalog_candidate_ops',
      )
    }
    throw new Error(msg)
  }
  return typeof data === 'string' ? data : ''
}

export function IptvPortalEditDialog({
  form,
  setForm,
  saving,
  error,
  onClose,
  onSave,
}: {
  form: IptvPortalEditForm
  setForm: Dispatch<SetStateAction<IptvPortalEditForm>>
  saving: boolean
  error: string | null
  onClose: () => void
  onSave: () => void
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
      role="presentation"
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="edit-cand-title"
        className="w-full max-w-lg border border-forja-border bg-forja-elevated p-5 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-center justify-between gap-2">
          <h2 id="edit-cand-title" className="text-sm font-semibold">
            Edit portal
          </h2>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="h-8 w-8 p-0"
            aria-label="Close"
            onClick={onClose}
          >
            <X className="size-4" />
          </Button>
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="space-y-2 sm:col-span-2">
            <Label htmlFor="cand-url">Panel URL</Label>
            <Input
              id="cand-url"
              value={form.url}
              onChange={(e) => setForm((f) => ({ ...f, url: e.target.value }))}
              autoFocus
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="cand-user">Username</Label>
            <Input
              id="cand-user"
              value={form.username}
              onChange={(e) =>
                setForm((f) => ({ ...f, username: e.target.value }))
              }
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="cand-pass">Password</Label>
            <PasswordInput
              id="cand-pass"
              value={form.password}
              onChange={(e) =>
                setForm((f) => ({ ...f, password: e.target.value }))
              }
            />
          </div>
          <div className="space-y-2 sm:col-span-2">
            <Label htmlFor="cand-region">Region</Label>
            <Input
              id="cand-region"
              value={form.region_primary}
              onChange={(e) =>
                setForm((f) => ({ ...f, region_primary: e.target.value }))
              }
            />
          </div>
          {error ? (
            <p className="text-sm text-red-400 sm:col-span-2">{error}</p>
          ) : null}
          <div className="flex gap-2 sm:col-span-2">
            <Button
              type="button"
              variant="secondary"
              disabled={
                saving || !form.url.trim() || !form.username.trim()
              }
              onClick={onSave}
            >
              {saving ? 'Saving…' : 'Save portal'}
            </Button>
            <Button type="button" variant="ghost" onClick={onClose}>
              Cancel
            </Button>
          </div>
        </div>
      </div>
    </div>
  )
}

/** Same hover action rail as Pool portal rows. */
export function IptvPortalActionRow({
  portal,
  badge,
  sharing,
  shareCode,
  deleting,
  checking,
  highlighted,
  deleteConfirmLabel,
  deleteDisabled,
  deleteTitle,
  onShare,
  onEdit,
  onDelete,
  onCheck,
  onPeople,
}: {
  portal: IptvPortalCardData
  badge?: ReactNode
  sharing: boolean
  shareCode: string | null
  deleting: boolean
  checking: boolean
  highlighted?: boolean
  deleteConfirmLabel: string
  deleteDisabled?: boolean
  deleteTitle?: string
  onShare: () => void
  onEdit: () => void
  onDelete: () => void
  onCheck: () => void
  onPeople: () => void
}) {
  const [confirmDelete, setConfirmDelete] = useState(false)
  const pinRail = confirmDelete || sharing || !!shareCode || checking
  const rowId = 'id' in portal && typeof portal.id === 'string' ? portal.id : null

  return (
    <li
      id={rowId ? `pool-portal-${rowId}` : undefined}
      className={cn(
        'group flex min-h-22 items-stretch border-b border-forja-border/70 last:border-b-0',
        'hover:bg-white/[0.03] focus-within:bg-white/[0.03]',
        pinRail && 'bg-white/[0.03]',
        highlighted &&
          'bg-forja-green/[0.08] ring-1 ring-inset ring-forja-green/35',
      )}
    >
      <div className="flex min-w-0 flex-1 items-center px-3 py-2.5">
        {confirmDelete ? (
          <p className="text-[13px] font-semibold text-red-400">
            {deleteConfirmLabel}
          </p>
        ) : shareCode || sharing ? (
          <div className="min-w-0">
            {sharing && !shareCode ? (
              <p className="text-sm text-forja-muted">Creating share code…</p>
            ) : (
              <>
                <p className="text-[10px] font-semibold tracking-wider text-forja-muted">
                  SHARE CODE
                </p>
                <p className="mt-1 font-mono text-lg font-bold tracking-[0.18em] text-forja-green">
                  {shareCode}
                </p>
              </>
            )}
          </div>
        ) : (
          <IptvPortalCardBody
            portal={portal}
            checking={checking}
            badge={badge}
          />
        )}
      </div>

      <div
        className={cn(
          'flex shrink-0 items-center justify-end overflow-hidden transition-[width] duration-180 ease-out',
          pinRail
            ? 'w-[180px]'
            : 'w-0 group-hover:w-[180px] group-focus-within:w-[180px]',
        )}
      >
        <div
          className="flex h-full shrink-0 items-center justify-end pr-1"
          style={{ width: ACTION_RAIL_W }}
        >
          {confirmDelete ? (
            <>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0 text-red-400 hover:text-red-300"
                disabled={deleting}
                aria-label="Confirm delete"
                onClick={() => {
                  setConfirmDelete(false)
                  onDelete()
                }}
              >
                <Check className="size-4" />
              </Button>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0"
                aria-label="Cancel delete"
                onClick={() => setConfirmDelete(false)}
              >
                <X className="size-4" />
              </Button>
            </>
          ) : (
            <>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0"
                disabled={checking || sharing}
                aria-label="Assigned accounts"
                title="Assigned accounts"
                onClick={onPeople}
              >
                <UserPlus className="size-4" />
              </Button>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0"
                disabled={checking || sharing}
                aria-label="Check portal status"
                title="Check portal status"
                onClick={onCheck}
              >
                <Radio
                  className={cn(
                    'size-4',
                    checking && 'animate-pulse text-amber-400',
                  )}
                />
              </Button>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0"
                disabled={sharing || checking}
                aria-label="Copy share code"
                title="Copy share code"
                onClick={onShare}
              >
                {sharing ? (
                  <Share2 className="size-4 animate-pulse" />
                ) : shareCode ? (
                  <Check className="size-4 text-forja-green" />
                ) : (
                  <Copy className="size-4" />
                )}
              </Button>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0"
                disabled={checking}
                aria-label="Edit portal"
                onClick={onEdit}
              >
                <Pencil className="size-4" />
              </Button>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0 text-red-400 hover:text-red-300"
                disabled={checking || deleteDisabled}
                aria-label={deleteTitle ?? 'Delete'}
                title={deleteTitle}
                onClick={() => setConfirmDelete(true)}
              >
                <Trash2 className="size-4" />
              </Button>
            </>
          )}
        </div>
      </div>
    </li>
  )
}

/** Flat 2-col grid — no nested card chrome (same as Pool host expand). */
export const iptvPortalGridClassName =
  'grid grid-cols-1 border-t border-forja-border/70 sm:grid-cols-2 sm:[&>li:nth-child(odd)]:border-r sm:[&>li:nth-child(odd)]:border-forja-border/70'
