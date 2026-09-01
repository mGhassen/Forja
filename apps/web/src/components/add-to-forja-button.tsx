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
}

export function AddToForjaButton({
  pack,
  className,
  size = 'default',
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

  if (!user && !authLoading) {
    return (
      <div className={cn('flex flex-col gap-2', className)}>
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
      {error ? (
        <p className="text-xs text-red-300">{error}</p>
      ) : installed && !justAdded ? (
        <p className="text-xs text-forja-muted">
          Synced to your profile — open Forja to install.
        </p>
      ) : justAdded ? (
        <p className="text-xs text-forja-muted">
          Saved to your profile. Forja installs on sync.
        </p>
      ) : null}
    </div>
  )
}
