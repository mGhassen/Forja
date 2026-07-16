import { Link } from '@tanstack/react-router'
import { cn } from '@/lib/utils'

type BrandLogoProps = {
  /** Green brand wordmark, or paper fill for rare light surfaces */
  tone?: 'brand' | 'paper'
  className?: string
  imgClassName?: string
  to?: '/' | string | null
}

/** Full Forja wordmark SVG only — no F-mark asset. */
export function BrandLogo({
  tone = 'brand',
  className,
  imgClassName,
  to = '/',
}: BrandLogoProps) {
  const src = tone === 'paper' ? '/brand/logo-light.svg' : '/brand/logo-dark.svg'

  const img = (
    <img
      src={src}
      alt="Forja"
      className={cn('h-8 w-auto object-contain object-left', imgClassName)}
    />
  )

  if (to) {
    return (
      <Link to={to} className={cn('inline-flex items-center', className)}>
        {img}
      </Link>
    )
  }

  return <span className={cn('inline-flex items-center', className)}>{img}</span>
}
