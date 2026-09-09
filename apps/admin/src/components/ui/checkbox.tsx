import { Check, Minus } from 'lucide-react'
import { cn } from '@/lib/utils'

type CheckboxProps = {
  checked: boolean
  indeterminate?: boolean
  onCheckedChange: (checked: boolean) => void
  disabled?: boolean
  className?: string
  'aria-label'?: string
}

export function Checkbox({
  checked,
  indeterminate = false,
  onCheckedChange,
  disabled = false,
  className,
  'aria-label': ariaLabel,
}: CheckboxProps) {
  const on = checked || indeterminate
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={indeterminate ? 'mixed' : checked}
      aria-label={ariaLabel}
      disabled={disabled}
      onClick={() => onCheckedChange(!(checked || indeterminate))}
      className={cn(
        'flex size-4 shrink-0 items-center justify-center rounded border transition-colors',
        on
          ? 'border-forja-green bg-forja-green text-[#0B0A0A]'
          : 'border-white/25 bg-transparent hover:border-forja-green/60',
        disabled && 'pointer-events-none opacity-45',
        className,
      )}
    >
      {indeterminate ? (
        <Minus className="size-2.5 stroke-3" />
      ) : checked ? (
        <Check className="size-2.5 stroke-3" />
      ) : null}
    </button>
  )
}
