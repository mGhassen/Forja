import type { HTMLAttributes } from 'react'
import { cn } from '@/lib/utils'

type LiquidGlassProps = HTMLAttributes<HTMLDivElement> & {
  /** Slightly denser tint on dark chrome. */
  solid?: boolean
}

/**
 * Soft Liquid Glass — like Apple’s frosted panels:
 * deep backdrop blur, light tint, thin rim, almost no specular.
 */
export function LiquidGlass({
  className,
  solid = false,
  children,
  ...props
}: LiquidGlassProps) {
  return (
    <div
      className={cn(
        'relative overflow-hidden rounded-2xl',
        'border border-white/15',
        'backdrop-blur-2xl backdrop-saturate-150',
        solid ? 'bg-white/10' : 'bg-white/[0.08]',
        'shadow-[inset_0_1px_0_0_rgba(255,255,255,0.18)]',
        className,
      )}
      {...props}
    >
      {children}
    </div>
  )
}
