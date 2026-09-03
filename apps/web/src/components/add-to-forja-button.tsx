import { useState } from 'react'
import { useNavigate } from '@tanstack/react-router'
import { Cloud, Plus, Trash2 } from 'lucide-react'
import { Link } from '@tanstack/react-router'
import { Button } from '@/components/ui/button'
import { useGoToPluginInstall } from '@/components/plugin-install-confirm-dialog'
import { useAuth } from '@/hooks/use-auth'
import { useForjaSetting } from '@/hooks/use-user-setting'
import { useProfiles } from '@/hooks/use-profiles'
import type { ForjaPluginPackLive } from '@/lib/forja-plugin-catalog'
import {
  isPackInstalled,
  rememberPluginInstallIntent,
  tryOpenForjaInstallDeepLink,
} from '@/lib/forja-plugin-install'
import { cn } from '@/lib/utils'

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
  const navigate = useNavigate()
  const goToInstall = useGoToPluginInstall()
  const { user, loading: authLoading } = useAuth()
  const { activeProfile } = useProfiles()
  const { data, isLoading } = useForjaSetting()
  const [opening, setOpening] = useState(false)

  const installed = isPackInstalled(
    data?.payload?.packs ?? [],
    pack.manifestUrl,
  )

  const payload = {
    manifestUrl: pack.manifestUrl,
    name: pack.name,
    version: pack.version,
  }

  const openProfileAction = (op: 'add' | 'remove') => {
    if (!user) {
      rememberPluginInstallIntent(payload)
      void navigate({
        to: '/login',
        search: { next: '/account/settings/forja' },
      })
      return
    }
    if (!activeProfile) {
      void navigate({ to: '/account/profiles' })
      return
    }
    goToInstall(payload, { op })
  }

  const handleDeepLink = async () => {
    if (opening) return
    setOpening(true)
    try {
      const opened = await tryOpenForjaInstallDeepLink(pack.manifestUrl, {
        name: pack.name,
      })
      if (!opened && !user) openProfileAction('add')
    } finally {
      setOpening(false)
    }
  }

  const primaryLabel = installed
    ? 'Open in Forja'
    : opening
      ? 'Opening…'
      : 'Add to Forja'
  const hint = installed
    ? 'On your profile. Open Forja on this device, or remove it from the profile.'
    : user
      ? 'Opens Forja on this device. Cloud adds it to your profile for other devices.'
      : 'Opens Forja if installed, otherwise sign in to add it to your profile.'

  const magnetClass =
    'btn-magnet inline-flex w-full items-center justify-center gap-2 rounded-full px-6 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_28px_rgba(28,231,131,0.28)] will-change-transform sm:text-xs'

  const iconBtnClass =
    'flex size-11 shrink-0 items-center justify-center rounded-full border border-white/15 bg-white/8 text-[#EDE6DA] hover:bg-white/15 disabled:pointer-events-none disabled:opacity-60'

  const profileIcon = installed ? (
    <button
      type="button"
      className={iconBtnClass}
      title="Remove from profile (uninstalls on devices after sync)"
      aria-label="Remove from profile"
      disabled={authLoading || isLoading}
      onClick={() => openProfileAction('remove')}
    >
      <Trash2 className="size-4" />
    </button>
  ) : (
    <button
      type="button"
      className={iconBtnClass}
      title="Add to profile (syncs to all devices)"
      aria-label="Add to profile"
      disabled={authLoading || isLoading}
      onClick={() => openProfileAction('add')}
    >
      <Cloud className="size-4" />
    </button>
  )

  if (!user && !authLoading) {
    return (
      <div className={cn('flex flex-col gap-2', className)}>
        {variant === 'magnet' ? (
          <button
            type="button"
            data-hover=""
            className={magnetClass}
            disabled={opening}
            onClick={() => void handleDeepLink()}
          >
            <Plus className="size-4" />
            Add to Forja
          </button>
        ) : (
          <Button
            type="button"
            size={size}
            className="w-full sm:w-auto"
            disabled={opening}
            onClick={() => void handleDeepLink()}
          >
            <Plus className="size-4" />
            Add to Forja
          </Button>
        )}
        <p className="text-center font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.38)] sm:text-left">
          {hint}
        </p>
      </div>
    )
  }

  if (variant === 'magnet') {
    return (
      <div className={cn('flex flex-col gap-2', className)}>
        <div className="flex items-center gap-2">
          <button
            type="button"
            data-hover=""
            disabled={authLoading || isLoading || opening}
            onClick={() => void handleDeepLink()}
            className={cn(
              magnetClass,
              installed &&
                'border border-white/15 bg-white/10 text-[#EDE6DA] shadow-none hover:bg-white/15',
              (authLoading || isLoading || opening) &&
                'pointer-events-none opacity-60',
            )}
          >
            <Plus className="size-4" />
            {primaryLabel}
          </button>
          {profileIcon}
        </div>
        <p className="text-center font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.38)]">
          {hint}
        </p>
      </div>
    )
  }

  return (
    <div className={cn('flex flex-col gap-1.5', className)}>
      <div className="flex flex-wrap items-center gap-2">
        <Button
          type="button"
          size={size}
          className="w-full sm:w-auto"
          disabled={authLoading || isLoading || opening}
          variant={installed ? 'secondary' : 'default'}
          onClick={() => void handleDeepLink()}
        >
          <Plus className="size-4" />
          {opening ? 'Opening…' : primaryLabel}
        </Button>
        {profileIcon}
      </div>
      <p className="text-center font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.38)] sm:text-left">
        {hint}
      </p>
      <Link
        to="/download"
        className="text-center text-[10px] text-[rgba(237,230,218,0.4)] underline-offset-2 hover:text-forja-green hover:underline sm:text-left"
      >
        Don&apos;t have the app? Download
      </Link>
    </div>
  )
}
