import { useCallback, useState } from 'react'
import { Link } from '@tanstack/react-router'
import { Check, Loader2, Plus } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useAuth } from '@/hooks/use-auth'
import { useCommitDraft } from '@/hooks/use-commit-draft'
import { useForjaSetting } from '@/hooks/use-user-setting'
import { useProfiles } from '@/hooks/use-profiles'
import type { ForjaPluginPackLive } from '@/lib/forja-plugin-catalog'
import {
  isPackInstalled,
  packRowFromIntent,
  rememberPluginInstallIntent,
  tryOpenForjaInstallDeepLink,
} from '@/lib/forja-plugin-install'
import {
  emptyForjaPayload,
  type ForjaPayload,
} from '@/lib/sync-domains'
import { cn } from '@/lib/utils'

function forjaFromServer(value: unknown): ForjaPayload {
  const payload = value as ForjaPayload | undefined
  return { packs: payload?.packs ?? [] }
}

type AddToForjaButtonProps = {
  pack: ForjaPluginPackLive
  className?: string
  size?: 'default' | 'sm'
  variant?: 'default' | 'magnet'
}

export function AddToForjaButton({
  pack,
  className,
  size = 'default',
  variant = 'default',
}: AddToForjaButtonProps) {
  const { user, loading: authLoading } = useAuth()
  const { activeProfile } = useProfiles()
  const { data, profileId, isLoading, save } = useForjaSetting()
  const { draft, commit, controlsLocked, isSaving } = useCommitDraft({
    profileId,
    updatedAt: data?.updated_at,
    isReady: Boolean(data) && !isLoading,
    serverValue: data?.payload,
    mapServer: forjaFromServer,
    makeEmpty: emptyForjaPayload,
    save,
  })
  const [error, setError] = useState<string | null>(null)
  const [justAdded, setJustAdded] = useState(false)

  const installed = isPackInstalled(draft.packs, pack.manifestUrl)
  const sessionReady =
    !authLoading && !!user && !!activeProfile && Boolean(data) && !isLoading

  const magnetClass =
    'btn-magnet inline-flex w-full items-center justify-center gap-2 rounded-full px-6 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_28px_rgba(28,231,131,0.28)] will-change-transform sm:text-xs'

  const addPack = useCallback(async () => {
    setError(null)
    const manifestUrl = pack.manifestUrl.trim()
    if (!manifestUrl) return

    if (!user) {
      rememberPluginInstallIntent({
        manifestUrl,
        name: pack.name,
        version: pack.version,
      })
      return
    }

    if (!activeProfile) {
      setError('Pick a profile first.')
      return
    }

    if (installed) {
      tryOpenForjaInstallDeepLink(manifestUrl)
      return
    }

    const row = packRowFromIntent({
      manifestUrl,
      name: pack.name,
      version: pack.version,
    })

    try {
      await commit((prev) => ({ packs: [...prev.packs, row] }))
      setJustAdded(true)
      tryOpenForjaInstallDeepLink(manifestUrl)
      window.setTimeout(() => setJustAdded(false), 2500)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not add pack.')
    }
  }, [
    activeProfile,
    commit,
    installed,
    pack.manifestUrl,
    pack.name,
    pack.version,
    user,
  ])

  const statusHint =
    error ??
    (installed && !justAdded
      ? 'Synced to your profile — open Forja to install.'
      : justAdded
        ? 'Saved. Forja installs on sync.'
        : null)

  if (!user && !authLoading) {
    return (
      <div className={cn('flex flex-col gap-2', className)}>
        {variant === 'magnet' ? (
          <Link
            to="/login"
            search={{ next: '/plugins' }}
            data-hover=""
            className={magnetClass}
            onClick={() => {
              rememberPluginInstallIntent({
                manifestUrl: pack.manifestUrl,
                name: pack.name,
                version: pack.version,
              })
            }}
          >
            <Plus className="size-4" />
            Add to Forja
          </Link>
        ) : (
          <Button type="button" size={size} className="w-full sm:w-auto" asChild>
            <Link
              to="/login"
              search={{ next: '/plugins' }}
              onClick={() => {
                rememberPluginInstallIntent({
                  manifestUrl: pack.manifestUrl,
                  name: pack.name,
                  version: pack.version,
                })
              }}
            >
              <Plus className="size-4" />
              Add to Forja
            </Link>
          </Button>
        )}
      </div>
    )
  }

  const busy = authLoading || isSaving || (user && !sessionReady)
  const label = installed
    ? justAdded
      ? 'Added — open Forja'
      : 'In your account'
    : justAdded
      ? 'Added'
      : 'Add to Forja'

  if (variant === 'magnet') {
    return (
      <div className={cn('flex flex-col gap-2', className)}>
        <button
          type="button"
          data-hover=""
          disabled={busy || controlsLocked}
          onClick={() => void addPack()}
          className={cn(
            magnetClass,
            installed &&
              !justAdded &&
              'border border-white/15 bg-white/10 text-[#EDE6DA] shadow-none hover:bg-white/15',
            (busy || controlsLocked) && 'pointer-events-none opacity-60',
          )}
        >
          {busy || isSaving ? (
            <Loader2 className="size-4 animate-spin" />
          ) : installed ? (
            <Check className="size-4" />
          ) : (
            <Plus className="size-4" />
          )}
          {label}
        </button>
        {statusHint ? (
          <p
            className={cn(
              'text-center text-[10px] leading-snug',
              error ? 'text-red-300' : 'text-[rgba(237,230,218,0.4)]',
            )}
          >
            {statusHint}
          </p>
        ) : null}
      </div>
    )
  }

  return (
    <div className={cn('flex flex-col gap-1.5', className)}>
      <Button
        type="button"
        size={size}
        className="w-full sm:w-auto"
        disabled={busy || controlsLocked}
        variant={installed ? 'secondary' : 'default'}
        onClick={() => void addPack()}
      >
        {busy || isSaving ? (
          <Loader2 className="size-4 animate-spin" />
        ) : installed ? (
          <Check className="size-4" />
        ) : (
          <Plus className="size-4" />
        )}
        {label}
      </Button>
      {statusHint ? (
        <p className={cn('text-xs', error ? 'text-red-300' : 'text-forja-muted')}>
          {statusHint}
        </p>
      ) : null}
    </div>
  )
}
