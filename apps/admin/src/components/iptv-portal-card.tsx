import { CalendarDays, Users } from 'lucide-react'
import type { ReactNode } from 'react'
import { cn } from '@/lib/utils'

export type IptvPortalCardData = {
  username: string
  url: string
  alive: boolean | null
  expiry?: string | null
  max_connections?: string | null
  catalog_pool?: boolean
}

export function portalExpiryTone(expiry?: string | null): {
  label: string
  className: string
} {
  const label = (expiry ?? '').trim() || 'Unknown'
  const end = (() => {
    const d = new Date(label)
    return Number.isNaN(d.getTime()) ? null : d
  })()
  if (!end) {
    return {
      label: label === 'Unknown' ? 'Ends: Unknown' : `Ends: ${label}`,
      className: 'text-forja-muted',
    }
  }
  const today = new Date()
  const midnight = new Date(
    today.getFullYear(),
    today.getMonth(),
    today.getDate(),
  )
  const days = Math.floor((end.getTime() - midnight.getTime()) / 86_400_000)
  const className =
    days < 0
      ? 'text-red-400'
      : days <= 7
        ? 'text-amber-400'
        : days <= 30
          ? 'text-yellow-400'
          : 'text-forja-green'
  return {
    label: `${days < 0 ? 'Expired' : 'Ends'} ${label}`,
    className,
  }
}

export function seatsTone(max?: string | null) {
  const cap = (max ?? '').trim() || '?'
  return {
    label: `Max ${cap}`,
    className: 'text-sky-400',
  }
}

export function aliveTone(alive: boolean | null): {
  label: string
  className: string
  dotClass: string
} {
  if (alive === true)
    return {
      label: 'Alive',
      className: 'text-forja-green',
      dotClass: 'bg-forja-green shadow-[0_0_8px_rgba(28,231,131,0.55)]',
    }
  if (alive === false)
    return {
      label: 'Dead',
      className: 'text-red-400',
      dotClass: 'bg-red-500',
    }
  return {
    label: 'Unchecked',
    className: 'text-forja-muted',
    dotClass: 'bg-white/25',
  }
}

/** Same content stack as Pool portal rows. */
export function IptvPortalCardBody({
  portal,
  checking = false,
  badge,
}: {
  portal: IptvPortalCardData
  checking?: boolean
  /** Extra pill next to username (e.g. profile name). */
  badge?: ReactNode
}) {
  const expiry = portalExpiryTone(portal.expiry)
  const seats = seatsTone(portal.max_connections)
  const status = aliveTone(portal.alive)
  const inPool = portal.catalog_pool === true

  return (
    <div className="min-w-0 flex-1 space-y-1">
      <p
        className={cn(
          'flex items-center gap-1.5 text-[11px] font-semibold',
          expiry.className,
        )}
      >
        <CalendarDays className="size-3 shrink-0" />
        <span className="truncate">{expiry.label}</span>
      </p>
      <p className="flex min-w-0 items-center gap-2">
        <span
          className={cn(
            'size-2 shrink-0 rounded-full',
            checking ? 'animate-pulse bg-amber-400' : status.dotClass,
          )}
          title={checking ? 'Checking…' : status.label}
          aria-label={checking ? 'Checking status' : status.label}
        />
        <span className="truncate text-[13px] font-semibold text-forja-text">
          {portal.username}
        </span>
        {inPool ? (
          <span className="shrink-0 rounded bg-forja-green/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-forja-green">
            pool
          </span>
        ) : null}
        {badge}
      </p>
      <p className="truncate text-sm text-white/55">{portal.url}</p>
      <p
        className={cn(
          'flex items-center gap-1.5 text-[11px] font-semibold',
          seats.className,
        )}
      >
        <Users className="size-3 shrink-0" />
        <span>{seats.label}</span>
      </p>
    </div>
  )
}
