import * as React from 'react'
import { cn } from '@/lib/utils'

export const Input = React.forwardRef<
  HTMLInputElement,
  React.InputHTMLAttributes<HTMLInputElement>
>(({ className, type, ...props }, ref) => (
  <input
    type={type}
    className={cn(
      'flex h-10 w-full rounded-md border border-forja-border bg-forja-surface px-3 py-2 text-sm text-forja-text placeholder:text-forja-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forja-green/50 disabled:cursor-not-allowed disabled:opacity-50',
      className,
    )}
    ref={ref}
    {...props}
  />
))
Input.displayName = 'Input'
