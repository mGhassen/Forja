import { Link } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import {
  SHOWCASE_PLATFORMS,
  primaryDownloadsByPlatform,
  useLatestRelease,
  type ShowcasePlatformId,
} from '@/hooks/use-releases'
import { startBackgroundDownload } from '@/lib/start-download'
import { cn } from '@/lib/utils'

type Variant = 'pills' | 'links' | 'row'

function DownloadTrigger({
  href,
  className,
  children,
  'data-hover': dataHover,
}: {
  href: string
  className?: string
  children: ReactNode
  'data-hover'?: string
}) {
  return (
    <a
      href={href}
      data-hover={dataHover}
      className={className}
      onClick={(e) => {
        e.preventDefault()
        startBackgroundDownload(href)
      }}
    >
      {children}
    </a>
  )
}

/**
 * One download control per platform, wired to the latest R2 release asset
 * (`latest/manifest.json` → CDN `latest/{filename}`).
 * Platforms without a file in the latest release fall back to `/download`.
 */
export function PlatformDownloadButtons({
  variant = 'pills',
  className,
  emphasize,
}: {
  variant?: Variant
  className?: string
  /** Highlight one platform (e.g. guessed OS). */
  emphasize?: ShowcasePlatformId
}) {
  const { data, isLoading } = useLatestRelease()
  const byId = primaryDownloadsByPlatform(data?.assets)

  if (variant === 'links') {
    return (
      <div
        className={cn(
          'flex flex-wrap gap-x-[22px] gap-y-2 font-mono-ui text-xs uppercase tracking-[0.1em]',
          className,
        )}
      >
        {SHOWCASE_PLATFORMS.map((p) => {
          const asset = byId[p.id]
          const classNames = cn(
            'transition-colors',
            emphasize === p.id
              ? 'text-brand hover:text-flame'
              : 'text-[rgba(237,230,218,0.42)] hover:text-flame',
          )
          if (asset) {
            return (
              <DownloadTrigger key={p.id} href={asset.download_url} className={classNames}>
                {p.label}
              </DownloadTrigger>
            )
          }
          return (
            <Link key={p.id} to="/download" className={classNames}>
              {p.label}
            </Link>
          )
        })}
      </div>
    )
  }

  if (variant === 'row') {
    return (
      <div className={cn('flex flex-col gap-2', className)}>
        {SHOWCASE_PLATFORMS.map((p) => {
          const asset = byId[p.id]
          const body = (
            <>
              <span className="font-disp text-lg uppercase tracking-tight sm:text-xl">
                {p.label}
              </span>
              <span className="font-mono-ui text-[10px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.4)]">
                {asset ? 'Download' : isLoading ? '…' : 'Soon'}
              </span>
            </>
          )
          const shell =
            'flex items-center justify-between gap-4 border border-[rgba(237,230,218,0.12)] px-4 py-3 transition-colors hover:border-brand/50 hover:bg-brand/5'
          if (asset) {
            return (
              <DownloadTrigger
                key={p.id}
                href={asset.download_url}
                data-hover=""
                className={shell}
              >
                {body}
              </DownloadTrigger>
            )
          }
          return (
            <Link key={p.id} to="/download" data-hover="" className={shell}>
              {body}
            </Link>
          )
        })}
      </div>
    )
  }

  return (
    <div className={cn('flex flex-wrap gap-2.5 sm:gap-3', className)}>
      {SHOWCASE_PLATFORMS.map((p) => {
        const asset = byId[p.id]
        const hot = emphasize === p.id
        // Landing CTAs: solid brand fill for every platform - download file or /download.
        const classNames = cn(
          'btn-magnet inline-flex min-h-11 flex-1 items-center justify-center rounded-full px-4 py-3 font-mono-ui text-[11px] font-bold uppercase tracking-[0.1em] shadow-[0_0_28px_rgba(28,231,131,0.28)] transition-all will-change-transform sm:min-h-0 sm:flex-none sm:px-7 sm:py-4 sm:text-[13px]',
          hot && 'scale-[1.04] shadow-[0_0_40px_rgba(28,231,131,0.45)]',
        )
        if (asset) {
          return (
            <DownloadTrigger
              key={p.id}
              href={asset.download_url}
              data-hover=""
              className={classNames}
            >
              {p.label}
            </DownloadTrigger>
          )
        }
        return (
          <Link
            key={p.id}
            to="/download"
            data-hover=""
            className={classNames}
            aria-disabled={!isLoading}
          >
            {p.label}
          </Link>
        )
      })}
    </div>
  )
}
