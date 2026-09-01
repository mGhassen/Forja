import { Plus } from 'lucide-react'
import { Link } from '@tanstack/react-router'
import { Button } from '@/components/ui/button'
import type { ForjaPluginPackLive } from '@/lib/forja-plugin-catalog'
import { tryOpenForjaInstallDeepLink } from '@/lib/forja-plugin-install'
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
  const magnetClass =
    'btn-magnet inline-flex w-full items-center justify-center gap-2 rounded-full px-6 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_28px_rgba(28,231,131,0.28)] will-change-transform sm:text-xs'

  const openInApp = () => {
    tryOpenForjaInstallDeepLink(pack.manifestUrl, { name: pack.name })
  }

  if (variant === 'magnet') {
    return (
      <div className={cn('flex flex-col gap-2', className)}>
        <button
          type="button"
          data-hover=""
          className={magnetClass}
          onClick={openInApp}
        >
          <Plus className="size-4" />
          Add to Forja
        </button>
        <p className="text-center font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.38)]">
          Opens Forja to confirm install
        </p>
      </div>
    )
  }

  return (
    <div className={cn('flex flex-col gap-1.5', className)}>
      <Button
        type="button"
        size={size}
        className="w-full sm:w-auto"
        onClick={openInApp}
      >
        <Plus className="size-4" />
        Add to Forja
      </Button>
      <p className="text-center font-mono-ui text-[9px] uppercase tracking-wider text-[rgba(237,230,218,0.38)] sm:text-left">
        Opens Forja to confirm install
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
