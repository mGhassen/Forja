import * as React from 'react'
import { cn } from '@/lib/utils'

export const Input = React.forwardRef<
  HTMLInputElement,
  React.InputHTMLAttributes<HTMLInputElement>
>(({ className, type, ...props }, ref) => (
  <input
    type={type}
    className={cn(
      'flex h-10 w-full rounded-lg border border-forja-border bg-forja-elevated/60 px-3 py-2 text-sm text-forja-text placeholder:text-forja-muted transition-colors hover:border-forja-border focus-visible:border-forja-green/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forja-green/35 disabled:cursor-not-allowed disabled:opacity-50',
      className,
    )}
    ref={ref}
    {...props}
  />
))
Input.displayName = 'Input'
